use strict;
use warnings;

use DBI;

die 'has pm.db' if -e 'pm.db';

my $dsn = "dbi:SQLite:dbname=pm.db";
my $dbh = DBI->connect($dsn, "", "", {
	RaiseError => 1,
	PrintError => 0,
	AutoCommit => 1,
});

$dbh->do('INSERT INTO product (dir, name) VALUES (?)',
	undef, 'perl_maven_cookbook', 'Perl Maven Cookbook');

my $users = $dbh->selectall_arrayref('SELECT id FROM user WHERE id < 5');
print Dumper $users;

$dbh->do('INSERT INTO  subscription (uid, pid) VALUES (?, ?)',
	undef, $uid, 1);


