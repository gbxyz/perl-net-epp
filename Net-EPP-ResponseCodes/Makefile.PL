#!/usr/bin/perl
# $Id: Makefile.PL,v 1.1 2007/12/03 12:05:23 gavin Exp $

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'			=> 'Net::EPP::ResponseCodes',
    'VERSION_FROM'		=> 'lib/Net/EPP/ResponseCodes.pm',
    'PREREQ_PM'			=> {
        'IO::Socket::SSL'	=> 0,
        'Net::EPP::Client'	=> 0,
        'Net::EPP::Frame'	=> 0,
        'Time::HiRes'		=> 0,
        'Digest::SHA1'		=> 0,
    },
);
