#!/usr/bin/perl
# Copyright (c) 2007 CentralNic Ltd. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the same
# terms as Perl itself.
package Preppi;
use Carp;
use Digest::SHA1 qw(sha1_hex);
use Gnome2::GConf;
use File::Basename qw(basename);
use Gtk2 -init;
use Gtk2::SourceView;
use Gtk2::Ex::Simple::List;
use Gtk2::Ex::Simple::Tree;
use HTML::Entities qw(encode_entities_numeric);
use Locale::gettext;
use Net::EPP::Client;
use Net::EPP::Frame;
use POSIX qw(setlocale);
use Time::HiRes qw(time);
use URI::Escape;
use XML::LibXML;
use base qw(Gtk2::GladeXML::Simple);
use bytes;
use constant EPP_XMLNS	=> 'urn:ietf:params:xml:ns:epp-1.0';
use constant true => 1;
use constant false => undef;
use constant FROM_CLIENT => 'C';
use constant FROM_SERVER => 'S';
use strict;

our $NORMAL	= Gtk2::Gdk::Cursor->new('left_ptr');
our $BUSY	= Gtk2::Gdk::Cursor->new('watch');
our $NAME	= __PACKAGE__;
our $VERSION	= '0.06';
chomp(our $OPENER = `which gnome-open 2> /dev/null`);
our $GLADE	= (-e '@PREFIX@' ? sprintf('%s/share/%s', '@PREFIX@', lc($NAME)) : $ENV{PWD}) . sprintf('/%s.glade', lc($NAME));
our $XSD	= (-e '@PREFIX@' ? sprintf('%s/share/%s', '@PREFIX@', lc($NAME)) : $ENV{PWD}) . sprintf('/epp.xsd', lc($NAME));
our %CERT_KEYS	= (
	'C'		=> gettext('Country'),
	'L'		=> gettext('Location'),
	'O'		=> gettext('Organisation'),
	'OU'		=> gettext('Organisational Unit'),
	'CN'		=> gettext('Common Name'),
	'ST'		=> gettext('State/Province'),
	'emailAddress'	=> gettext('Email address'),
);

