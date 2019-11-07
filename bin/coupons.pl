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
	die "db file pm.db is missing\n";
}

my $db = Perl::Maven::DB->new($dbfile);

##########################################

my $code;
my $days;

GetOptions(
    "code=s" => \$code,
    "days=i" => \$days,
) or die;
die usage() if not $code or not $days;

my $pid        = 6;                             # perl_maven_pro
my $price      = 0;
my $start_time = time;
my $end_time   = time + $days * 60 * 60;
my $max_users  = 30;

my $sql = "INSERT INTO coupons (code, pid, price, start_time, end_time, max_uses) VALUES (?, ?, ?, ?, ?, ?)";
$db->{dbh}->do( $sql, undef, $code, $pid, $price, $start_time, $end_time, $max_users );


sub usage {
    die "Usage: $0 CODE DAYS\n";
}
