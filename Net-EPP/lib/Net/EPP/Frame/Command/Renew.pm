package Net::EPP::Frame::Command::Renew;
use Net::EPP::Frame::Command::Renew::Domain;
use base qw(Net::EPP::Frame::Command);
use strict;

=pod

=head1 NAME

Net::EPP::Frame::Command::Renew - an instance of L<Net::EPP::Frame::Command>
for the EPP C<E<lt>renewE<gt>> command.

=head1 OBJECT HIERARCHY

    L<XML::LibXML::Node>
    +----L<XML::LibXML::Document>
        +----L<Net::EPP::Frame>
            +----L<Net::EPP::Frame::Command>
                +----L<Net::EPP::Frame::Command::Renew>

=head1 METHODS

This module does not define any methods in addition to those it inherits from
its ancestors.

=cut

1;