sub new {
	my $package = shift;
	my $self = bless($package->SUPER::new($GLADE), $package);

	$self->{parser} = XML::LibXML->new;

	$self->{gconf} = Gnome2::GConf::Client->get_default;
	$self->{gconf_base} = sprintf('/apps/%s', lc($NAME));

	$self->{connected} = false;
	$self->{connect_dialog}->show_all;

	$self->{lm}		= Gtk2::SourceView::LanguagesManager->new;
	$self->{lang}		= $self->{lm}->get_language_from_mime_type("text/xml");

	$self->{input_sb}	= Gtk2::SourceView::Buffer->new_with_language($self->{lang});
	$self->{input_sb}->set_highlight(true);
	$self->{input_view}	= Gtk2::SourceView::View->new_with_buffer($self->{input_sb});
	$self->{input_scrwin}->add($self->{input_view});

	$self->{input_view}->get_buffer->signal_connect('changed', sub { $self->validate_input_buffer });

	$self->{output_sb}	= Gtk2::SourceView::Buffer->new_with_language($self->{lang});
	$self->{output_sb}->set_highlight(true);
	$self->{output_view}	= Gtk2::SourceView::View->new_with_buffer($self->{output_sb});
	$self->{output_view}->set_editable(false);
	$self->{output_scrwin}->add($self->{output_view});

	$self->{output_view}->get_buffer->signal_connect('changed', sub { $self->validate_output_buffer });

	$self->{greeting_sb}	= Gtk2::SourceView::Buffer->new_with_language($self->{lang});
	$self->{greeting_sb}->set_highlight(true);
	$self->{greeting_view}	= Gtk2::SourceView::View->new_with_buffer($self->{greeting_sb});
	$self->{greeting_view}->set_editable(false);
	$self->{greeting_scrwin}->add($self->{greeting_view});

	$self->{input_view}->set_show_line_numbers($self->{gconf}->get_bool("$self->{gconf_base}/show_line_numbers"));
	$self->{output_view}->set_show_line_numbers($self->{gconf}->get_bool("$self->{gconf_base}/show_line_numbers"));
	$self->{greeting_view}->set_show_line_numbers($self->{gconf}->get_bool("$self->{gconf_base}/show_line_numbers"));

	$self->{input_view}->set_wrap_mode($self->{gconf}->get_bool("$self->{gconf_base}/wrap_lines") ? 'char' : 'none');
	$self->{output_view}->set_wrap_mode($self->{gconf}->get_bool("$self->{gconf_base}/wrap_lines") ? 'char' : 'none');
	$self->{greeting_view}->set_wrap_mode($self->{gconf}->get_bool("$self->{gconf_base}/wrap_lines") ? 'char' : 'none');

	my $bool = $self->{wrap_lines_menu_item}->set_active($self->{gconf}->get_bool("$self->{gconf_base}/wrap_lines"));
	my $bool = $self->{view_line_numbers_menu_item}->set_active($self->{gconf}->get_bool("$self->{gconf_base}/show_line_numbers"));

	$self->{template_list} = Gtk2::Ex::Simple::Tree->new_from_treeview(
		$self->{template_list},
		'Template'	=> 'markup',
		'Data'		=> 'hidden',
		'is_template'	=> 'hidden',
	);

	($self->{template_list}->get_column(0)->get_cell_renderers)[0]->set('ellipsize-set' => 0, 'ellipsize' => 'end');

	$self->{template_list}->get_selection->signal_connect('changed', sub { $self->template_selected });

	$self->{cert_info_treeview} = Gtk2::Ex::Simple::List->new_from_treeview(
		$self->{cert_info_treeview},
		gettext('Name') => 'text',
		gettext('Value') => 'text',
	);

	$self->build_template_list;

	my $font = Gtk2::Pango::FontDescription->from_string($self->{gconf}->get_string('/desktop/gnome/interface/monospace_font_name'));
	$self->{input_view}->modify_font($font);
	$self->{output_view}->modify_font($font);
	$self->{greeting_view}->modify_font($font);

	$self->{template_list}->signal_connect('button_press_event', sub { $self->select_template if ($_[1]->type eq '2button-press') });

	$self->{host_store} = Gtk2::ListStore->new('Glib::String');

	my $host_completion = Gtk2::EntryCompletion->new;
	$host_completion->set_model($self->{host_store});
	$host_completion->set_text_column(0);
	$host_completion->set_inline_completion(1);
	$host_completion->signal_connect('match-selected', sub {
		my ($host_completion, $model, $iter) = @_;
		my $value = $model->get_value($iter, 0);
	});

	$self->{host_history} = [split(/,/, $self->{gconf}->get_string($self->{gconf_base}.'/host_history'))];

	$self->update_host_entry_completion_store;

	$self->{connect_server_entry}->set_completion($host_completion);

	$self->{userid_store} = Gtk2::ListStore->new('Glib::String');

	my $userid_completion = Gtk2::EntryCompletion->new;
	$userid_completion->set_model($self->{userid_store});
	$userid_completion->set_text_column(0);
	$userid_completion->set_inline_completion(1);
	$userid_completion->signal_connect('match-selected', sub {
		my ($userid_completion, $model, $iter) = @_;
		my $value = $model->get_value($iter, 0);
	});

	$self->{userid_history} = [split(/,/, $self->{gconf}->get_string($self->{gconf_base}.'/userid_history'))];

	$self->update_userid_entry_completion_store;

	$self->{connect_username_entry}->set_completion($userid_completion);

	$self->{connect_server_entry}->set_text($self->{gconf}->get_string($self->{gconf_base}.'/last_host'));
	$self->{connect_port_spinbutton}->set_value($self->{gconf}->get_int($self->{gconf_base}.'/last_port') || 700);

	$self->{connect_ssl_cert_filechooser}->set_filename($self->{gconf}->get_string($self->{gconf_base}.'/last_cert')) if ($self->{gconf}->get_string($self->{gconf_base}.'/last_cert'));

	$self->{connect_ssl_use_cert_checkbutton}->signal_connect('toggled', sub {
		my $bool = $self->{connect_ssl_use_cert_checkbutton}->get_active;
		$self->{connect_ssl_cert_label}->set_sensitive($bool);
		$self->{connect_ssl_cert_filechooser}->set_sensitive($bool);
		$self->{connect_ssl_cert_passphrase_label}->set_sensitive($bool);
		$self->{connect_ssl_cert_passphrase}->set_sensitive($bool);
	});

	$self->{connect_ssl_use_cert_checkbutton}->set_active(true);
	$self->{connect_ssl_use_cert_checkbutton}->set_active($self->{gconf}->get_bool($self->{gconf_base}.'/last_use_cert'));

	$self->{connect_ssl_checkbutton}->signal_connect('toggled', sub {
		my $bool = $self->{connect_ssl_checkbutton}->get_active;
		$self->{connect_ssl_use_cert_checkbutton}->set_sensitive($bool);
		$self->{connect_ssl_cert_label}->set_sensitive($bool);
		$self->{connect_ssl_cert_filechooser}->set_sensitive($bool);
		$self->{connect_ssl_cert_passphrase_label}->set_sensitive($bool);
		$self->{connect_ssl_cert_passphrase}->set_sensitive($bool);
	});

	$self->{connect_ssl_checkbutton}->set_active(true);
	$self->{connect_ssl_checkbutton}->set_active($self->{gconf}->get_bool($self->{gconf_base}.'/last_ssl'));

	my $val = $self->{gconf}->get_string($self->{gconf_base}.'/last_user');
	$self->{connect_username_entry}->set_text($val);
	$self->{connect_password_entry}->grab_focus if ($val);

	# Option to randomise <clTRID> element (default: TRUE)
	$self->{randomise_cltrid_item}->signal_connect('toggled', sub {
		$self->{gconf}->set_bool($self->{gconf_base}.'/randomise_cltrid', $self->{randomise_cltrid_item}->get_active);
	});
	$self->{randomise_cltrid_item}->set_active($self->{gconf}->get_bool($self->{gconf_base}.'/randomise_cltrid'));

	# Option to keep connection to EPP server alive (default: TRUE)
	$self->{keep_connection_alive_item}->signal_connect('toggled', sub {
		$self->{gconf}->set_bool($self->{gconf_base}.'/keep_connection_alive', $self->{keep_connection_alive_item}->get_active);
	});
	$self->{keep_connection_alive_item}->set_active($self->{gconf}->get_bool($self->{gconf_base}.'/keep_connection_alive'));

	$self->{transaction_summary} = Gtk2::Ex::Simple::List->new_from_treeview(
		$self->{transaction_summary},
		gettext('Time')		=> 'text',
		gettext('Command')	=> 'text',
		gettext('Duration')	=> 'text',
		gettext('Code')		=> 'int',
		gettext('Message')	=> 'text',
	);

	$self->{parser} = XML::LibXML->new;

	Gtk2::AboutDialog->set_url_hook(sub { $self->open_url(@_) });

	$self->{busy} = false;

	eval { $self->{schema} = XML::LibXML::Schema->new(location => $XSD) };

	# Ping EPP server to keep connection alive
	Glib::Timeout->add(5000, sub { $self->keep_alive; return true; });

	return true;
}

