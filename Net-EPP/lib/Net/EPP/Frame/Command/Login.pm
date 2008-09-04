# Copyright (c) 2007 CentralNic Ltd. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the same
# terms as Perl itself.
# 
# $Id: Login.pm,v 1.5 2007/12/03 11:44:52 gavin Exp $
package Net::EPP::Frame::Command::Login;
use base qw(Net::EPP::Frame::Command);
use strict;

=pod

=head1 NAME

Net::EPP::Frame::Command::Login - an instance of L<Net::EPP::Frame::Command>
for the EPP C<E<lt>loginE<gt>> command.

=head1 OBJECT HIERARCHY

    L<XML::LibXML::Node>
    +----L<XML::LibXML::Document>
        +----L<Net::EPP::Frame>
            +----L<Net::EPP::Frame::Command>
                +----L<Net::EPP::Frame::Command::Login>

=cut

sub _addCommandElements {
	my $self = shift;
	$self->getNode('login')->addChild($self->createElement('clID'));
	$self->getNode('login')->addChild($self->createElement('pw'));
	$self->getNode('login')->addChild($self->createElement('options'));
	$self->getNode('login')->addChild($self->createElement('svcs'));
}

=pod

=head1 METHODS

	my $node = $frame->clID;

This method returns the L<XML::LibXML::Element> object corresponding to the
C<E<lt>clIDE<gt>> element.

	my $node = $frame->pw;

This method returns the L<XML::LibXML::Element> object corresponding to the
C<E<lt>pwE<gt>> element.

	my $node = $frame->svcs;

This method returns the L<XML::LibXML::Element> object corresponding to the
C<E<lt>svcsE<gt>> element.

	my $node = $frame->options;

This method returns the L<XML::LibXML::Element> object corresponding to the
C<E<lt>optionsE<gt>> element.

=cut

sub clID { $_[0]->getNode('clID') }
sub pw { $_[0]->getNode('pw') }
sub svcs { $_[0]->getNode('svcs') }
sub options { $_[0]->getNode('options') }

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
