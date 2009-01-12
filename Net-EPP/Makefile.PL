#!/usr/bin/perl
# $Id$
use ExtUtils::MakeMaker;
use strict;

WriteMakefile(
	'NAME'		=> 'Net::EPP',
	'VERSION'	=> '0.12',
	'PREREQ_PM'	=> {
		'IO::Socket::SSL'	=> 0,
		'XML::LibXML'		=> 0,
		'Time::HiRes'		=> 0,
		'Digest::SHA1'		=> 0,
	},
);
