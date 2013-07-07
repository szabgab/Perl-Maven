use strict;
use warnings;

use DBIx::RunSQL;
use DBI;

die 'has pm.db' if -e 'pm.db';


my $dsn = "dbi:SQLite:dbname=pm.db";
DBIx::RunSQL->create(
	verbose => 0,
	dsn     => $dsn,
	sql     => 'sql/schema.sql',
);

my $dbh = DBI->connect($dsn, "", "", {
	RaiseError => 1,
	PrintError => 0,
	AutoCommit => 1,
});

# DBIx::RunSQL cannot handle this:
$dbh->do(q{
CREATE TRIGGER user_cleanup
  BEFORE DELETE ON user FOR EACH ROW
  BEGIN
   DELETE FROM subscription WHERE uid=OLD.id;
  END;
});

$dbh->do('INSERT INTO product (code, name, price) VALUES (?, ?, ?)',
	undef, 'perl_maven_cookbook', 'Perl Maven Cookbook', 39);

