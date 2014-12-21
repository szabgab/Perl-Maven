package Perl::Maven::DB;
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use DBI;
use MongoDB;
use boolean;
use DateTime::Tiny;

our $VERSION = '0.11';

my $instance;

sub new {
	my ( $class, $dbfile ) = @_;

	if ( $ENV{PERL_MAVEN_DB} ) {
		$dbfile = $ENV{PERL_MAVEN_DB};
	}

	return $instance if $instance;

	my $dbname = $ENV{PERL_MAVEN_MONGO_DB} || 'PerlMaven';

	my $client = MongoDB::MongoClient->new( host => 'localhost', port => 27017 );
	my $database = $client->get_database($dbname);

	$instance = bless { db => $database }, $class;

	return $instance;
}

sub instance {
	return $instance;
}

sub add_registration {
	my ( $self, $args ) = @_;

	$args->{register_time} = DateTime::Tiny->now;
	$args->{subscriptions} ||= [];
	$self->{db}->get_collection('user')->insert($args);
}

sub update_user {
	my ( $self, $id, %fields ) = @_;

	$self->{dbh}->do( 'UPDATE user SET name=? WHERE id=?', undef, $fields{name}, $id );
}

sub set_whitelist {
	my ( $self, $id, $value ) = @_;

	$self->{db}->get_collection('user')
		->update( { _id => $id }, { '$set' => { whitelist_on => ( $value ? boolean::true : boolean::false ) } } );
	return;
}

# ip, mask, note
sub add_to_whitelist {
	my ( $self, $uid, $args ) = @_;

	my $user = $self->get_user_by_id($uid);
	return if not $user;
	if ( not $user->{whitelist} ) {
		$self->{db}->get_collection('user')->update( { _id => $uid }, { '$set' => { whitelist => [] } } );
	}

	$self->{db}->get_collection('user')->update( { _id => $uid }, { '$push' => { whitelist => $args } } );
}

sub delete_from_whitelist {
	my ( $self, $uid, $args ) = @_;
	$self->{db}->get_collection('user')->update( { _id => $uid }, { '$pull', { whitelist => $args } } );
}

sub get_whitelist {
	my ( $self, $uid ) = @_;

	my $user = $self->get_user_by_id($uid);
	return $user->{whitelist} || [];
}

sub get_user_by_email {
	my ( $self, $email ) = @_;

	return $self->{db}->get_collection('user')->find_one( { email => $email } );
}

sub get_people {
	my ( $self, $email ) = @_;

	return [ $self->{db}->get_collection('user')->find( { email => qr/$email/ } )->all ];
}

sub get_user_by_id {
	my ( $self, $id ) = @_;

	return $self->{db}->get_collection('user')->find_one( { _id => $id } );
}

sub verify_registration {
	my ( $self, $id, $code ) = @_;

	$self->{dbh}->do( 'UPDATE user SET verify_time=? WHERE id=?', undef, time, $id );
}

sub set_password {
	my ( $self, $id, $password ) = @_;

	$self->{dbh}->do(
		'UPDATE user
		SET password=?, password_reset_code="" WHERE id=?',
		undef, $password, $id
	);
}

sub get_subscriptions {
	my ( $self, $email ) = @_;

	my $sth = $self->{dbh}->prepare(
		q{
		SELECT product.code
		FROM product, user, subscription
		WHERE user.id=subscription.uid
			AND user.email=?
			AND product.id=subscription.pid
	}
	);

	$sth->execute($email);
	my @products;
	while ( my ($p) = $sth->fetchrow_array ) {
		push @products, $p;
	}

	return \@products;
}

sub get_subscribers {
	my ( $self, $code ) = @_;

	return $self->{dbh}->selectall_arrayref(
		q{
	   SELECT email, user.id
	   FROM user, subscription, product
	   WHERE user.id=subscription.uid
	     AND user.verify_time is not null
	     AND product.id=subscription.pid
	     AND product.code=?
	}, undef, $code
	);
}

sub is_subscribed {
	my ( $self, $id, $code ) = @_;

	my ($subscribed) = $self->{dbh}->selectrow_array(
		q{
		SELECT COUNT(*)
		FROM subscription, product, user
		WHERE user.id=subscription.uid
			AND user.id=?
			AND product.code=?
			AND product.id=subscription.pid
	}, undef, $id, $code
	);

	return $subscribed;
}

sub subscribe_to {
	my ( $self, %args ) = @_;

	my $prod = $self->get_product_by_code( $args{code} );
	return 'no_such_code' if not $prod;

	my $uid = $args{uid};
	if ( not $uid ) {
		my $user = $self->get_user_by_email( $args{email} );
		$uid = $user->{_id};
	}
	return 'no_such_email' if not $uid;

	$self->{db}->get_collection('user')->update( { _id => $uid }, { '$push' => { subscriptions => $args{code} } } );

	return;
}

