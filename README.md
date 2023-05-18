# NAME

Net::EPP - a Perl library for the Extensible Provisioning Protocol (EPP)

# DESCRIPTION

EPP is the Extensible Provisioning Protocol. EPP (defined in RFC 5730)
is an application layer client-server protocol for the provisioning and
management of objects stored in a shared central repository. Specified
in XML, the protocol defines generic object management operations and an
extensible framework that maps protocol operations to objects. As of
writing, its only well-developed application is the provisioning of
Internet domain names, hosts, and related contact details.

This package offers a number of Perl modules which implement various
EPP-related functions:

- a low level protocol implementation ([Net::EPP::Protocol](https://metacpan.org/pod/Net%3A%3AEPP%3A%3AProtocol))
- a low-level client ([Net::EPP::Client](https://metacpan.org/pod/Net%3A%3AEPP%3A%3AClient))
- a high(er)-level client ([Net::EPP::Simple](https://metacpan.org/pod/Net%3A%3AEPP%3A%3ASimple))
- an EPP frame builder ([Net::EPP::Frame](https://metacpan.org/pod/Net%3A%3AEPP%3A%3AFrame))
- a utility library to export EPP responde codes ([Net::EPP::ResponseCodes](https://metacpan.org/pod/Net%3A%3AEPP%3A%3AResponseCodes))

These modules were originally created and maintained by CentralNic for
use by their own registrars, but since their original release have
become widely used by registrars and registries of all kinds.

CentralNic has chosen to create this project to allow interested third
parties to contribute to the development of these libraries, and to
guarantee their long-term stability and maintenance. 

# AUTHOR

CentralNic Ltd (http://www.centralnic.com/), with the assistance of other contributors around the world, including (but not limited to):

- Rick Jansen
- Mike Kefeder
- Sage Weil
- Eberhard Lisse
- Yulya Shtyryakova
- Ilya Chesnokov
- Simon Cozens
- Patrick Mevzek
- Alexander Biehl and Christian Maile, united-domains AG

# COPYRIGHT

This module is (c) 2008 - 2023 CentralNic Ltd. This module is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.
