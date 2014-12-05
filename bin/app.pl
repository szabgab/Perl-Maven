#!/usr/bin/env perl
use Dancer;
if ( $ENV{PERL_MAVEN_TEST} ) {
	set log          => 'warning';
	set startup_info => 0;
}

use Perl::Maven;
dance;
