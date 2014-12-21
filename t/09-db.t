use strict;
use warnings;
use Test::Most tests => 7;
use Test::Deep qw(cmp_deeply re ignore isa);

use File::Copy qw(move);
use Capture::Tiny qw(capture);
use Cwd qw(cwd);
use t::lib::Test;

t::lib::Test::setup();

use Perl::Maven::DB;
use Perl::Maven::WebTools qw(_generate_code);

my $db        = Perl::Maven::DB->instance;
my $TIMESTAMP = isa('DateTime');
my $ID        = re('^\w+$');

subtest users => sub {
	plan tests => 8;

	my $people = $db->get_people('');
	is_deeply $people, [], 'no people';

	my $id = $db->add_registration( { email => 'foo@bar.com' } );
	$people = $db->get_people('');
	cmp_deeply $people, [ { _id => $ID, email => 'foo@bar.com', subscriptions => [], register_time => $TIMESTAMP } ],
		'first person';

	my $user = $db->get_user_by_id( $people->[0]{_id} );
	cmp_deeply $user, {

		#'admin'                  => undef,
		'email' => 'foo@bar.com',
		'_id'   => $ID,

		#'login_whitelist'        => undef,
		#'name'                   => undef,
		#'password'               => undef,
		#'password_reset_code'    => undef,
		#'password_reset_timeout' => undef,
		'register_time' => $TIMESTAMP,

		#'verify_code'            => undef,
		#'verify_time'            => undef,
		subscriptions => [],
		},
		'get_user_by_id';

	my $no_user = $db->get_user_by_id(2);
	is $no_user, undef, 'get_user_by_id no such user';

	#diag explain $no_user;

	$db->add_registration( { email => 'buzz@nasa.com' } );
	$people = $db->get_people('');

	#diag explain $people;
	cmp_deeply $people,
		[
		{ _id => $ID, email => 'foo@bar.com',   register_time => $TIMESTAMP, subscriptions => [] },
		{ _id => $ID, email => 'buzz@nasa.com', register_time => $TIMESTAMP, subscriptions => [] }
		],
		'two people';

	$people = $db->get_people('oo');
	cmp_deeply $people, [ { _id => $ID, email => 'foo@bar.com', register_time => $TIMESTAMP, subscriptions => [] } ],
		'one person';

	my $p = $db->get_user_by_email('foo@bar');
	is $p, undef, 'no such email';
	$p = $db->get_user_by_email('foo@bar.com');

	#diag explain $p;
	cmp_deeply $p, {
		'email' => 'foo@bar.com',
		'_id'   => $ID,

		#'name'                   => undef,
		#'password'               => undef,
		#'password_reset_code'    => undef,
		#'password_reset_timeout' => undef,
		'register_time' => $TIMESTAMP,

		#'verify_code'            => undef,
		#'verify_time'            => undef,
		#'admin'                  => undef,
		#'login_whitelist'        => undef,
		subscriptions => [],
	};
};

subtest replace_email => sub {
	plan tests => 3;

	my $before = $db->get_user_by_email('buzz@nasa.com');

	cmp_deeply $before, {
		'email' => 'buzz@nasa.com',
		'_id'   => $ID,

		#'name'                   => undef,
		#'password'               => undef,
		#'password_reset_code'    => undef,
		#'password_reset_timeout' => undef,
		'register_time' => $TIMESTAMP,

		#'verify_code'            => undef,
		#'verify_time'            => undef,
		#'admin'                  => undef,
		#'login_whitelist'        => undef,
		subscriptions => [],
	};

	$db->replace_email( 'buzz@nasa.com', 'buzz@buzzaldrin.com' );

	my $after_old = $db->get_user_by_email('buzz@nasa.com');
	is $after_old, undef;

	my $after = $db->get_user_by_email('buzz@buzzaldrin.com');

	cmp_deeply $after, {
		'email' => 'buzz@buzzaldrin.com',
		'_id'   => $ID,

		#'name'                   => undef,
		#'password'               => undef,
		#'password_reset_code'    => undef,
		#'password_reset_timeout' => undef,
		'register_time' => $TIMESTAMP,

		#'verify_code'            => undef,
		#'verify_time'            => undef,
		#'admin'                  => undef,
		#'login_whitelist'        => undef,
		subscriptions => [],
	};

};

