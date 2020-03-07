#!/usr/bin/perl
use strict;
use warnings;
use v5.12;

use Data::Dumper qw(Dumper);
use Getopt::Long qw(GetOptions);

use lib 'lib';

use Perl::Maven::DB;
my $dbfile = $ENV{PERL_MAVEN_DB} || 'pm.db';    # TODO integrate with the mymaven.yml
if ( not $dbfile or $dbfile !~ /\.db$/ or not -e $dbfile ) {
	die "First parameter must be name of the db file pm.db or cm.db\n";
}

my $db = Perl::Maven::DB->new($dbfile);

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
	'uid=i',

	'deluser=s',

	'unsub=s',
	'perl',

	'dump:s',
) or usage();

if ( $opt{email} ) {
	$opt{email} = lc $opt{email};
}

if ( $opt{products} ) {
	my $products = $db->get_products;

	if ( $opt{perl} ) {

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
		printf $format, $stats->{products}{$code}{code}, $stats->{products}{$code}{cnt},;
	}
	say '-' x 45;
	printf $format, q{Total 'purchases':},     $stats->{all_subs};
	printf $format, q{Distinct # of clients:}, $stats->{distinct_subs};
	print "\n";
	printf $format, 'All the users',            $stats->{all_users};
	printf $format, 'Verified', ( $stats->{all_users} - $stats->{not_verified} );
	printf $format, 'NOT Verified',             $stats->{not_verified};
	printf $format, 'Verified but NO password', $stats->{no_password};
	printf $format, 'Has password',             $stats->{has_password};
	printf $format, '    New pw',               $stats->{new_password};
	printf $format, '    Old pw',               $stats->{old_password};

}
elsif ( $opt{show} and $opt{email} ) {
	show_people( $opt{email} );
}
elsif ( $opt{show} and $opt{uid} ) {
	my $user = $db->get_user_by_id( $opt{uid} );
	if ($user) {
		show_people( $user->{email} );
	}
	else {
		say "Could not find user with uid '$opt{uid}'";
	}
}
elsif ( $opt{replace} and $opt{email} ) {
	show_people( $opt{email} );
	$db->replace_email( $opt{email}, $opt{replace} );
	show_people( $opt{replace} );
}
elsif ( $opt{addsub} and $opt{email} ) {
	my $res = $db->subscribe_to( email => $opt{email}, code => $opt{addsub} );
	if ($res) {
		usage("Could not find product '$opt{addsub}'")
			if $res eq 'no_such_code';
		usage("Could not find user '$opt{email}'") if $res eq 'no_such_email';
	}

	#print "PID: $pid  UID: $uid\n";
	show_people( $opt{email} );
}
elsif ( $opt{unsub} and $opt{email} ) {
	my $res
		= $db->unsubscribe_from( email => $opt{email}, code => $opt{unsub} );

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
		printf "%4s %s\n", $e->[1], $e->[0];
	}
}
elsif ( $opt{deluser} ) {
	my $email = lc $opt{deluser};
	my $user  = $db->get_user_by_email($email);

	die "Could not find user with email '$email'\n" if not $user;

	#die "There are more than one user with this email '$email'\n" . Dumper $users
	#	if @$users > 1; # nah, this really should not happen, should this

	#print 'Found user: ' . Dumper $user;
	print 'Do you want to remove it? (Y/N) ?';
	my $answer = lc <STDIN>;
	chomp $answer;
	die "Aborting\n" if $answer ne 'y';

	my $res = $db->delete_user($email);
	if ($res) {
		say 'Done';
	}
	else {
		say 'Failed???';
	}

}
elsif ( defined $opt{dump} ) {
	$db->dump( $opt{dump} );
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
		$p->{verify_time} //= '-';
		printf "%4s %30s  verify_time='%s'\n", @{$p}{qw(id email verify_time)};
		foreach my $s ( @{ $p->{subscriptions} } ) {
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
    --show   --uid 123                       show user

    --replace NEW_EMAIL --email OLD_EMAIL

    --list PRODUCT                           list all the users who subscribe to this project

    --addsub product --email email\@address  add the specific product to the specific user
    --unsub  product --email email\@address  remove the perl_maven_cookbook from the specific user


    --deluser EMAIL                          delete this user
 
    --dump  [EMAIL]                          dump dataof all the user or a specific user

Products:
END_USAGE

	my $products = $db->get_products;
	foreach my $code (
		sort { $products->{$a}{name} cmp $products->{$b}{name} }
		keys %$products
		)
	{
		say "   $code";
	}

	exit;
}