sub build_template_list {
	my $self = shift;

	$self->{template_list}->get_model->clear;

	### domain:
	my $cd = Net::EPP::Frame::Command::Check::Domain->new;
	$cd->addDomain('example.com');
	$cd->clTRID->appendText('ABC-12345');

	my $id = Net::EPP::Frame::Command::Info::Domain->new;
	$id->setDomain('example.com');
	$id->clTRID->appendText('ABC-12345');

        my $rd = Net::EPP::Frame::Command::Renew::Domain->new;
        $rd->setDomain('example.com');
        $rd->setPeriod('1');
        $rd->setCurExpDate('2010-01-01');
        $rd->clTRID->appendText('ABC-12345');

	my $td_query = Net::EPP::Frame::Command::Transfer::Domain->new;
	$td_query->setOp('query');
	$td_query->setDomain('example.com');
	$td_query->clTRID->appendText('ABC-12345');

	my $td_request = Net::EPP::Frame::Command::Transfer::Domain->new;
	$td_request->setOp('request');
	$td_request->setDomain('example.com');
	$td_request->setPeriod(1);
	$td_request->setAuthInfo('foo2bar');
	$td_request->clTRID->appendText('ABC-12345');

	my $td_cancel = Net::EPP::Frame::Command::Transfer::Domain->new;
	$td_cancel->setOp('cancel');
	$td_cancel->setDomain('example.com');
	$td_cancel->clTRID->appendText('ABC-12345');

	my $td_approve = Net::EPP::Frame::Command::Transfer::Domain->new;
	$td_approve->setOp('approve');
	$td_approve->setDomain('example.com');
	$td_approve->clTRID->appendText('ABC-12345');

	my $td_reject = Net::EPP::Frame::Command::Transfer::Domain->new;
	$td_reject->setOp('reject');
	$td_reject->setDomain('example.com');
	$td_reject->clTRID->appendText('ABC-12345');

	## contact:
	my $cc = Net::EPP::Frame::Command::Check::Contact->new;
	$cc->addContact('contact-id');
	$cc->clTRID->appendText('ABC-12345');

	my $ci = Net::EPP::Frame::Command::Info::Contact->new;
	$ci->setContact('contact-id');
	$ci->clTRID->appendText('ABC-12345');

	my $tc_query = Net::EPP::Frame::Command::Transfer::Contact->new;
	$tc_query->setOp('query');
	$tc_query->setContact('contact-id');
	$tc_query->clTRID->appendText('ABC-12345');

	my $tc_request = Net::EPP::Frame::Command::Transfer::Contact->new;
	$tc_request->setOp('request');
	$tc_request->setContact('contact-id');
	$tc_request->setAuthInfo('foo2bar');
	$tc_request->clTRID->appendText('ABC-12345');

	my $tc_cancel = Net::EPP::Frame::Command::Transfer::Contact->new;
	$tc_cancel->setOp('cancel');
	$tc_cancel->setContact('contact-id');
	$tc_cancel->clTRID->appendText('ABC-12345');

	my $tc_approve = Net::EPP::Frame::Command::Transfer::Contact->new;
	$tc_approve->setOp('approve');
	$tc_approve->setContact('contact-id');
	$tc_approve->clTRID->appendText('ABC-12345');

	my $tc_reject = Net::EPP::Frame::Command::Transfer::Contact->new;
	$tc_reject->setOp('reject');
	$tc_reject->setContact('contact-id');
	$tc_reject->clTRID->appendText('ABC-12345');

	## host:
	my $hc = Net::EPP::Frame::Command::Check::Host->new;
	$hc->addHost('ns0.example.com');
	$hc->clTRID->appendText('ABC-12345');

	my $hi = Net::EPP::Frame::Command::Info::Host->new;
	$hi->setHost('ns0.example.com');
	$hi->clTRID->appendText('ABC-12345');

	my $req = Net::EPP::Frame::Command::Poll::Req->new;
	$req->clTRID->appendText('ABC-12345');

	my $ack = Net::EPP::Frame::Command::Poll::Ack->new;
	$ack->setMsgID(12345);
	$ack->clTRID->appendText('ABC-12345');

	@{$self->{template_list}->{data}} = (
		{
			value => [ '<b>'.gettext('Session').'</b>', '', 0 ],
			children => [
				{ value => [ gettext('Hello'), 	Net::EPP::Frame::Hello->new->toString(1), 0] },
				{
					value => [ '<b>'.gettext('Poll').'</b>', Net::EPP::Frame::Hello->new->toString(1), 0],
					children => [
						{ value => [ gettext('Req'), 	$req->toString(1), 0] },
						{ value => [ gettext('Ack'), 	$ack->toString(1), 0] },
					],
				},
			],
		},
		{
			value => [ '<b>'.gettext('Domain').'</b>', '', 0 ],
			children => [
				{ value => [ gettext('Check'), 	$cd->toString(true),	0] },
				{ value => [ gettext('Info'), 	$id->toString(true),	0] },
				{ value => [ gettext('Renew'),  $rd->toString(true),    0] },
				{
					value => [ '<b>'.gettext('Transfer').'</b>' ],
					children => [
						{ value => [ gettext('Query'), $td_query->toString(true), 0 ] },
						{ value => [ gettext('Request'), $td_request->toString(true), 0 ] },
						{ value => [ gettext('Approve'), $td_approve->toString(true), 0 ] },
						{ value => [ gettext('Reject'), $td_reject->toString(true), 0 ] },
						{ value => [ gettext('Cancel'), $td_cancel->toString(true), 0 ] },
					],
				}
			],
		},
		{
			value => [ '<b>'.gettext('Contact').'</b>', '', 0 ],
			children => [
				{ value => [ gettext('Check'), 	$cc->toString(true),	0] },
				{ value => [ gettext('Info'), 	$ci->toString(true),	0] },
				{
					value => [ '<b>'.gettext('Transfer').'</b>' ],
					children => [
						{ value => [ gettext('Query'), $tc_query->toString(true), 0 ] },
						{ value => [ gettext('Request'), $tc_request->toString(true), 0 ] },
						{ value => [ gettext('Approve'), $tc_approve->toString(true), 0 ] },
						{ value => [ gettext('Reject'), $tc_reject->toString(true), 0 ] },
						{ value => [ gettext('Cancel'), $tc_cancel->toString(true), 0 ] },
					],
				}
			],
		},
		{
			value => [ '<b>'.gettext('Host').'</b>', '', 0 ],
			children => [
				{ value => [ gettext('Check'), 	$hc->toString(true),	0] },
				{ value => [ gettext('Info'), 	$hi->toString(true),	0] },
			],
		},
	);
	$self->{template_list}->expand_all;

	my @templates = split(/,/, $self->{gconf}->get_string("$self->{gconf_base}/template_list"));
	foreach my $template (@templates) {
		push(@{$self->{template_list}->{data}}, { value => [ basename(uri_unescape($template)), $template, 1 ] });
	}

	$self->{template_list}->expand_all;

}

