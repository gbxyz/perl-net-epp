# Copyright (c) 2010 CentralNic Ltd. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the same
# terms as Perl itself.
# 
# $Id: Domain.pm,v 1.3 2007/12/03 11:44:52 gavin Exp $
package Net::EPP::Frame::Command::Update::Domain;
use base qw(Net::EPP::Frame::Command::Update);
use Net::EPP::Frame::ObjectSpec;
use strict;

=pod

=head1 NAME

Net::EPP::Frame::Command::Update::Domain - an instance of L<Net::EPP::Frame::Command::Update>
for domain names.

=head1 SYNOPSIS

	use Net::EPP::Frame::Command::Update::Domain;
	use strict;

	my $info = Net::EPP::Frame::Command::Update::Domain->new;
	$info->setDomain('example.tld');

	print $info->toString(1);

This results in an XML document like this:

	<?xml version="1.0" encoding="UTF-8"?>
	<epp xmlns="urn:ietf:params:xml:ns:epp-1.0"
	  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	  xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0
	  epp-1.0.xsd">
	    <command>
	      <info>
	        <domain:update
	          xmlns:domain="urn:ietf:params:xml:ns:domain-1.0"
	          xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0
	          domain-1.0.xsd">
	            <domain:name>example-1.tldE<lt>/domain:name>
	        </domain:update>
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
                    +----L<Net::EPP::Frame::Command::Update::Domain>

=cut

sub new {
	my $package = shift;
	my $self = bless($package->SUPER::new('update'), $package);

	my $domain = $self->addObject(Net::EPP::Frame::ObjectSpec->spec('domain'));

	foreach my $grp (qw(add rem chg)) {
		my $el = $self->createElement(sprintf('domain:%s', $grp));
		$self->getNode('update')->getChildNodes->shift->appendChild($el);
	}

	return $self;
}

=pod

=head1 METHODS

	$frame->setDomain($domain_name);

This specifies the domain name to be updated.

=cut

sub setDomain {
	my ($self, $domain) = @_;

	my $name = $self->createElement('domain:name');
	$name->appendText($domain);

	$self->getNode('update')->getChildNodes->shift->appendChild($name);

	return 1;
}

=pod

	$frame->addStatus($type, $info);

Add a status of $type with the optional extra $info.

=cut
sub addStatus {
	my ($self, $type, $info) = @_;
	my $status = $self->createElement('domain:status');
	$status->setAttribute('s', $type);
	$status->setAttribute('lang', 'en');
	if ($info) {
		$status->appendText($info);
	}
	$self->getElementsByLocalName('domain:add')->shift->appendChild($status);
}

=pod

	$frame->remStatus($type);

Remove a status of $type.

=cut
sub remStatus {
	my ($self, $type) = @_;
	my $status = $self->createElement('domain:status');
	$status->setAttribute('s', $type);
	$self->getElementsByLocalName('domain:rem')->shift->appendChild($status);
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
