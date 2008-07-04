#!/usr/bin/perl
# $Id: Makefile.PL,v 1.5 2006/02/14 14:30:01 gavin Exp $

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'			=> 'Net::EPP::Client',
    'VERSION_FROM'		=> 'lib/Net/EPP/Client.pm',
    'PREREQ_PM'			=> {
        'IO::Socket'		=> 0,
        'IO::Socket::SSL'	=> 0,
        'XML::LibXML'		=> 0,
    },
);
