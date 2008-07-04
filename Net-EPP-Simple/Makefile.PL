#!/usr/bin/perl
# $Id: Makefile.PL,v 1.2 2007/11/28 14:36:30 gavin Exp $

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'			=> 'Net::EPP::Simple',
    'VERSION_FROM'		=> 'lib/Net/EPP/Simple.pm',
    'PREREQ_PM'			=> {
        'IO::Socket::SSL'	=> 0,
        'Net::EPP::Client'	=> 0,
        'Net::EPP::Frame'	=> 0,
        'Time::HiRes'		=> 0,
        'Digest::SHA1'		=> 0,
    },
);
