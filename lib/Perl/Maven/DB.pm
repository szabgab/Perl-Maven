package Perl::Maven::DB;
use strict;
use warnings;

use DBI;

our $VERSION = '0.11';

my $instance;

sub new {
	my ( $class, $dbfile ) = @_;

	return $instance if $instance;

	my $dsn = "dbi:SQLite:dbname=$dbfile";
	my $dbh = DBI->connect(
		$dsn, '', '',
		{
			RaiseError => 1,
			PrintError => 0,
			AutoCommit => 1,
		}
	);

	$instance = bless { dbh => $dbh, }, $class;

	return $instance;
}

sub add_registration {
	my ( $self, $email, $code ) = @_;

	$self->{dbh}->do(
		'INSERT INTO user (email, verify_code, register_time)
		VALUES (?, ?, ?)',
		undef,
		$email, $code, time
	);
	my $id = $self->{dbh}->last_insert_id( '', '', '', '' );

	return $id;
}

sub update_user {
	my ( $self, $id, %fields ) = @_;

	$self->{dbh}->do( 'UPDATE user SET name=? WHERE id=?',
		undef, $fields{name}, $id );
}

sub get_user_by_email {
	my ( $self, $email ) = @_;

	my $hr
		= $self->{dbh}->selectrow_hashref( 'SELECT * FROM user WHERE email=?',
		undef, $email );

	return $hr;
}

sub get_people {
	my ( $self, $email ) = @_;

	return $self->{dbh}->selectall_arrayref(
		q{
	   SELECT id, email, verify_time
	   FROM user WHERE email LIKE ?
	}, undef, '%' . $email . '%'
	);
}

sub get_user_by_id {
	my ( $self, $id ) = @_;

	my $hr = $self->{dbh}
		->selectrow_hashref( 'SELECT * FROM user WHERE id=?', undef, $id );

	return $hr;
}

sub verify_registration {
	my ( $self, $id, $code ) = @_;

	$self->{dbh}
		->do( 'UPDATE user SET verify_time=? WHERE id=?', undef, time, $id );
}

sub set_password_code {
	my ( $self, $email, $code ) = @_;
	$self->{dbh}->do(
		'UPDATE user
		SET password_reset_code=?, password_reset_timeout=?
		WHERE email=?',
		undef, $code, time + 60 * 60, $email
	);
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

	return @products;
}

sub is_subscribed {
	my ( $self, $email, $code ) = @_;

	my ($subscribed) = $self->{dbh}->selectrow_array(
		q{
		SELECT COUNT(*)
		FROM subscription, product, user
		WHERE user.id=subscription.uid
			AND user.email=?
			AND product.code=?
			AND product.id=subscription.pid
	}, undef, $email, $code
	);

	return $subscribed;
}

sub subscribe_to {
	my ( $self, $email, $code ) = @_;

	my ($pid)
		= $self->{dbh}
		->selectrow_array( q{SELECT product.id FROM product WHERE code=?},
		undef, $code );
	return 'no_such_code' if not $pid;

	my ($uid)
		= $self->{dbh}
		->selectrow_array( q{SELECT user.id FROM user WHERE email=?},
		undef, $email );
	return 'no_such_email' if not $uid;

	$self->{dbh}->do( 'INSERT INTO subscription (uid, pid) VALUES (?, ?)',
		undef, $uid, $pid );

	return;
}

sub unsubscribe_from {
	my ( $self, $email, $code ) = @_;

	my ($pid)
		= $self->{dbh}
		->selectrow_array( q{SELECT product.id FROM product WHERE code=?},
		undef, $code );
	return 'no_such_code' if not $pid;

	my ($uid)
		= $self->{dbh}
		->selectrow_array( q{SELECT user.id FROM user WHERE email=?},
		undef, $email );
	return 'no_such_email' if not $uid;

	$self->{dbh}->do( 'DELETE FROM subscription WHERE uid=? AND pid=?',
		undef, $uid, $pid );

	return;
}

sub save_transaction {
	my ( $self, $id, $data ) = @_;
	$self->{dbh}->do(
		q{INSERT INTO transactions (id, ts, sys, data) VALUES(?, ?, ?, ?)},
		{}, $id, time, 'paypal', $data );
	return;
}

sub get_transaction {
	my ( $self, $id ) = @_;
	my ($data)
		= $self->{dbh}
		->selectrow_array( q{SELECT data FROM transactions WHERE id=?},
		undef, $id );
	return $data;
}

sub get_products {
	my ($self) = @_;
	return $self->{dbh}
		->selectall_hashref( q{SELECT id, code, name, price FROM product},
		'code' );
}

sub add_product {
	my ( $self, $code, $name, $price ) = @_;

	die "Invlaid code '$code'" if $code !~ /^[a-z0-9_]+$/;
	$self->{dbh}
		->do( 'INSERT INTO product (code, name, price) VALUES (?, ?, ?)',
		undef, $code, $name, $price );
}

sub stats {
	my ($self) = @_;

	my $products = $self->get_products;
	my $subs     = $self->{dbh}->selectall_hashref(
		q{SELECT pid, COUNT(*) cnt FROM subscription GROUP BY pid}, 'pid' );
	foreach my $code ( keys %$products ) {
		my $pid = $products->{$code}{id};
		$products->{$code}{cnt} = ( $subs->{$pid}{cnt} || 0 );
	}

	my %stats = ( products => $products );
	$stats{all_subs} = $self->{dbh}->selectrow_array(
		q{SELECT COUNT(uid) FROM subscription WHERE pid != 1});
	$stats{distinct_subs} = $self->{dbh}->selectrow_array(
		q{SELECT COUNT(DISTINCT(uid)) FROM subscription WHERE pid != 1});

	$stats{all_users}
		= $self->{dbh}->selectrow_array(q{SELECT COUNT(*) FROM user});
	$stats{not_verified} = $self->{dbh}->selectrow_array(
		q{SELECT COUNT(*) FROM user WHERE verify_time is NULL});
	$stats{no_password}
		= $self->{dbh}->selectrow_array(
		q{SELECT COUNT(*) FROM user WHERE verify_time is NOT NULL AND password is NULL}
		);

	return \%stats;
}

1;

# vim:noexpandtab

