use strict;
use warnings;
use Test::Most;
use Test::Deep qw(cmp_deeply re ignore isa);

use File::Copy qw(move);
use Capture::Tiny qw(capture);
use Cwd qw(cwd);
use t::lib::Test;

plan skip_all => 'Old MongoDB on Travis???' if $ENV{TRAVIS};

plan tests => 8;

t::lib::Test::setup();

use Perl::Maven::DB;
use Perl::Maven::WebTools qw(_generate_code);

my $db        = Perl::Maven::DB->instance;
my $TIMESTAMP = isa('DateTime::Tiny');
my $ID        = re('^\w+$');

diag qx{mongo --version};

subtest users => sub {
	plan tests => 13;

	my $people = $db->get_people('');
	is_deeply $people, [], 'no people';

	my $id = $db->add_registration( { email => 'foo@bar.com' } );
	$people = $db->get_people('');
	cmp_deeply $people, [ { _id => $ID, email => 'foo@bar.com', subscriptions => [], register_time => $TIMESTAMP } ],
		'first person';

	my $user = $db->get_user_by_id( $people->[0]{_id} );
	cmp_deeply $user,
		{
		'_id'           => $ID,
		'email'         => 'foo@bar.com',
		'register_time' => $TIMESTAMP,
		subscriptions   => [],
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
		{ _id => $ID, email => 'buzz@nasa.com', register_time => $TIMESTAMP, subscriptions => [] },
		{ _id => $ID, email => 'foo@bar.com',   register_time => $TIMESTAMP, subscriptions => [] },
		],
		'two people';

	$people = $db->get_people('oo');
	cmp_deeply $people, [ { _id => $ID, email => 'foo@bar.com', register_time => $TIMESTAMP, subscriptions => [] } ],
		'one person';

	my $p = $db->get_user_by_email('foo@bar');
	is $p, undef, 'no such email';
	$p = $db->get_user_by_email('foo@bar.com');

	#diag explain $p;
	cmp_deeply $p,
		{
		'_id'           => $ID,
		'email'         => 'foo@bar.com',
		'register_time' => $TIMESTAMP,
		subscriptions   => [],
		};

	ok $db->add_registration( { email => 'foo@perlmaven.com' } );
	ok $db->add_registration( { email => 'bar@perlmaven.com' } );
	ok !$db->add_registration( { email => 'bar@perlmaven.com' } ), 'cannot add the same e-mail twice';
	my $all = $people = $db->get_people('');
	is scalar @$all, 4;

	#diag explain $all;

	my $stats = $db->stats;

	#diag explain $stats;
	cmp_deeply $stats,
		{
		'all_users'    => 4,
		'no_password'  => 0,
		'verified'     => 0,
		'not_verified' => 4,
		'has_password' => 0,
		'new_password' => 0,
		'old_password' => 0,
		'products'     => {
			'beginner_perl_maven_ebook' => {
				'_id'   => $ID,
				'code'  => 'beginner_perl_maven_ebook',
				'name'  => 'Beginner Perl Maven e-book',
				'price' => '0.01'
			},
			'perl_maven_cookbook' => {
				'_id'   => $ID,
				'code'  => 'perl_maven_cookbook',
				'name'  => 'Perl Maven Cookbook',
				'price' => 0
			}
		}
		};

};

