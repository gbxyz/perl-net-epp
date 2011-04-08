# Copyright (c) 2011 CentralNic Ltd. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the same
# terms as Perl itself.
# 
# $Id$
package Net::EPP::Frame::Command::Create::Host;
use base qw(Net::EPP::Frame::Command::Create);
use Net::EPP::Frame::ObjectSpec;
use strict;

1;

=pod

=head1 NAME

Net::EPP::Frame::Command::Create::Host - an instance of L<Net::EPP::Frame::Command::Create>
for host objects.

=head1 OBJECT HIERARCHY

    L<XML::LibXML::Node>
    +----L<XML::LibXML::Document>
        +----L<Net::EPP::Frame>
            +----L<Net::EPP::Frame::Command>
                +----L<Net::EPP::Frame::Command::Create>
                    +----L<Net::EPP::Frame::Command::Create::Host>

=cut

