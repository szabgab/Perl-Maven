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
	'stats',
) or usage();

if ($opt{products}) {
	my $products = $dbh->selectall_arrayref(q{
	   SELECT *
	   FROM product
	});
	print Dumper $products;
} elsif ($opt{stats}) {
	my $products = $dbh->selectall_hashref(q{
	   SELECT *
	   FROM product
	}, 'id');
	#print Dumper $products;
	my $subs = $dbh->selectall_hashref(q{SELECT pid, COUNT(*) cnt FROM subscription GROUP BY pid}, 'pid');
	foreach my $pid (sort keys %$products) {
		printf "%-35s %5s\n", $products->{$pid}{code}, $subs->{$pid}{cnt};
	}
} else {
	usage();
}

sub usage {
	print <<"END_USAGE";
Usage: $0
    --products
    --stats
END_USAGE
	exit;
}