sub unsubscribe_from {
	my ( $self, %args ) = @_;

	my $prod = $self->get_product_by_code( $args{code} );
	return 'no_such_code' if not $prod;

	my $uid = $args{uid};
	if ( not $uid ) {
		my $user = $self->get_user_by_email( $args{email} );
		$uid = $user->{_id};
	}
	return 'no_such_email' if not $uid;

	$self->{db}->get_collection('user')->update( { _id => $uid }, { '$pull' => { subscriptions => $args{code} } } );

	return;
}

sub save_transaction {
	my ( $self, $id, $data ) = @_;
	$self->{dbh}
		->do( q{INSERT INTO transactions (id, ts, sys, data) VALUES(?, ?, ?, ?)}, {}, $id, time, 'paypal', $data );
	return;
}

sub get_transaction {
	my ( $self, $id ) = @_;
	my ($data)
		= $self->{dbh}->selectrow_array( q{SELECT data FROM transactions WHERE id=?}, undef, $id );
	return $data;
}

sub get_products {
	my ($self) = @_;

	#return [ $self->{db}->get_collection('products')->find()->all ];
	my %products = map { $_->{code} => $_ } $self->{db}->get_collection('products')->find()->all;

	#return $self->{dbh}->selectall_hashref( q{SELECT id, code, name, price FROM product}, 'code' );
	return \%products;
}

sub get_product_by_code {
	my ( $self, $code ) = @_;
	return $self->{db}->get_collection('products')->find_one( { code => $code } );
}

sub add_product {
	my ( $self, $args ) = @_;

	die "Invlaid code '$args->{code}'" if $args->{code} !~ /^[a-z0-9_]+$/;
	$self->{db}->get_collection('products')->insert($args);
}

sub stats {
	my ($self) = @_;

	my $products = $self->get_products;
	my $subs = $self->{dbh}->selectall_hashref( q{SELECT pid, COUNT(*) cnt FROM subscription GROUP BY pid}, 'pid' );
	foreach my $code ( keys %$products ) {
		my $pid = $products->{$code}{id};
		$products->{$code}{cnt} = ( $subs->{$pid}{cnt} || 0 );
	}

	my %stats = ( products => $products );
	$stats{all_subs}
		= $self->{dbh}->selectrow_array(q{SELECT COUNT(uid) FROM subscription WHERE pid != 1});
	$stats{distinct_subs}
		= $self->{dbh}->selectrow_array(q{SELECT COUNT(DISTINCT(uid)) FROM subscription WHERE pid != 1});

	$stats{all_users}
		= $self->{dbh}->selectrow_array(q{SELECT COUNT(*) FROM user});
	$stats{not_verified}
		= $self->{dbh}->selectrow_array(q{SELECT COUNT(*) FROM user WHERE verify_time is NULL});
	$stats{no_password}
		= $self->{dbh}
		->selectrow_array(q{SELECT COUNT(*) FROM user WHERE verify_time is NOT NULL AND password is NULL});
	$stats{has_password} = $self->{dbh}->selectrow_array(q{SELECT COUNT(*) FROM user WHERE password IS NOT NULL});
	$stats{new_password} = $self->{dbh}->selectrow_array(q{SELECT COUNT(*) FROM user WHERE password LIKE '{CRYPT}%'});
	$stats{old_password}
		= $self->{dbh}->selectrow_array(q{SELECT COUNT(*) FROM user WHERE password NOT LIKE '{CRYPT}%'});

	return \%stats;
}

sub replace_email {
	my ( $self, $old, $new ) = @_;
	return $self->{db}->get_collection('user')->update( { email => $old }, { '$set' => { email => $new } } );
}

sub delete_user {
	my ( $self, $email ) = @_;
	return $self->{dbh}->do( 'DELETE FROM user WHERE email=?', undef, $email );
}

sub dump {
	my ( $self, $email ) = @_;

	my $sql = 'SELECT * FROM user';
	my @params;
	if ($email) {
		$sql .= ' WHERE email like ?';
		push @params, '%' . $email . '%';
	}

	my $sth_subscriptions = $self->{dbh}->prepare(
		q{
	SELECT product.code
	FROM subscription, product
	WHERE
	  subscription.pid=product.id
	  AND subscription.uid=?}
	);

	my $sth = $self->{dbh}->prepare($sql);
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
}

sub setup {
	my ( $class, $dbfile ) = @_;

	die 'has pm.db' if -e $dbfile;
	require DBIx::RunSQL;
	my $dsn = "dbi:SQLite:dbname=$dbfile";
	DBIx::RunSQL->create(
		verbose => 0,
		dsn     => $dsn,
		sql     => 'sql/schema.sql',
	);
}

# TODO shall we use the _id generated by MongodB as the code?
# code timestamp action uid details
sub save_verification {
	my ( $self, %params ) = @_;
	$params{timestamp} = DateTime::Tiny->now;
	return $self->{db}->get_collection('verification')->insert( \%params );
}

sub get_verification {
	my ( $self, $code ) = @_;
	return $self->{db}->get_collection('verification')->find_one( { code => $code } );
}

sub delete_verification_code {
	my ( $self, $code ) = @_;
	return $self->{db}->get_collection('verification')->remove( { code => $code } );
}

1;

