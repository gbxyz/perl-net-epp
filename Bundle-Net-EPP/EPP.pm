# $Id: EPP.pm,v 1.4 2008/01/09 17:58:49 gavin Exp $
package Bundle::Net::EPP;

$VERSION = '0.02';

__END__

=pod

=head1 NAME

Bundle::Net::EPP - A bundle to install all EPP related modules.

=head1 SYNOPSIS

C<cpan -i Bundle::Net::EPP>

=head1 CONTENTS

IO::Socket::SSL		- Nearly transparent SSL encapsulation for IO::Socket::INET

XML::LibXML		- Perl Binding for libxml2

Net::EPP::Client	- a client library for the TCP transport for EPP, the Extensible Provisioning Protocol

Net::EPP::Frame		- An EPP XML frame system built on top of XML::LibXML.

Net::EPP::Proxy		- a proxy server for the EPP protocol

Net::EPP::ResponseCodes	- a module to export some constants that correspond to EPP response codes

Net::EPP::Simple	- a simple EPP client interface for the most common jobs

=head1 DESCRIPTION

EPP is the Extensible Provisioning Protocol. EPP (defined in RFC 4930) is an
application layer client-server protocol for the provisioning and management of
objects stored in a shared central repository. Specified in XML, the protocol
defines generic object management operations and an extensible framework that
maps protocol operations to objects. As of writing, its only well-developed
application is the provisioning of Internet domain names, hosts, and related
contact details.

A number of EPP-related modules are available via CPAN; this bundle will
allow you to install them all in one fell swoop.

=head1 AUTHOR

CentralNic Ltd (L<http://www.centralnic.com/>).

=head1 COPYRIGHT

This module is (c) 2007 CentralNic Ltd. This module is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

=over

=item * RFCs 4930 and RFC 4934, available from L<http://www.ietf.org/>.

=item * The CentralNic EPP site at L<http://www.centralnic.com/resellers/epp>.

=back

=cut

