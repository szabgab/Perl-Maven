use strict;
use warnings;
use Test::More;

## no critic
eval 'use Test::Perl::Critic 1.02';
plan skip_all => 'Test::Perl::Critic 1.02 required' if $@;

all_critic_ok();