sub connect_password_entry_activate { $_[0]->connect_dialog_response(undef, 'ok') }

sub connect_dialog_response {
	my ($self, undef, $response) = @_;
	if ($response eq 'ok') {
		$self->connect;

	} else {
		$self->close_program;

	}
}

sub connecting_dialog_cancel {
	my $self = shift;
	$self->disconnect if ($self->{connected});
	$self->{connecting_dialog}->hide;
	$self->{connect_dialog}->show_all;
	return true;
}

sub disconnect {
	my $self = shift;
	my $logout = Net::EPP::Frame::Command::Logout->new;
	$logout->clTRID->appendText(sha1_hex(ref($self).time().$$));
	eval { $self->{epp}->request($logout) };

	$self->clear_log;
	@{$self->{transaction_summary}->{data}} = ();
	$self->{epp}->disconnect;
	$self->{connected} = false;
	$self->{main_window}->hide;
	$self->{connect_dialog}->show_all;

	return true;
}

sub open_file {
	my $self = shift;
	my $dialog = Gtk2::FileChooserDialog->new(
		gettext('Open File'),
		$self->{main_window},
		'open',
		'gtk-cancel' => 'cancel',
		gettext('Add Template') => 'apply',
		'gtk-ok' => 'ok',
	);
	$dialog->set_current_folder($self->{last_open_dir}) if ($self->{last_open_dir});
	$dialog->set_local_only(true);
	$dialog->set_icon_name('stock_open');
	$dialog->set_modal(true);
	$dialog->signal_connect('response', sub {
		$self->{last_open_dir} = $dialog->get_current_folder;
		if ($_[1] eq 'ok') {
			$self->read_file($dialog->get_filename);

		} elsif ($_[1] eq 'apply') {
			$self->add_template($dialog->get_filename);

		}
		$dialog->destroy;
	});
	$dialog->show_all;

	return true;
}

sub add_template {
	my ($self, $file) = @_;

	my $key = "$self->{gconf_base}/template_list";
	my @list = split(/,/, $self->{gconf}->get_string($key));
	$self->{gconf}->set_string($key, join(',', @list, $file));

	push(@{$self->{template_list}->{data}}, { value => [ basename($file), $file, 1 ] });

	return true;
}

sub read_file {
	my ($self, $file) = @_;

	if (!open(FILE, $file)) {
		$self->error(sprintf(gettext("Error reading '%s': %s"), $file, $!));

	} else {
		local $/;
		undef $/;
		$self->{input_view}->get_buffer->set_text(<FILE>);
	}

	return true;
}

sub save_output {
	my $self = shift;
	my $data = $self->{output_view}->get_buffer->get_text(
		$self->{output_view}->get_buffer->get_start_iter,
		$self->{output_view}->get_buffer->get_end_iter,
		false,
	);
	my $file = $self->select_save_target;
	$self->save_to_file($data, $file) if ($file);
	return true;
}

sub save_input {
	my $self = shift;
	my $data = $self->{input_view}->get_buffer->get_text(
		$self->{input_view}->get_buffer->get_start_iter,
		$self->{input_view}->get_buffer->get_end_iter,
		false,
	);
	my $file = $self->select_save_target;
	$self->save_to_file($data, $file) if ($file);
	return true;
}

sub select_save_target {
	my $self = shift;
	my $file;
	my $dialog = Gtk2::FileChooserDialog->new(
		gettext('Save File'),
		$self->{main_window},
		'save',
		'gtk-cancel' => 'cancel',
		'gtk-ok' => 'ok'
	);
	$dialog->set_current_folder($self->{last_save_dir}) if ($self->{last_save_dir});
	$dialog->set_local_only(true);
	$dialog->set_icon_name('stock_save');
	$dialog->set_modal(true);
	$dialog->set_do_overwrite_confirmation(true);
	$dialog->signal_connect('response', sub {
		$file = $dialog->get_filename;
		$self->{last_save_dir} = $dialog->get_current_folder;
		$dialog->destroy;
	});
	$dialog->run;
	return $file;
}

sub save_to_file {
	my ($self, $data, $file) = @_;

	if (!open(FILE, '>'.$file)) {
		$self->error(sprintf(gettext("Error writing to '%s': %s"), $file, $!));

	} else {
		print FILE $data;
		close(FILE);
	}

	return true;
}

