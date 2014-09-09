use strict;
use warnings;
use 5.010;

use DBIx::RunSQL;
use DBI;

my $dbfile = shift // 'pm.db';

die 'has pm.db' if -e $dbfile;

my $dsn = "dbi:SQLite:dbname=$dbfile";
DBIx::RunSQL->create(
	verbose => 0,
	dsn     => $dsn,
	sql     => 'sql/schema.sql',
);

my $dbh = DBI->connect(
	$dsn, '', '',
	{
		RaiseError => 1,
		PrintError => 0,
		AutoCommit => 1,
	}
);

