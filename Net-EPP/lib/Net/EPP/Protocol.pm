# Copyright (c) 2008 CentralNic Ltd. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the same
# terms as Perl itself.
package Net::EPP::Protocol;
use bytes;
use Carp;
use strict;

=pod

=head1 NAME

Net::EPP::Protocol - Low-level functions useful for both EPP clients and
servers.

=head1 SYNOPSIS

	#!/usr/bin/perl
	use Net::EPP::Protocol;
	use IO::Socket;
	use strict;

	# create a socket:

	my $socket = IO::Socket::INET->new( ... );

	# send a frame down the socket:

	Net::EPP::Protocol->send_frame($frame);

	# get a frame from the socket:

	Net::EPP::Protocol->get_frame($frame);

=head1 DESCRIPTION

EPP is the Extensible Provisioning Protocol. EPP (defined in RFC 4930)
is an application layer client-server protocol for the provisioning and
management of objects stored in a shared central repository. Specified
in XML, the protocol defines generic object management operations and an
extensible framework that maps protocol operations to objects. As of
writing, its only well-developed application is the provisioning of
Internet domain names, hosts, and related contact details.

This module implements functions that are common to both EPP clients and
servers that implement the TCP transport as defined in RFC 4934. The
main consumer of this module is currently L<Net::EPP::Client>.

=head1 METHODS

	my $xml = Net::EPP::Protocol->get_frame($socket);

=cut

sub get_frame {
	my ($class, $fh) = @_;

	my $hdr;
	$fh->read($hdr, 4);
	my $length = (unpack('N', $hdr) - 4);
	if ($length < 1) {
		croak("Got a bad frame length from server - connection closed?");

	} else {
		my $frame = '';
		my $buffer;
		while (length($frame) < $length) {
			$buffer = '';
			$fh->read($buffer, ($length - length($frame)));
			last if (length($buffer) == 0); # in case the socket has closed
			$frame .= $buffer;
		}

		return $frame;

	}

}

=pod

	Net::EPP::Protocol->send_frame($socket, $xml);

This method prepares an RFC 4934 compliant EPP frame and transmits it to
the remote peer. C<$socket> must be an L<IO::Handle> or one of its
subclasses (ie C<IO::Socket::*>).

If the transmission fails for whatever reason, this method will
C<croak()>, so be sure to enclose it in an C<eval()>. Otherwise, it will
return a true value.

=cut

sub send_frame {
	my ($class, $fh, $frame) = @_;
	croak("Connection closed") if (ref($fh) ne 'IO::Socket::SSL' && $fh->eof); # eof() dies for me
	$fh->print(pack('N', length($frame) + 4).$frame);
	return 1;
}


=pod

=head1 AUTHOR

CentralNic Ltd (L<http://www.centralnic.com/>).

=head1 COPYRIGHT

This module is (c) 2008 CentralNic Ltd. This module is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

=over

=item * L<Net::EPP::Client>

=item * RFCs 4930 and RFC 4934, available from L<http://www.ietf.org/>.

=item * The CentralNic EPP site at L<http://www.centralnic.com/resellers/epp>.

=back

=cut

1;
