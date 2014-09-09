use strict;
use warnings;
use DBI;

# if e-mail or part of e-mail is provided then the info about that user
# is printed

my ($email) = @ARGV;

my $dsn = 'dbi:SQLite:dbname=pm.db';
my $dbh = DBI->connect(
	$dsn, '', '',
	{
		RaiseError => 1,
		PrintError => 0,
		AutoCommit => 1,
	}
);

my $sql = 'SELECT * FROM user';
my @params;
if ($email) {
	$sql .= ' WHERE email like ?';
	push @params, '%' . $email . '%';
}

my $sth_subscriptions = $dbh->prepare(
	q{
SELECT product.code
FROM subscription, product
WHERE
  subscription.pid=product.id
  AND subscription.uid=?}
);

my $sth = $dbh->prepare($sql);
$sth->execute(@params);
while ( my $user = $sth->fetchrow_hashref ) {
	foreach my $k ( sort keys %$user ) {
		print "$k: ", ( $user->{$k} || '-' ), "\n";
	}
	print "\n";
	$sth_subscriptions->execute( $user->{id} );
	while ( my ($name) = $sth_subscriptions->fetchrow_array() ) {
		print "     $name\n";
	}
}
