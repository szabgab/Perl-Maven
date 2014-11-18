use strict;
use warnings;
use Test::More tests => 3;
use Test::Deep qw(cmp_deeply re);

use File::Copy qw(move);
use Capture::Tiny qw(capture);
use Cwd qw(cwd);
use t::lib::Test;

t::lib::Test::setup();

use Perl::Maven::DB;
my $db = Perl::Maven::DB->new('pm.db');

subtest users => sub {
	plan tests => 6;

	my $people = $db->get_people('');
	is_deeply $people, [], 'no people';

	my $id = $db->add_registration( 'foo@bar.com', '123' );
	$people = $db->get_people('');
	is_deeply $people, [ [ 1, 'foo@bar.com', undef ] ], 'first person';

	$db->add_registration( 'buzz@nasa.com', '123' );
	$people = $db->get_people('');

	#diag explain $people;
	is_deeply $people,
		[ [ 1, 'foo@bar.com', undef ], [ 2, 'buzz@nasa.com', undef ] ],
		'two people';

	$people = $db->get_people('oo');
	is_deeply $people, [ [ 1, 'foo@bar.com', undef ] ], 'one person';

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
		'register_time'          => re('\d+'),
		'verify_code'            => '123',
		'verify_time'            => undef
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
		'perl_maven_cookbook' => {
			'code'  => 'perl_maven_cookbook',
			'id'    => 1,
			'name'  => 'Perl Maven Cookbook',
			'price' => 0
		}
	);

	my $prod = $db->get_products;

	#diag explain $prod;
	is_deeply $prod, \%products, 'products';

	$db->add_product( 'mars_landing_handbook', 'Mars Landing Handbook',
		20.40 );
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

	my @subs = $db->get_subscriptions('foo@bar.com');
	is_deeply \@subs, [];
	$db->subscribe_to( 'foo@bar.com', 'beginner_perl_maven_ebook' );

	@subs = $db->get_subscriptions('foo@bar.com');
	is_deeply \@subs, [ 'beginner_perl_maven_ebook' ], 'subscribed';

	$db->subscribe_to( 'foo@bar.com', 'mars_landing_handbook' );
	@subs = $db->get_subscriptions('foo@bar.com');
	is_deeply \@subs,
		[ 'beginner_perl_maven_ebook', 'mars_landing_handbook' ],
		'subscribed';

	$db->unsubscribe_from( 'foo@bar.com', 'mars_landing_handbook' );
	@subs = $db->get_subscriptions('foo@bar.com');
	is_deeply \@subs, [ 'beginner_perl_maven_ebook' ], 'subscribed';

	$db->unsubscribe_from( 'foo@bar.com', 'beginner_perl_maven_ebook' );
	@subs = $db->get_subscriptions('foo@bar.com');
	is_deeply \@subs, [];

};

