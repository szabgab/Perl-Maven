use strict;
use warnings;
use DBI;

my $dsn = "dbi:SQLite:dbname=pm.db";
my $dbh = DBI->connect($dsn, "", "", {
     RaiseError => 1,
	 PrintError => 0,
	 AutoCommit => 1,
});
my $sth =$dbh->prepare('SELECT * FROM user');
$sth->execute;
while (my $hr = $sth->fetchrow_hashref) {
  foreach my $k (sort keys %$hr) {
     print "$k: ", ($hr->{$k} || '-') , "\n";
  }
  print "\n";
}