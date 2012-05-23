#!/usr/bin/perl
use strict;
use warnings;

use DBI;
use Data::Dumper qw(Dumper);

my $dsn = "dbi:SQLite:dbname=pm.db";

my ($email) = @ARGV;

die "Usage $0 email" if not $email;
die 'No pm.db' if not -e 'pm.db';

my $dbh = DBI->connect($dsn, "", "", {
	RaiseError => 1,
	PrintError => 0,
	AutoCommit => 1,
});

$email = lc $email;

my $users = $dbh->selectall_arrayref('SELECT * FROM user WHERE email=?', undef, $email);
die "Could not find user with email '$email'\n" if not @$users;
die "There are more than one user with this email '$email'\n" . Dumper $users
	if @$users > 1;

print "Found user: " . Dumper $users->[0];
print "Do you want to remove it? (Y/N) ?";
my $answer = lc <STDIN>;
chomp $answer;
die "Aborting\n" if $answer ne 'y';

#$dbh->do('DELETE FROM
if ($dbh->do('DELETE FROM user WHERE email=?', undef, $email)) {
	print "Done\n";
} else {
	print "Failed???\n";
}



