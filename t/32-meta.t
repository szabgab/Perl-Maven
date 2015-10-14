#!/usr/bin/env perl
use strict;
use warnings;
use v5.10;

use Test::Most;
plan tests => 2;

use Perl::Maven::Config;
use Perl::Maven::CreateMeta;

my $mymaven = Perl::Maven::Config->new('t/files/config/test.yml');
$ENV{METAMETA} = 1;

my $domain_name = $mymaven->{config}{installation}{domain};
is $domain_name, 'test-pm.com';

my $meta = Perl::Maven::CreateMeta->new( mymaven => $mymaven, );
$meta->process_domain($domain_name);

pass;
