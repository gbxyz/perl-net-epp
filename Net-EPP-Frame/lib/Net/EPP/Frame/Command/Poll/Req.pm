# Copyright (c) 2007 CentralNic Ltd. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the same
# terms as Perl itself.
# 
# $Id: Req.pm,v 1.3 2007/12/03 11:44:52 gavin Exp $
package Net::EPP::Frame::Command::Poll::Req;
use base qw(Net::EPP::Frame::Command::Poll);
use strict;

=pod

=head1 NAME

Net::EPP::Frame::Command::Poll::Req - an instance of L<Net::EPP::Frame::Command>
for the EPP C<E<lt>PollE<gt>> request command.

=head1 OBJECT HIERARCHY

    L<XML::LibXML::Node>
    +----L<XML::LibXML::Document>
        +----L<Net::EPP::Frame>
            +----L<Net::EPP::Frame::Command>
                +----L<Net::EPP::Frame::Command::Poll>

=cut

sub new {
	my $package = shift;
	my $self = bless($package->SUPER::new('poll'), $package);
	$self->getCommandNode->setAttribute('op' => 'req');
	return $self;
}

=head1 METHODS

This module does not define any methods in addition to those it inherits from
its ancestors.

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
