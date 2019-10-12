use strict;
use warnings;
use 5.010;
use Data::Dumper qw(Dumper);

use DBI;

# merge the databased of two web sites.

my ( $from_file, $to_file ) = @ARGV;
die if not $to_file;

my $from_dbh = DBI->connect(
	"dbi:SQLite:dbname=$from_file",
	'', '',
	{
		RaiseError => 1,
		PrintError => 0,
		AutoCommit => 1,
	}
);

my $to_dbh = DBI->connect(
	"dbi:SQLite:dbname=$to_file",
	'', '',
	{
		RaiseError => 1,
		PrintError => 0,
		AutoCommit => 1,
	}
);

my $get_products_sth   = $from_dbh->prepare('SELECT * FROM product');
my $check_products_sth = $to_dbh->prepare('SELECT * FROM product WHERE code=?');
$get_products_sth->execute;
my %products;
while ( my $row = $get_products_sth->fetchrow_hashref ) {

	#print Dumper $row;
	$check_products_sth->execute( $row->{code} );
	my $old = $check_products_sth->fetchrow_hashref;
	if ($old) {
		die "The same product code '$old->{code}' in both databases. Aborting";
	}
	$products{ $row->{code} }{from} = $row;
}

#print Dumper \%products;

for my $code ( keys %products ) {

	#say $code;
	$to_dbh->do(
		"INSERT INTO product (code, name, price) VALUES (?, ?, ?)",
		undef, $code,
		$products{$code}{from}{name},
		$products{$code}{from}{price}
	);
	my $new_id = $to_dbh->sqlite_last_insert_rowid();
	$products{$code}{new} = $new_id;

	#say $new_id;
}

my $get_user_sth   = $from_dbh->prepare('SELECT * FROM user');
my $check_user_sth = $to_dbh->prepare('SELECT * FROM user WHERE email=?');

my $get_subscriptions_sth = $from_dbh->prepare(
	"SELECT code FROM subscription, product WHERE subscription.uid=? and subscription.pid=product.id");

$get_user_sth->execute;
while ( my $row = $get_user_sth->fetchrow_hashref ) {

	# Add missing users from to
	$check_user_sth->execute( $row->{email} );
	my $in_to   = $check_user_sth->fetchrow_hashref;
	my $in_from = $row->{id};
	if ( not $in_to ) {
		my %row = %$row;
		my @values = @row{ 'email', 'password', 'register_time', 'verify_code', 'verify_time', 'name', 'admin',
			'login_whitelist' };

		#print Dumper \@values;
		$to_dbh->do(
			"INSERT INTO user (email, password, register_time, verify_code, verify_time, name, admin, login_whitelist) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
			undef, @values
		);
		$check_user_sth->execute( $row->{email} );
		$in_to = $check_user_sth->fetchrow_hashref;

		# copy whitelist
	}

	# copy subscriptions
	#say "uid: $in_from => $in_to->{id}";
	$get_subscriptions_sth->execute($in_from);
	while ( my $subs = $get_subscriptions_sth->fetchrow_hashref ) {

		#say "code: $subs->{code}";
		#say "new product_id: $products{$subs->{code}}{new}";
		$to_dbh->do( 'INSERT INTO subscription (uid, pid) VALUES (?, ?)',
			undef, $in_to->{id}, $products{ $subs->{code} }{new} );
	}
}