sub open_url {
	my ($self, undef, $url) = @_;

	if (!-x $OPENER) {
		my $dialog = Gtk2::MessageDialog->new($self->{main_window}, 'modal', 'info', 'ok', gettext('Error opening URL'));
		$dialog->format_secondary_text(gettext("The 'gnome-open' program could not be found."));
		$dialog->signal_connect('response', sub { $dialog->destroy });
		$dialog->show_all;
		return false;

	} else {
		system("$OPENER \"$url\" &");
		return true;

	}
}

sub show_about_dialog {
	my $self = shift;
	my $dialog = Gtk2::AboutDialog->new;
	$dialog->set('name'		=> $NAME);
	$dialog->set('version'		=> $VERSION);
	$dialog->set('comments'		=> gettext('A Pretty Good EPP Client.'));
	$dialog->set('copyright'	=> gettext("Copyright 2006 CentralNic Ltd. This program is\nfree software, you can use it and/or modify it\nunder the terms of the GNU General Public License."));
	$dialog->set('website'		=> 'http://labs.centralnic.com/preppi.php');
	$dialog->set('logo_icon_name'	=> 'stock_database');
	$dialog->set('icon_name'	=> $self->{main_window}->get_icon_name);
	$dialog->signal_connect('close', sub { $dialog->destroy });
	$dialog->signal_connect('response', sub { $dialog->destroy });
	$dialog->show_all;

	return true;
}

sub close_program {
	my $self = shift;
	$self->disconnect if ($self->{connected});
	Gtk2->main_quit;
}

sub connect {
	my $self = shift;

	@{$self->{view_log}->{data}} = ();

	$self->{epp} = Net::EPP::Client->new(
		host	=> $self->{connect_server_entry}->get_text,
		port	=> $self->{connect_port_spinbutton}->get_value,
		ssl	=> ($self->{connect_ssl_checkbutton}->get_active ? true : false),
		dom	=> 1,
	);

	$self->{connect_dialog}->hide;

	$self->{connecting_dialog}->show_all;
	$self->update_ui;

	$self->{connecting_progressbar}->set_text(gettext('Connecting to server'));
	$self->{connecting_progressbar}->pulse;
	$self->update_ui;

	eval {
		local $SIG{ALRM} = sub { croak("ALRM\n") };
		alarm($self->{connect_timeout_spinbutton}->get_value);

		my $use_cert = ($self->{connect_ssl_checkbutton}->get_active && $self->{connect_ssl_use_cert_checkbutton}->get_active);
		my $file = $self->{connect_ssl_cert_filechooser}->get_filename;

		$self->{greeting} = $self->{epp}->connect(
			SSL_use_cert		=> $use_cert,
			SSL_cert_file		=> ($use_cert ? $file : false),
			SSL_key_file		=> ($use_cert ? $file : false),
			SSL_passwd_cb		=> ($use_cert ? sub { return $self->{connect_ssl_cert_passphrase}->get_text } : false),
			SSL_verify_mode		=> false,
		);
		alarm(0);
	};
	if ($@) {
		print $@;
		alarm(0);
		$self->{connecting_dialog}->hide;
		$self->{connect_dialog}->show_all;
		$self->error(sprintf(
			gettext('Connection to the EPP server on %s:%d failed.'),
			$self->{connect_server_entry}->get_text,
			$self->{connect_port_spinbutton}->get_value
		));
		return true;
	}

	$self->parse_peer_certificate if ($self->{connect_ssl_checkbutton}->get_active);

	eval {
		$self->{greeting_view}->get_buffer->set_text($self->{greeting}->toString(1));
		$self->append_log($self->{greeting}->toString(1), FROM_SERVER);
	};

	$self->{connecting_progressbar}->set_text(gettext('Connection established, logging in'));
	$self->{connecting_progressbar}->pulse;
	$self->update_ui;

	my $login = Net::EPP::Frame::Command::Login->new;

	# add credentials:
	$login->clID->appendText($self->{connect_username_entry}->get_text);
	$login->pw->appendText($self->{connect_password_entry}->get_text);

	$login->version->appendText($self->{greeting}->getElementsByTagNameNS(EPP_XMLNS, 'version')->shift->firstChild->data);
	$login->lang->appendText($self->{greeting}->getElementsByTagNameNS(EPP_XMLNS, 'lang')->shift->firstChild->data);

	$login->clTRID->appendText(sha1_hex(ref($self).time().$$));

	# add object URIs:
	my $objects = $self->{greeting}->getElementsByTagNameNS(EPP_XMLNS, 'objURI');
	while (my $object = $objects->shift) {
		my $el = $login->createElement('objURI');
		$el->appendText($object->firstChild->data);
		$login->svcs->appendChild($el);
	}
	my $objects = $self->{greeting}->getElementsByTagNameNS(EPP_XMLNS, 'extURI');
	while (my $object = $objects->shift) {
		my $el = $login->createElement('objURI');
		$el->appendText($object->firstChild->data);
		$login->svcs->appendChild($el);
	}

	# add new password info
	if ($self->{newPW1}->get_text ne '') {
		my $newPW = $login->createElement('newPW');
		$newPW->appendText($self->{newPW1}->get_text);
		$login->getNode('login')->insertAfter($newPW, $login->pw);
	}

	$self->{connecting_dialog}->hide;

	$self->append_log($login->toString(1), FROM_CLIENT);

	my $answer = $self->{epp}->request($login);

	$self->append_log($answer->toString(1), FROM_SERVER);

	my $code = $self->get_result_code($answer);

	if ($code != 1000) {
		$self->{connect_dialog}->show_all;
		$self->error(sprintf(gettext('Error: %s'), $self->get_result_message($answer)));
		return true;

	} else {
		$self->{connected} = 1;

		$self->{gconf}->set_string($self->{gconf_base}.'/last_host', $self->{connect_server_entry}->get_text);
		$self->{gconf}->set_int($self->{gconf_base}.'/last_port', $self->{connect_port_spinbutton}->get_value);
		$self->{gconf}->set_bool($self->{gconf_base}.'/last_ssl', $self->{connect_ssl_checkbutton}->get_active);
		$self->{gconf}->set_string($self->{gconf_base}.'/last_user', $self->{connect_username_entry}->get_text);
		$self->{gconf}->set_bool($self->{gconf_base}.'/last_use_cert', $self->{connect_ssl_use_cert_checkbutton}->get_active);
		$self->{gconf}->set_string($self->{gconf_base}.'/last_cert', $self->{connect_ssl_cert_filechooser}->get_filename);

		$self->{main_window}->show_all;
		$self->{input_status_icon}->hide;
		$self->{output_status_icon}->hide;
		$self->{transaction_error_box}->hide;
		$self->update_ui;

		$self->{output_view}->get_buffer->set_text('');
		$self->set_status(
			sprintf(gettext('Logged in to %s:%d as %s'),
			$self->{connect_server_entry}->get_text,
			$self->{connect_port_spinbutton}->get_value,
			$self->{connect_username_entry}->get_text,
		));

		$self->{template_list}->get_selection->unselect_all;

		$self->{main_window}->set_title(sprintf(gettext('%s@%s'), $self->{connect_username_entry}->get_text, $self->{connect_server_entry}->get_text));

		my %hosts;
		$hosts{lc($self->{connect_server_entry}->get_text)}++;
		foreach my $host (@{$self->{host_history}}) {
			$hosts{lc($host)}++;
		}
		$self->{host_history} = [sort(keys(%hosts))];
		$self->{gconf}->set_string($self->{gconf_base}.'/host_history', join(',', @{$self->{host_history}}));
		$self->update_host_entry_completion_store;

		my %userids;
		$userids{lc($self->{connect_username_entry}->get_text)}++;
		foreach my $userid (@{$self->{userid_history}}) {
			$userids{lc($userid)}++;
		}
		$self->{userid_history} = [sort(keys(%userids))];
		$self->{gconf}->set_string($self->{gconf_base}.'/userid_history', join(',', @{$self->{userid_history}}));
		$self->update_userid_entry_completion_store;
	}

	return true;
}

