#!/usr/bin/perl
use strict;
use warnings;
use v5.12;

use Data::Dumper qw(Dumper);
use DBI;
use Getopt::Long qw(GetOptions);

use lib 'lib';

use Perl::Maven::DB;
my $db = Perl::Maven::DB->new('pm.db');

my $dsn = 'dbi:SQLite:dbname=pm.db';
my $dbh = DBI->connect(
	$dsn, '', '',
	{
		RaiseError => 1,
		PrintError => 0,
		AutoCommit => 1,
	}
);

my %opt;
GetOptions(
	\%opt,
	'products',
	'stats',
	'show',
	'list=s',
	'replace=s',

	'addsub=s',
	'email=s',

	'unsub=s',
	'dump'
) or usage();

if ( $opt{email} ) {
	$opt{email} = lc $opt{email};
}

if ( $opt{products} ) {
	my $products = $db->get_products;

	if ( $opt{dump} ) {

		#die Dumper $products;
		print Dumper $products;
	}
	else {
		foreach my $p ( sort keys %$products ) {
			my %h = %{ $products->{$p} };
			printf "%2s %-35s %-33s %3s\n", @h{qw(id code name price)};
		}
	}
}
elsif ( $opt{stats} ) {
	my $stats = $db->stats;

	my $format = "%-35s %5s\n";
	printf $format, 'Product code', 'Number of subscribers';
	foreach my $code ( sort keys %{ $stats->{products} } ) {
		printf $format, $stats->{products}{$code}{code},
			$stats->{products}{$code}{cnt},
			;
	}
	say '-' x 45;
	printf $format, q{Total 'purchases':},     $stats->{all_subs};
	printf $format, q{Distinct # of clients:}, $stats->{distinct_subs};
	print "\n";
	printf $format, 'All the users', $stats->{all_users};
	printf $format, 'Verified',
		( $stats->{all_users} - $stats->{not_verified} );
	printf $format, 'NOT Verified',             $stats->{not_verified};
	printf $format, 'Verified but NO password', $stats->{no_password};

}
elsif ( $opt{show} and $opt{email} ) {
	show_people( $opt{email} );
}
elsif ( $opt{replace} and $opt{email} ) {
	show_people( $opt{email} );
	$db->replace_email( $opt{email}, $opt{replace} );
	show_people( $opt{replace} );
}
elsif ( $opt{addsub} and $opt{email} ) {
	my $res = $db->subscribe_to( $opt{email}, $opt{addsub} );
	if ($res) {
		usage("Could not find product '$opt{addsub}'")
			if $res eq 'no_such_code';
		usage("Could not find user '$opt{email}'") if $res eq 'no_such_email';
	}

	#print "PID: $pid  UID: $uid\n";
	show_people( $opt{email} );
}
elsif ( $opt{unsub} and $opt{email} ) {
	my $res = $db->unsubscribe_from( $opt{email}, $opt{unsub} );

	#print "PID: $pid  UID: $uid\n";
	if ($res) {
		usage("Could not find product '$opt{addsub}'")
			if $res eq 'no_such_code';
		usage("Could not find user '$opt{email}'") if $res eq 'no_such_email';
	}
	show_people( $opt{email} );
}
elsif ( $opt{list} ) {
	my $emails = $db->get_subscribers( $opt{list} );

	foreach my $e ( sort { $a->[0] cmp $b->[0] } @$emails ) {
		say "$e->[0]";
	}
}
else {
	usage();
}
exit;
#######################################################################################################

sub show_people {
	my ($email) = @_;

	my $people = $db->get_people($email);
	foreach my $p (@$people) {
		$p->[2] //= '-';
		my @subs = $db->get_subscriptions( $p->[1] );
		printf "%4s %30s  verify_time='%s'\n", @$p;
		foreach my $s (@subs) {
			printf "     %s\n", $s;
		}
	}
	return;
}

sub usage {
	my ($msg) = @_;

	if ($msg) {
		print "*** $msg\n\n";
	}

	print <<"END_USAGE";
Usage: $0
    --products                               list of products
    --stats                                  subscription statistics
    --show   --email FILTER_FOR_EMAIL        list users

    --replace NEW_EMAIL --email OLD_EMAIL

    --list PRODUCT                           list all the users who subscribe to this project

    --addsub product --email email\@address  add the specific product to the specific user
    --unsub  product --email email\@address  remove the perl_maven_cookbook from the specific user

Products:
END_USAGE

	my $products = $db->get_products;
	foreach
		my $code ( sort { $products->{$a}{name} cmp $products->{$b}{name} }
		keys %$products )
	{
		say "   $code";
	}

	exit;
}

