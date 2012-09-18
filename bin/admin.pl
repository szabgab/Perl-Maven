#!/usr/bin/perl
use strict;
use warnings;
use v5.12;

# TODO --addsub  product  --email  email@address     add the specific product to the specific user

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
	'address=s',
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
	my $format = "%-35s %5s\n";
	foreach my $pid (sort keys %$products) {
		printf $format, $products->{$pid}{code}, $subs->{$pid}{cnt};
	}
	my $all_subs = $dbh->selectrow_array(q{SELECT COUNT(uid) FROM subscription WHERE pid != 1});
	my $distinct_subs = $dbh->selectrow_array(q{SELECT COUNT(DISTINCT(uid)) FROM subscription WHERE pid != 1});
	say '-' x 45;
	printf $format, "Total 'purchases':", $all_subs;
	printf $format, "Distinct # of clients:", $distinct_subs;
} elsif ($opt{address}) {
	my $people = $dbh->selectall_arrayref(q{
	   SELECT id, email, verify_time
	   FROM user WHERE email LIKE ?
	}, undef, '%' . $opt{address} . '%');
	foreach my $p (@$people) {
		$p->[2] //= '-';
		printf "%4s %30s  %s\n", @$p;
	}
} else {
	usage();
}

sub usage {
	print <<"END_USAGE";
Usage: $0
    --products
    --stats
    --address   FILTER_FOR_EMAIL
END_USAGE
	exit;
}

