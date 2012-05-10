use strict;
use warnings;

use YAML qw(DumpFile LoadFile);
use DBIx::RunSQL;

die 'has no data.yml' if not -e 'data.yml';
die 'has pm.db' if -e 'pm.db';


my $dsn = "dbi:SQLite:dbname=pm.db";
DBIx::RunSQL->create(
    dsn     => $dsn,
    sql     => 'sql/schema.sql',
	verbose => 0,
);

my $dbh = DBI->connect($dsn, "", "", {
     RaiseError => 1,
	 PrintError => 0,
	 AutoCommit => 1,
});

my $data = LoadFile('data.yml');
foreach my $email (sort { $data->{$a}{register} cmp $data->{$b}{register} }  keys %$data) {
	print "$email  $data->{$email}{register} $data->{$email}{code} $data->{$email}{verified}\n";
    $dbh->do('INSERT INTO user (email, register_time, verify_code, verify_time)
	    VALUES (?, ?, ?, ?)',
        undef,
	    $email, $data->{$email}{register}, $data->{$email}{code}, $data->{$email}{verified});
    my $id = $dbh->last_insert_id('', '', '', '');
    print "$id\n";
}
