use strict;
use warnings;
use Test::Most tests => 5;
use Test::Deep qw(cmp_deeply re);

use File::Copy    qw(move);
use Capture::Tiny qw(capture);
use Cwd           qw(cwd);
use t::lib::Test;

t::lib::Test::setup();

use Perl::Maven::DB;
my $db        = Perl::Maven::DB->new('test_abc.db');
my $TIMESTAMP = re('^\d{10}$');

subtest users => sub {
	plan tests => 8;

	my $people = $db->get_people('');
	is_deeply $people, [], 'no people';

	my $id = $db->add_registration( { email => 'foo@bar.com' } );
	$people = $db->get_people('');
	is_deeply $people, [ { id => 1, email => 'foo@bar.com', verify_time => undef, subscriptions => [] } ],
		'first person';

	my $user = $db->get_user_by_id(1);
	cmp_deeply $user,
		{
		'admin'                  => undef,
		'email'                  => 'foo@bar.com',
		'id'                     => 1,
		'login_whitelist'        => undef,
		'name'                   => undef,
		'password'               => undef,
		'password_reset_code'    => undef,
		'password_reset_timeout' => undef,
		'register_time'          => $TIMESTAMP,
		'verify_code'            => undef,
		'verify_time'            => undef,
		subscriptions            => [],
		},
		'get_user_by_id';

	my $no_user = $db->get_user_by_id(2);
	is $no_user, undef, 'get_user_by_id no such user';

	#diag explain $no_user;

	$db->add_registration( { email => 'buzz@nasa.com' } );
	$people = $db->get_people('');

	#diag explain $people;
	is_deeply $people,
		[
		{ id => 1, email => 'foo@bar.com',   verify_time => undef, subscriptions => [] },
		{ id => 2, email => 'buzz@nasa.com', verify_time => undef, subscriptions => [] }
		],
		'two people';

	$people = $db->get_people('oo');
	is_deeply $people, [ { id => 1, email => 'foo@bar.com', verify_time => undef, subscriptions => [] } ], 'one person';

	my $p = $db->get_user_by_email('foo@bar');
	is $p, undef, 'no such email';
	$p = $db->get_user_by_email('foo@bar.com');

	#diag explain $p;
	cmp_deeply $p,
		{
		'email'                  => 'foo@bar.com',
		'id'                     => 1,
		'name'                   => undef,
		'password'               => undef,
		'password_reset_code'    => undef,
		'password_reset_timeout' => undef,
		'register_time'          => $TIMESTAMP,
		'verify_code'            => undef,
		'verify_time'            => undef,
		'admin'                  => undef,
		'login_whitelist'        => undef,
		subscriptions            => [],
		};
};

subtest replace_email => sub {
	plan tests => 3;

	my $before = $db->get_user_by_email('buzz@nasa.com');

	cmp_deeply $before,
		{
		'email'                  => 'buzz@nasa.com',
		'id'                     => 2,
		'name'                   => undef,
		'password'               => undef,
		'password_reset_code'    => undef,
		'password_reset_timeout' => undef,
		'register_time'          => re('\d+'),
		'verify_code'            => undef,
		'verify_time'            => undef,
		'admin'                  => undef,
		'login_whitelist'        => undef,
		subscriptions            => [],
		};

	$db->replace_email( 'buzz@nasa.com', 'buzz@buzzaldrin.com' );

	my $after_old = $db->get_user_by_email('buzz@nasa.com');
	is $after_old, undef;

	my $after = $db->get_user_by_email('buzz@buzzaldrin.com');

	cmp_deeply $after,
		{
		'email'                  => 'buzz@buzzaldrin.com',
		'id'                     => 2,
		'name'                   => undef,
		'password'               => undef,
		'password_reset_code'    => undef,
		'password_reset_timeout' => undef,
		'register_time'          => re('\d+'),
		'verify_code'            => undef,
		'verify_time'            => undef,
		'admin'                  => undef,
		'login_whitelist'        => undef,
		subscriptions            => [],
		};

};

subtest products => sub {
	plan tests => 2;

	my %products = (
		'beginner_perl_maven_ebook' => {
			'code'  => 'beginner_perl_maven_ebook',
			'id'    => 2,
			'name'  => 'Beginner Perl Maven e-book',
			'price' => '0.01'
		},
		'some_free_product' => {
			'code'  => 'some_free_product',
			'id'    => 1,
			'name'  => 'Perl Maven Cookbook',
			'price' => 0
		}
	);

	my $prod = $db->get_products;

	#diag explain $prod;
	is_deeply $prod, \%products, 'products';

	$db->add_product( { code => 'mars_landing_handbook', name => 'Mars Landing Handbook', price => 20.40 } );
	$products{mars_landing_handbook} = {
		code  => 'mars_landing_handbook',
		name  => 'Mars Landing Handbook',
		price => 20.40,
		id    => 3,
	};

	$prod = $db->get_products;
	is_deeply $prod, \%products, '3rd product added';
};

subtest subscriptions => sub {
	plan tests => 5;

	my $users = $db->get_people('foo@bar.com');
	is_deeply $users->[0]{subscriptions}, [];
	$db->subscribe_to(
		email => 'foo@bar.com',
		code  => 'beginner_perl_maven_ebook'
	);

	$users = $db->get_people('foo@bar.com');
	is_deeply $users->[0]{subscriptions}, ['beginner_perl_maven_ebook'], 'subscribed';

	$db->subscribe_to(
		email => 'foo@bar.com',
		code  => 'mars_landing_handbook'
	);
	$users = $db->get_people('foo@bar.com');
	is_deeply $users->[0]{subscriptions}, [ 'beginner_perl_maven_ebook', 'mars_landing_handbook' ], 'subscribed';

	$db->unsubscribe_from(
		email => 'foo@bar.com',
		code  => 'mars_landing_handbook'
	);
	$users = $db->get_people('foo@bar.com');
	is_deeply $users->[0]{subscriptions}, ['beginner_perl_maven_ebook'], 'subscribed';

	$db->unsubscribe_from(
		email => 'foo@bar.com',
		code  => 'beginner_perl_maven_ebook'
	);
	$users = $db->get_people('foo@bar.com');
	is_deeply $users->[0]{subscriptions}, [], 'empty again';
};

subtest whitelist => sub {
	plan tests => 3;

	my @whitelist = (
		{
			uid  => 1,
			ip   => '1.2.3.4',
			mask => '255.255.255.255',
			note => 'Some text',
		},
	);

	my $empty = $db->get_whitelist(1);
	is_deeply $empty, {};
	$db->add_to_whitelist( $whitelist[0] );
	my $list = $db->get_whitelist(1);
	$whitelist[0]{id} = 1;
	is_deeply $list, { 1 => $whitelist[0] };

	$db->delete_from_whitelist( 1, 1 );
	is_deeply $db->get_whitelist(1), {};
};

