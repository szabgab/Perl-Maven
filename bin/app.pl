#!/usr/bin/env perl
use Dancer;
if ( $ENV{PERL_MAVEN_TEST} ) {
	set log          => 'warning';
	set startup_info => 0;
}

if ( $ENV{PERL_MAVEN_PORT} ) {
	set port => $ENV{PERL_MAVEN_PORT};
}
use Perl::Maven;
dance;