subtest replace_email => sub {
	plan tests => 3;

	my $before = $db->get_user_by_email('buzz@nasa.com');

	cmp_deeply $before,
		{
		'_id'           => $ID,
		'email'         => 'buzz@nasa.com',
		'register_time' => $TIMESTAMP,
		subscriptions   => [],
		};

	$db->replace_email( 'buzz@nasa.com', 'buzz@buzzaldrin.com' );

	my $after_old = $db->get_user_by_email('buzz@nasa.com');
	is $after_old, undef;

	my $after = $db->get_user_by_email('buzz@buzzaldrin.com');

	cmp_deeply $after,
		{
		'_id'           => $ID,
		'email'         => 'buzz@buzzaldrin.com',
		'register_time' => $TIMESTAMP,
		subscriptions   => [],
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
	plan tests => 14;

	my $ret = $db->subscribe_to(
		email => 'foo@bar.com',
		code  => 'some_other_book'
	);
	is $ret, 'no_such_code';

	#diag explain $ret;

	is_deeply $db->get_subscribers('beginner_perl_maven_ebook'), [], 'no subscriber';
	my $users = $db->get_people('foo@bar.com');
	is_deeply $users->[0]{subscriptions}, [];
	ok !$db->is_subscribed( $users->[0]{_id}, 'beginner_perl_maven_ebook' ), 'not subscribed';
	$ret = $db->subscribe_to(
		email => 'foo@bar.com',
		code  => 'beginner_perl_maven_ebook'
	);
	ok $db->is_subscribed( $users->[0]{_id}, 'beginner_perl_maven_ebook' ), 'subscribed';
	my $user0 = $db->get_user_by_id( $users->[0]{_id} );
	is_deeply $db->get_subscribers('beginner_perl_maven_ebook'), [$user0];

	#diag explain $db->get_subscribers('beginner_perl_maven_ebook');
	#diag explain $user0;

	#diag explain $ret;

	$users = $db->get_people('foo@bar.com');
	is_deeply $users->[0]{subscriptions}, ['beginner_perl_maven_ebook'], 'subscribed';

	$db->subscribe_to(
		email => 'foo@bar.com',
		code  => 'mars_landing_handbook'
	);
	$users = $db->get_people('foo@bar.com');
	is_deeply $users->[0]{subscriptions}, [ 'beginner_perl_maven_ebook', 'mars_landing_handbook' ], 'subscribed';

	my $stats1 = $db->stats;

	#diag explain $stats1;
	cmp_deeply $stats1,
		{
		'all_users'    => 4,
		'no_password'  => 0,
		'verified'     => 0,
		'not_verified' => 4,
		'has_password' => 0,
		'new_password' => 0,
		'old_password' => 0,
		'products'     => {
			'beginner_perl_maven_ebook' => {
				'_id'   => $ID,
				'code'  => 'beginner_perl_maven_ebook',
				'name'  => 'Beginner Perl Maven e-book',
				'price' => '0.01'
			},
			'mars_landing_handbook' => {
				'_id'   => $ID,
				'code'  => 'mars_landing_handbook',
				'name'  => 'Mars Landing Handbook',
				'price' => '20.4'
			},
			'perl_maven_cookbook' => {
				'_id'   => $ID,
				'code'  => 'perl_maven_cookbook',
				'name'  => 'Perl Maven Cookbook',
				'price' => 0
			}
		}
		},
		'stats1';
	is_deeply $db->get_subscribers('beginner_perl_maven_ebook'), $db->get_people('foo@bar.com');

	$db->subscribe_to(
		email => 'foo@perlmaven.com',
		code  => 'beginner_perl_maven_ebook'
	);

	#diag explain $db->get_subscribers('beginner_perl_maven_ebook');
	is_deeply $db->get_subscribers('beginner_perl_maven_ebook'),
		[ $db->get_people('foo@bar.com')->[0], $db->get_people('foo@perlmaven.com')->[0], ];

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

	my $stats2 = $db->stats;

	#diag explain $stats;
	cmp_deeply $stats2,
		{
		'all_users'    => 4,
		'no_password'  => 0,
		'verified'     => 0,
		'not_verified' => 4,
		'has_password' => 0,
		'new_password' => 0,
		'old_password' => 0,
		'products'     => {
			'beginner_perl_maven_ebook' => {
				'_id'   => $ID,
				'code'  => 'beginner_perl_maven_ebook',
				'name'  => 'Beginner Perl Maven e-book',
				'price' => '0.01'
			},
			'mars_landing_handbook' => {
				'_id'   => $ID,
				'code'  => 'mars_landing_handbook',
				'name'  => 'Mars Landing Handbook',
				'price' => '20.4'
			},
			'perl_maven_cookbook' => {
				'_id'   => $ID,
				'code'  => 'perl_maven_cookbook',
				'name'  => 'Perl Maven Cookbook',
				'price' => 0
			}
		}
		},
		'stats2';
};

subtest whitelist => sub {
	plan tests => 5;

	my @whitelist = (
		{
			ip   => '1.2.3.4',
			mask => '255.255.255.255',
			note => 'Some text',
		},
		{
			ip   => '1.2.3.5',
			mask => '255.255.255.255',
			note => 'Some other text',
		},
		{
			ip   => '12.2.3.5',
			mask => '255.255.255.0',
			note => 'Yet another text',
		},
	);
	my $people = $db->get_people('');
	my $uid    = $people->[0]{_id};

	my $empty = $db->get_whitelist($uid);
	is_deeply $empty, [];

	$db->add_to_whitelist( $uid, $whitelist[0] );
	my $list = $db->get_whitelist($uid);
	is_deeply $list, [ $whitelist[0] ];

	$db->add_to_whitelist( $uid, $whitelist[1] );
	is_deeply $db->get_whitelist($uid), [ @whitelist[ 0, 1 ] ];

	$db->add_to_whitelist( $uid, $whitelist[2] );
	is_deeply $db->get_whitelist($uid), [ @whitelist[ 0, 1, 2 ] ];

	$db->delete_from_whitelist( $uid, { ip => '1.2.3.5', mask => '255.255.255.255' } );
	is_deeply $db->get_whitelist($uid), [ @whitelist[ 0, 2 ] ];
};

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

subtest update_user => sub {
	plan tests => 16;

	my $people_before = $db->get_people('');
	for my $i ( 0 .. 1 ) {
		for my $field (qw(name verify_time password)) {
			ok !exists $people_before->[$i]{$field}, "no $field yet";
		}
	}

	#diag explain $people_before;

	$db->update_user( $people_before->[0]{_id}, name => 'Orgo Morgo' );
	ok !$db->verify_registration('random string'), 'verify_registration for not existing user id';
	ok $db->verify_registration( $people_before->[1]{_id} ), 'verify_registration';
	ok !$db->verify_registration( $people_before->[1]{_id} ), 'verify_registration cannot use same code again';
	$db->set_password( $people_before->[0]{_id}, 'abcdef' );
	my $user1 = $db->get_user_by_id( $people_before->[0]{_id} );
	is $user1->{name}, 'Orgo Morgo', 'name updated';
	ok !exists $user1->{verify_time}, 'still no verify_time';
	is $user1->{password}, 'abcdef', 'password updated';

	my $user2 = $db->get_user_by_id( $people_before->[1]{_id} );
	ok !exists $user2->{name},     'no name yet';
	ok !exists $user2->{password}, 'no password yet';
	isa_ok $user2->{verify_time}, 'DateTime::Tiny';

	my $stats = $db->stats;
	cmp_deeply $stats,
		{
		'all_users'    => '4',
		'no_password'  => '1',
		'not_verified' => '3',
		'verified'     => 1,
		'has_password' => 1,
		'new_password' => 0,
		'old_password' => 1,
		'products'     => {
			'beginner_perl_maven_ebook' => {
				'_id'   => $ID,
				'code'  => 'beginner_perl_maven_ebook',
				'name'  => 'Beginner Perl Maven e-book',
				'price' => '0.01'
			},
			'perl_maven_cookbook' => {
				'_id'   => $ID,
				'code'  => 'perl_maven_cookbook',
				'name'  => 'Perl Maven Cookbook',
				'price' => 0
			},
			'mars_landing_handbook' => {
				'_id'   => $ID,
				'code'  => 'mars_landing_handbook',
				'name'  => 'Mars Landing Handbook',
				'price' => '20.4'
			},
		}
		};

};

subtest delete_user => sub {
	plan tests => 2;

	my $people_before = $db->get_people('');
	is scalar @$people_before, 4;
	$db->delete_user( $people_before->[0]{email} );
	my $people_after = $db->get_people('');
	is scalar @$people_after, 3;
};

