use strict;
use warnings;

use Test::More;

plan tests => 3;

use Perl::Maven::Config;
my $mymaven = Perl::Maven::Config->new('t/files/mymaven.yml');
my $main    = $mymaven->config('perlmaven.com');
my $br      = $mymaven->config('br.perlmaven.com');

is $main->{site}, '/home/foobar/perlmaven.com/sites/en';
is_deeply $main->{redirect},
	{
	'abc'      => 'def',
	'szg'      => 'http://szabgab.com/?r=12345',
	'products' => 'http://perlmaven.com/products',
	};

is_deeply $br->{redirect}, {
	'products'    => 'http://perlmaven.com/products',
	'old-article' => 'new-article',
	'abc'         => 'other-page',

	'szg' => 'http://szabgab.com/?r=12345',
};

