#!/usr/bin/perl

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'			=> 'Net::EPP',
    'VERSION'			=> '0.10',
    'PREREQ_PM'			=> {
        'IO::Socket::SSL'	=> 0,
        'XML::LibXML'		=> 0,
        'Time::HiRes'		=> 0,
        'Digest::SHA1'		=> 0,
    },
);
