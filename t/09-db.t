use strict;
use warnings;
use Test::More tests => 5;
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

	my $id = $db->add_registration( { email => 'foo@bar.com' } );
	$people = $db->get_people('');
	is_deeply $people, [ { id => 1, email => 'foo@bar.com', verify_time => undef } ], 'first person';

	$db->add_registration( { email => 'buzz@nasa.com' } );
	$people = $db->get_people('');

	#diag explain $people;
	is_deeply $people,
		[
		{ id => 1, email => 'foo@bar.com',   verify_time => undef },
		{ id => 2, email => 'buzz@nasa.com', verify_time => undef }
		],
		'two people';

	$people = $db->get_people('oo');
	is_deeply $people, [ { id => 1, email => 'foo@bar.com', verify_time => undef } ], 'one person';

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
		'verify_code'            => undef,
		'verify_time'            => undef,
		'admin'                  => undef,
		'login_whitelist'        => undef,
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

	my @subs = $db->get_subscriptions('foo@bar.com');
	is_deeply \@subs, [];
	$db->subscribe_to(
		email => 'foo@bar.com',
		code  => 'beginner_perl_maven_ebook'
	);

	@subs = $db->get_subscriptions('foo@bar.com');
	is_deeply \@subs, ['beginner_perl_maven_ebook'], 'subscribed';

	$db->subscribe_to(
		email => 'foo@bar.com',
		code  => 'mars_landing_handbook'
	);
	@subs = $db->get_subscriptions('foo@bar.com');
	is_deeply \@subs, [ 'beginner_perl_maven_ebook', 'mars_landing_handbook' ], 'subscribed';

	$db->unsubscribe_from(
		email => 'foo@bar.com',
		code  => 'mars_landing_handbook'
	);
	@subs = $db->get_subscriptions('foo@bar.com');
	is_deeply \@subs, ['beginner_perl_maven_ebook'], 'subscribed';

	$db->unsubscribe_from(
		email => 'foo@bar.com',
		code  => 'beginner_perl_maven_ebook'
	);
	@subs = $db->get_subscriptions('foo@bar.com');
	is_deeply \@subs, [];

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

