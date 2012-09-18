#!/usr/bin/perl
use strict;
use warnings;
use v5.12;

use Data::Dumper qw(Dumper);
use DBI;
use Getopt::Long qw(GetOptions);

my $dsn = "dbi:SQLite:dbname=pm.db";
my $dbh = DBI->connect($dsn, "", "", {
	RaiseError => 1,
	PrintError => 0,
	AutoCommit => 1,
});

my %opt;
GetOptions(\%opt,
	'products',
) or usage();

if ($opt{products}) {
	my $products = $dbh->selectall_arrayref(q{
	   SELECT *
	   FROM product
	});
	print Dumper $products;
	exit;
}

usage();


sub usage {
	print <<"END_USAGE";
Usage: $0
    --products
END_USAGE
	exit;
}