sub update_ui { Gtk2->main_iteration while (Gtk2->events_pending) }

sub error {
	my ($self, $error) = @_;
	my $dialog = Gtk2::MessageDialog->new(
		($self->{connected} ? $self->{main_window} : $self->{connect_dialog}),
		'modal',
		'error',
		'ok',
		gettext('Error'),
	);
	$dialog->format_secondary_markup(encode_entities_numeric($error));
	$dialog->signal_connect('response', sub { $dialog->destroy });
	$dialog->signal_connect('close', sub { $dialog->destroy });
	$dialog->set_modal(true);
	$dialog->set_position('center');
	$dialog->set_keep_above(true);
	$dialog->show_all;
	return true;
}

sub get_result_code {
	my ($self, $doc) = @_;
	my $els = $doc->getElementsByTagNameNS(EPP_XMLNS, 'result');
	if (defined($els)) {
		my $el = $els->shift;
		if (defined($el)) {
			return $el->getAttribute('code');
		}
	}
	return 2400;
}

sub get_result_message {
	my ($self, $doc) = @_;
	my $els = $doc->getElementsByTagNameNS(EPP_XMLNS, 'msg');
	if (defined($els)) {
		my $el = $els->shift;
		if (defined($el)) {
			my @children = $el->getChildNodes;
			if (defined($children[0])) {
				my $txt = $children[0];
				return $txt->data if (ref($txt) eq 'XML::LibXML::Text');
			}
		}
	}
	return 'Unknown message';
}

sub send_request {
	my $self = shift;

	$self->{busy} = true;

	$self->set_status(gettext('Sending request frame to server...'));
	$self->{main_window}->window->set_cursor($BUSY);
	$self->{main_window}->set_sensitive(false);
	$self->update_ui;

	my $input = $self->{input_view}->get_buffer->get_text(
		$self->{input_view}->get_buffer->get_start_iter,
		$self->{input_view}->get_buffer->get_end_iter,
		false
	);

	my ($time, $answer, $t0, $t1);
	eval {
		local $SIG{ALRM} = sub { croak('Timed out waiting for response from server') };
		alarm($self->{connect_timeout_spinbutton}->get_value);

		if ($self->{gconf}->get_bool($self->{gconf_base}.'/randomise_cltrid')) {
			my $clTRID = '<clTRID>'.sha1_hex(Time::HiRes::time()).'</clTRID>';
			$input =~ s/<clTRID>.+?<\/clTRID>/$clTRID/mg;
			$input =~ s/<clTRID\s*\/>/$clTRID/mg;
			$self->{input_view}->get_buffer->set_text($input);
		}

		$time = sprintf('%02d:%02d:%02d', (localtime())[2,1,0]);
		$t0 = time();
		$answer = $self->{epp}->request($input);
		$t1 = time() - $t0;

		$self->append_log($input, FROM_CLIENT);

		alarm(0);
	};

	$self->set_status('');
	$self->{main_window}->window->set_cursor($NORMAL);
	$self->{main_window}->set_sensitive(true);
	$self->update_ui;

	my ($err, $xml, $code, $message);
	if ($@) {
		alarm(0);
		$err = "$@";

	} else {
		eval {
			$xml		= $answer->toString(true);
			$code		= $self->get_result_code($answer);
			$message	= $self->get_result_message($answer);
		};
		$err = "$@";

	}
	if ($err ne '') {
		$self->show_transaction_error_box($err);

	} else {
		unshift(@{$self->{transaction_summary}->{data}}, [
			$time,
			$self->get_command_from_input($input),
			sprintf('%0.2fs', $t1),
			$code,
			$message,
		]);
		$self->append_log($xml, FROM_SERVER);
		$self->{output_view}->get_buffer->set_text($xml);
		$self->hide_transaction_error_box;

	}

	$@ = '';

	$self->set_status(sprintf(gettext('Request processed in %01.2fs'), $t1));

	$self->{busy} = false;

	return true;
}

