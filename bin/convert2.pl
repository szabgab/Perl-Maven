use strict;
use warnings;

use DBI;
use Data::Dumper qw(Dumper);
use DBIx::RunSQL;

die 'has no pm.db' if ! -e 'pm.db';

my $dsn = "dbi:SQLite:dbname=pm.db";
DBIx::RunSQL->create(
	verbose => 0,
	dsn     => $dsn,
	sql     => 'sql/schema2.sql',
);


my $dbh = DBI->connect($dsn, "", "", {
	RaiseError => 1,
	PrintError => 0,
	AutoCommit => 1,
});

$dbh->do('INSERT INTO product (dir, name) VALUES (?, ?)',
	undef, 'perl_maven_cookbook', 'Perl Maven Cookbook');

my $users = $dbh->selectall_arrayref('SELECT id FROM user');
#die Dumper $users;

foreach my $ar (@$users) {
	$dbh->do('INSERT INTO  subscription (uid, pid) VALUES (?, ?)',
		undef, $ar->[0], 1);
}

