package Perl::Maven::DB;
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use MongoDB;
use boolean;
use DateTime::Tiny;

our $VERSION = '0.11';

my $instance;

sub new {
	my ( $class, $dbname ) = @_;
	$dbname ||= 'PerlMaven';
	if ( $ENV{PERL_MAVEN_DB} ) {
		$dbname = $ENV{PERL_MAVEN_DB};
	}

	if ($instance) {
		die "Trying to call ->new($dbname) while it has already been called using ->new($instance->{dbname})"
			if $instance->{dbname} ne $dbname;
		return $instance;
	}

	#die 'Call ->instance instead' if $instance;

	my $client = MongoDB::MongoClient->new( host => 'localhost', port => 27017 );
	$client->dt_type('DateTime::Tiny');

	my $database = $client->get_database($dbname);
	$database->get_collection('user')->ensure_index( { email => 1 }, { unique => boolean::true } );
	$database->get_collection('paypal_transactions')->ensure_index( { paypal_id => 1 }, { unique => boolean::true } );

	$instance = bless { db => $database, dbname => $dbname }, $class;

	return $instance;
}

sub instance {
	die if not $instance;
	return $instance;
}

sub add_registration {
	my ( $self, $args ) = @_;

	return if $self->get_user_by_email( $args->{email} );

	$args->{register_time} = DateTime::Tiny->now;
	$args->{subscriptions} ||= [];
	return $self->{db}->get_collection('user')->insert($args);
}

sub delete_user {
	my ( $self, $email ) = @_;
	return $self->{db}->get_collection('user')->remove( { email => $email } );
}

sub get_people {
	my ( $self, $email ) = @_;

	return [ $self->{db}->get_collection('user')->find( { email => qr/$email/ } )->sort( { email => 1 } )->all ];
}

sub get_user_by_email {
	my ( $self, $email ) = @_;

	return $self->{db}->get_collection('user')->find_one( { email => $email } );
}

sub get_user_by_id {
	my ( $self, $id ) = @_;

	return $self->{db}->get_collection('user')->find_one( { _id => $id } );
}

sub update_user {
	my ( $self, $id, %fields ) = @_;
	$self->{db}->get_collection('user')->update( { _id => $id }, { '$set' => \%fields } );
	return;
}

sub verify_registration {
	my ( $self, $id ) = @_;

	my $user = $self->get_user_by_id($id);
	return 0 if not $user;
	return 0 if $user->{verify_time};
	return $self->{db}->get_collection('user')
		->update( { _id => $id }, { '$set' => { verify_time => DateTime::Tiny->now } } );
}

sub set_password {
	my ( $self, $id, $password ) = @_;
	$self->update_user( $id, password => $password );
}

sub replace_email {
	my ( $self, $old, $new ) = @_;
	return $self->{db}->get_collection('user')->update( { email => $old }, { '$set' => { email => $new } } );
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

sub get_subscribers {
	my ( $self, $code ) = @_;

	return [ $self->{db}->get_collection('user')->find( { subscriptions => { '$elemMatch' => { '$eq' => $code } } } )
			->sort( { email => 1 } )->all ];
}

sub is_subscribed {
	my ( $self, $id, $code ) = @_;

	my $user = $self->get_user_by_id($id);
	return scalar grep { $_ eq $code } @{ $user->{subscriptions} };
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
	my ( $self, %data ) = @_;
	$data{ts} = DateTime::Tiny->now;
	return $self->{db}->get_collection('paypal_transactions')->insert( \%data );
}

sub get_transaction {
	my ( $self, $id ) = @_;
	return $self->{db}->get_collection('paypal_transactions')->find_one( { paypal_id => $id } );
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

	my $all_subs = 0;
	foreach my $code ( keys %$products ) {
		my $count = $self->{db}->get_collection('user')
			->find( { 'subscriptions' => { '$elemMatch' => { '$eq' => $code } } } )->count;
		$products->{$code}{cnt} = $count;
		$all_subs += $count if $code ne 'perl_maven_cookbook';
	}

	my %stats = ( products => $products );
	$stats{product_list} = [ sort { $a->{code} cmp $b->{code} } values %$products ];

	$stats{all_subs} = $all_subs;

	my $all_users_with_subscription
		= $self->{db}->get_collection('user')->find( { 'subscriptions' => { '$not' => { '$size' => 0 } } } )->count;
	my $free_only_subs = $self->{db}->get_collection('user')->find(
		{
			'$and' => [
				{ 'subscriptions' => { '$size'      => 1 } },
				{ 'subscriptions' => { '$elemMatch' => { '$eq' => 'perl_maven_cookbook' } } }
			]
		}
	)->count;

	$stats{distinct_subs} = $all_users_with_subscription - $free_only_subs;
	$stats{all_users}
		= $self->{db}->get_collection('user')->find()->count;
	$stats{verified}
		= $self->{db}->get_collection('user')->find( { verify_time => { '$exists' => boolean::true } } )->count;
	$stats{not_verified}
		= $self->{db}->get_collection('user')->find( { verify_time => { '$exists' => boolean::false } } )->count;
	$stats{no_password} = $self->{db}->get_collection('user')->find(
		{
			'$and' =>
				[ { verify_time => { '$exists' => boolean::true } }, { password => { '$exists' => boolean::false } } ]
		}
	)->count;

	$stats{has_password}
		= $self->{db}->get_collection('user')->find( { password => { '$exists' => boolean::true } } )->count;
	$stats{new_password} = $self->{db}->get_collection('user')->find( { password => qr/{CRYPT}/ } )->count;

	$stats{old_password}
		= $self->{db}->get_collection('user')
		->find(
		{ '$and' => [ { password => { '$exists' => boolean::true } }, { password => { '$not' => qr/{CRYPT}/ } } ] } )
		->count;

	return \%stats;
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

sub add_log {
	my ( $self, $data ) = @_;

	$self->{db}->get_collection('logging')->insert($data);
	return;
}

sub save_job_post {
	my ( $self, $data ) = @_;

	$self->{db}->get_collection('jobs')->insert($data);
	return;
}

sub get_jobs {
	my ( $self, $uid ) = @_;

	return [ $self->{db}->get_collection('jobs')->find( { uid => $uid } )->all ];
}

1;

