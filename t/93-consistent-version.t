use strict;
use warnings;
use Test::More;

## no critic
eval 'use Test::ConsistentVersion 0.2.3';
plan skip_all =>
	"Test::ConsistentVersion 0.2.3 required for checking versions"
	if $@;
Test::ConsistentVersion::check_consistent_versions();