sub set_status {
	my ($self, $msg) = @_;
	$self->{status}->push($self->{status}->get_context_id(ref($self)), $msg);
	$self->update_ui;
	return true;
}

sub get_selected_template_iter {
	my $self = shift;

	my ($path) = $self->{template_list}->get_selection->get_selected_rows;
	if ($path) {
		my $path = $path->to_string;
		return $self->{template_list}->get_model->get_iter_from_string($path);
	}

	return false;
}

sub select_template {
	my $self = shift;
	my $iter = $self->get_selected_template_iter;
	if ($iter) {
		my $row = [$self->{template_list}->get_model->get_value($iter)];

		if ($row->[2] == 1) {
			$self->read_file($row->[1]);

		} elsif ($row->[1] ne '') {
			$self->{input_view}->get_buffer->set_text($row->[1]);

		}

	}

	return true;
}


sub template_selected {
	my $self = shift;
	my $iter = $self->get_selected_template_iter;
	if ($iter) {
		my $row = [$self->{template_list}->get_model->get_value($iter)];
		$self->{delete_template_button}->set_sensitive($row->[2] == 1);
	}
	return true;
}

sub view_greeting {
	my $self = shift;
	$self->{greeting_window}->show_all;
	return true;
}

sub close_greeting_window {
	my $self = shift;
	$self->{greeting_window}->hide;
	return true;
}

sub toggle_wrap_lines {
	my $self = shift;
	my $bool = $self->{wrap_lines_menu_item}->get_active;

	$self->{input_view}->set_wrap_mode($bool	? 'char' : 'none');
	$self->{output_view}->set_wrap_mode($bool	? 'char' : 'none');
	$self->{greeting_view}->set_wrap_mode($bool	? 'char' : 'none');

	$self->{gconf}->set_bool("$self->{gconf_base}/wrap_lines", $bool);

	return true;
}

sub toggle_line_numbers {
	my $self = shift;
	my $bool = $self->{view_line_numbers_menu_item}->get_active;

	$self->{input_view}->set_show_line_numbers($bool);
	$self->{output_view}->set_show_line_numbers($bool);
	$self->{greeting_view}->set_show_line_numbers($bool);

	$self->{gconf}->set_bool("$self->{gconf_base}/show_line_numbers", $bool);

	return true;
}

sub delete_template {
	my $self = shift;

	my $iter = $self->get_selected_template_iter;
	if ($iter) {
		my $row = [$self->{template_list}->get_model->get_value($iter)];

		my $key = "$self->{gconf_base}/template_list";

		my @list = split(/,/, $self->{gconf}->get_string($key));
		@list = grep { $_ ne $row->[1] } @list;
		$self->{gconf}->set_string($key, join(',', @list));

		$self->build_template_list;

	}

	return true;
}

sub validate_input_buffer {
	my $self = shift;
	my $input = $self->{input_view}->get_buffer->get_text(
		$self->{input_view}->get_buffer->get_start_iter,
		$self->{input_view}->get_buffer->get_end_iter,
		false,
	);

	my ($icon, $markup, $doc);
	eval { $doc = $self->{parser}->parse_string($input) };
	if ($@) {
		$icon = 'gtk-dialog-error';
		$markup = gettext('input is not well formed');

	} else {
		if ($self->{schema}) {
			eval { $self->{schema}->validate($doc) };
		}

		if ($@) {
			$icon = 'gtk-dialog-error';
			chomp($@);
			$markup = encode_entities_numeric(sprintf(gettext('Schema validation error: %s'), $@));
			
		} else {
			$icon = 'gtk-apply';
			if ($self->{schema}) {
				$markup = gettext('input is valid');

			} else {
				$markup = gettext('input is well-formed');

			}

		}

	}

	$self->{input_status_label}->set_markup($markup);
	$self->{input_status_icon}->set_from_stock($icon, 'menu');
	$self->{input_status_icon}->show;

	return true;
}

sub validate_output_buffer {
	my $self = shift;
	my $output = $self->{output_view}->get_buffer->get_text(
		$self->{output_view}->get_buffer->get_start_iter,
		$self->{output_view}->get_buffer->get_end_iter,
		false,
	);

	my ($icon, $markup, $doc);
	eval { $doc = $self->{parser}->parse_string($output) };
	if ($@) {
		$icon = 'gtk-dialog-error';
		$markup = gettext('output is not well formed');

	} else {
		if ($self->{schema}) {
			eval { $self->{schema}->validate($doc) };
		}

		if ($@) {
			$icon = 'gtk-dialog-error';
			chomp($@);
			$markup = encode_entities_numeric(sprintf(gettext('Schema validation error: %s'), $@));
			
		} else {
			$icon = 'gtk-apply';
			if ($self->{schema}) {
				$markup = gettext('output is valid');

			} else {
				$markup = gettext('output is well-formed');

			}

		}

	}

	$self->{output_status_label}->set_markup($markup);
	$self->{output_status_icon}->set_from_stock($icon, 'menu');
	$self->{output_status_icon}->show;

	return true;
}

