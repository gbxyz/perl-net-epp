#!/usr/bin/perl
# $Id: Makefile.PL,v 1.3 2008/04/08 12:56:33 gavin Exp $

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'			=> 'Net::EPP::Frame',
    'VERSION_FROM'		=> 'lib/Net/EPP/Frame.pm',
    'PREREQ_PM'			=> {
        'XML::LibXML'		=> 0,
        'Net::EPP::ResponseCodes' => 0,
    },
);
