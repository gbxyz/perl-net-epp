# Copyright (c) 2010 CentralNic Ltd. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the same
# terms as Perl itself.
# 
# $Id: Host.pm,v 1.3 2008/01/23 12:26:24 gavin Exp $
package Net::EPP::Frame::Command::Update::Host;
use base qw(Net::EPP::Frame::Command::Update);
use Net::EPP::Frame::ObjectSpec;
use strict;

=pod

=head1 NAME

Net::EPP::Frame::Command::Update::Host - an instance of L<Net::EPP::Frame::Command::Update>
for host objects.

=head1 SYNOPSIS

	use Net::EPP::Frame::Command::Update::Host;
	use strict;

	my $info = Net::EPP::Frame::Command::Update::Host->new;
	$info->setHost('ns0.example.tld');

	print $info->toString(1);

This results in an XML document like this:

	<?xml version="1.0" encoding="UTF-8"?>
	<epp xmlns="urn:ietf:params:xml:ns:epp-1.0"
	  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	  xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0
	  epp-1.0.xsd">
	    <command>
	      <info>
	        <host:update
	          xmlns:host="urn:ietf:params:xml:ns:host-1.0"
	          xsi:schemaLocation="urn:ietf:params:xml:ns:host-1.0
	          host-1.0.xsd">
	            <host:name>example-1.tldE<lt>/host:name>
	        </host:update>
	      </info>
	      <clTRID>0cf1b8f7e14547d26f03b7641660c641d9e79f45</clTRIDE<gt>
	    </command>
	</epp>

=head1 OBJECT HIERARCHY

    L<XML::LibXML::Node>
    +----L<XML::LibXML::Document>
        +----L<Net::EPP::Frame>
            +----L<Net::EPP::Frame::Command>
                +----L<Net::EPP::Frame::Command::Update>
                    +----L<Net::EPP::Frame::Command::Update::Host>

=cut

sub new {
	my $package = shift;
	my $self = bless($package->SUPER::new('update'), $package);

	my $host = $self->addObject(Net::EPP::Frame::ObjectSpec->spec('host'));

	foreach my $grp (qw(add rem chg)) {
		my $el = $self->createElement(sprintf('host:%s', $grp));
		$self->getNode('update')->getChildNodes->shift->appendChild($el);
	}

	return $self;
}

=pod

=head1 METHODS

	$frame->setHost($host_name);

This specifies the host object to be updated.

=cut

sub setHost {
	my ($self, $host) = @_;

	my $name = $self->createElement('host:name');
	$name->appendText($host);

	$self->getNode('update')->getChildNodes->shift->appendChild($name);

	return 1;
}

=pod

=head1 AUTHOR

CentralNic Ltd (http://www.centralnic.com/).

=head1 COPYRIGHT

This module is (c) 2007 CentralNic Ltd. This module is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

=over

=item * L<Net::EPP::Frame>

=back

=cut

1;