sub keep_alive {
	my $self = shift;
	return true unless ($self->{connected});
	return true if ($self->{busy});

	# Check if user has activated keep_alive
	if ($self->{gconf}->get_bool($self->{gconf_base}.'/keep_connection_alive'))
	{
		eval {
			local $SIG{ALRM} = sub { croak("ALRM\n") };
			alarm($self->{connect_timeout_spinbutton}->get_value);
			$self->{epp}->request(Net::EPP::Frame::Hello->new);
			alarm(0);
		};
		if ($@) {
			alarm(0);
			$self->disconnect;
			$self->error(gettext('Disconnected from server.'));
		}
	}
	return true;
}

sub show_transaction_error_box {
	my ($self, $err) = @_;
	$self->{transaction_error_view}->get_buffer->set_text($err);
	$self->{output_scrwin}->hide;
	$self->{output_label}->hide;
	$self->{transaction_error_box}->show_all;

	return true;
}

sub hide_transaction_error_box {
	my $self = shift;
	$self->{transaction_error_box}->hide;
	$self->{output_scrwin}->show_all;
	$self->{output_label}->show_all;

	return true;
}

sub reconnect {
	my $self = shift;
	$self->disconnect;
	$self->connect;
}

sub parse_peer_certificate {
	my $self = shift;

	@{$self->{cert_info_treeview}->{data}} = ();

	my $issuer	= $self->{epp}->{connection}->peer_certificate('issuer');
	my $subject	= $self->{epp}->{connection}->peer_certificate('subject');

	$subject =~ s/\/([A-Za-z]+?=)/\n$1/img;
	$subject =~ s/^\n+//g;
	$subject =~ s/\n+$//g;
	foreach my $pair (split(/\n/, $subject)) {
		my ($name, $value) = split(/=/, $pair, 2);
		push(@{$self->{cert_info_treeview}->{data}}, [ sprintf(gettext("Peer's %s"), ($CERT_KEYS{$name} ? $CERT_KEYS{$name} : $name)), $value ]);
	}

	$issuer	=~ s/\/([A-Za-z]+?=)/\n$1/img;
	$issuer =~ s/^\n+//g;
	$issuer =~ s/\n+$//g;
	foreach my $pair (split(/\n/, $issuer)) {
		my ($name, $value) = split(/=/, $pair, 2);
		push(@{$self->{cert_info_treeview}->{data}}, [ sprintf(gettext("Issuer's %s"), ($CERT_KEYS{$name} ? $CERT_KEYS{$name} : $name)), $value ]);
	}

	return true;
}

sub show_cert_info_dialog {
	my $self = shift;
	$self->{cert_info_dialog}->show_all;
	return true;
}

sub close_cert_info_dialog {
	my $self = shift;
	$self->{cert_info_dialog}->hide;
	return true;
}

sub show_log_window {
	my $self = shift;
	$self->{log_window}->show_all;
	return true;
}

sub hide_log_window {
	my $self = shift;
	$self->{log_window}->hide;
	return true;
}

sub compare_new_passwords {
	my $self = shift;
	$self->{connect_button}->set_sensitive($self->{newPW1}->get_text eq $self->{newPW2}->get_text);
}

sub clear_log {
	my $self = shift;
	foreach my $child ($self->{log_view_vbox}->get_children) {
		$self->{log_view_vbox}->remove($child);
		$child->destroy;
	}
	return true;
}

sub append_log {
	my ($self, $xml, $type) = @_;

	chomp($xml);

	my $prefix = ($type eq FROM_CLIENT ? 'C:' : 'S:');
	$xml =~ s/([\n|\r\n])/$1$prefix/g;
	$xml = $prefix.$xml;

	my $view = Gtk2::SourceView::View->new_with_buffer(Gtk2::SourceView::Buffer->new_with_language($self->{lang}));
	$view->get_buffer->set_text($xml);
	$view->get_buffer->set_highlight(true);
	$view->modify_font(Gtk2::Pango::FontDescription->from_string($self->{gconf}->get_string('/desktop/gnome/interface/monospace_font_name')));

	$self->{log_view_vbox}->pack_start(Gtk2::HSeparator->new, 0, 0, 0) if (scalar($self->{log_view_vbox}->get_children) > 0);
	$self->{log_view_vbox}->pack_start($view, 1, 1, 0);
	$self->{log_view_vbox}->show_all;

	return true;

}

sub get_command_from_input {
	my ($self, $input) = @_;

	my ($input_xml, $cmd);

	$cmd = gettext('Unknown');

	eval {
		$input_xml = $self->{parser}->parse_string($input);
	};

	if ($input_xml && $@ eq '') {
		my $els = $input_xml->getElementsByLocalName('hello');
		if ($els->size == 1) {
			$cmd = 'hello';

		} else {
			my $els = $input_xml->getElementsByLocalName('command');
			if ($els->size == 1) {
				my $el = $els->shift;
				foreach my $child ($el->childNodes) {
					if (ref($child) ne 'XML::LibXML::Text') {
						$cmd = $child->nodeName;
						foreach my $grandchild ($child->childNodes) {
							if (ref($grandchild) ne 'XML::LibXML::Text') {
								my ($type, $command) = split(/:/, $grandchild->nodeName, 2);
								$cmd = $command.'.'.$type;
								last;
							}
						}
						last;
					}
				}
			}
		}
	}

	return $cmd;

}

sub update_host_entry_completion_store {
	my $self = shift;
	$self->{host_store}->clear;
	foreach my $host (@{$self->{host_history}}) {
		$self->{host_store}->set($self->{host_store}->append, 0, $host);
	}
	return true;
}

sub update_userid_entry_completion_store {
	my $self = shift;
	$self->{userid_store}->clear;
	foreach my $host (@{$self->{userid_history}}) {
		$self->{userid_store}->set($self->{userid_store}->append, 0, $host);
	}
	return true;
}

1;

__PACKAGE__->new;

Gtk2->main;

exit;