subtest products => sub {
	plan tests => 3;

	my %products = (
		'beginner_perl_maven_ebook' => {
			'code'  => 'beginner_perl_maven_ebook',
			'_id'   => $ID,
			'name'  => 'Beginner Perl Maven e-book',
			'price' => '0.01'
		},
		'perl_maven_cookbook' => {
			'code'  => 'perl_maven_cookbook',
			'_id'   => $ID,
			'name'  => 'Perl Maven Cookbook',
			'price' => 0
		}
	);

	my $prods = $db->get_products;

	#diag explain $prod;
	cmp_deeply $prods, \%products, 'products';

	$db->add_product( { code => 'mars_landing_handbook', name => 'Mars Landing Handbook', price => 20.40 } );
	$products{mars_landing_handbook} = {
		code  => 'mars_landing_handbook',
		name  => 'Mars Landing Handbook',
		price => 20.40,
		_id   => $ID,
	};

	$prods = $db->get_products;
	cmp_deeply $prods, \%products, '3rd product added';

	my $prod = $db->get_product_by_code('mars_landing_handbook');

	#diag explain $prod;
	cmp_deeply $prod, $products{mars_landing_handbook};
};

subtest subscriptions => sub {
	plan tests => 6;

	my $ret = $db->subscribe_to(
		email => 'foo@bar.com',
		code  => 'some_other_book'
	);
	is $ret, 'no_such_code';

	#diag explain $ret;

	my $users = $db->get_people('foo@bar.com');
	is_deeply $users->[0]{subscriptions}, [];
	$ret = $db->subscribe_to(
		email => 'foo@bar.com',
		code  => 'beginner_perl_maven_ebook'
	);

	#diag explain $ret;

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
			ip   => '1.2.3.4',
			mask => '255.255.255.255',
			note => 'Some text',
		},
	);
	my $people = $db->get_people('');
	my $uid    = $people->[0]{_id};

	my $empty = $db->get_whitelist($uid);
	is_deeply $empty, [];
	$db->add_to_whitelist( $uid, $whitelist[0] );
	my $list = $db->get_whitelist($uid);

	#$whitelist[0]{id} = 1;
	is_deeply $list, \@whitelist;

	$db->delete_from_whitelist( $uid, { ip => '1.2.3.4', mask => '255.255.255.255' } );
	is_deeply $db->get_whitelist($uid), [];
};

# TODO add more entries to the whitelist and remove from the beginnig, middle and the end.

subtest verification => sub {
	plan tests => 2;

	my $people = $db->get_people('');
	my $code   = _generate_code();
	$db->save_verification(
		code    => $code,
		action  => 'add_to_whitelist',
		uid     => $people->[0]{_id},
		details => q[{ 'ip' : '1.3.5.6' }],
	);
	my $verification = $db->get_verification($code);

	#diag explain $verification;
	cmp_deeply $verification,
		{
		_id       => $ID,
		code      => $code,
		action    => 'add_to_whitelist',
		uid       => $ID,
		details   => q[{ 'ip' : '1.3.5.6' }],
		timestamp => $TIMESTAMP,
		};

	$db->delete_verification_code($code);
	is $db->get_verification($code), undef, 'verification code was removed';
};

subtest other => sub {
	plan tests => 4;
	my $people_before = $db->get_people('');
	ok !exists $people_before->[0]{name}, 'no name yet';
	ok !exists $people_before->[1]{name}, 'no name yet';

	$db->update_user($people_before->[0]{_id}, name => 'Orgo Morgo');
	my $user1 = $db->get_user_by_id($people_before->[0]{_id});
	is $user1->{name}, 'Orgo Morgo', 'name updated';

	my $user2 = $db->get_user_by_id($people_before->[1]{_id});
	ok !exists $user2->{name}, 'no name yet';
	#diag explain $people;
};

