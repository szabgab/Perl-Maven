use strict;
use warnings;

use t::lib::Test qw(read_file);

use Cwd            qw(abs_path getcwd);
use File::Basename qw(basename);
use Data::Dumper   qw(Dumper);
use Path::Tiny     ();
use Carp::Always;

use Test::Most;
use Test::Deep;
use Test::WWW::Mechanize::PSGI;

t::lib::Test::setup();

my $EPOCH = re('^\d{10}$');

my $url      = "https://$t::lib::Test::DOMAIN";
my $EMAIL    = 'gabor@perlmaven.com';
my $EMAIL2   = 'other@perlmaven.com';
my $EMAIL3   = 'zorg@perlmaven.com';
my $EMAIL4   = 'foobar@perlmaven.com';
my @PASSWORD = ( '123456', 'abcdef', 'secret', 'qwerty' );
my @NAMES    = ( 'Foo Bar', );

plan skip_all => 'We have disabled the registration features';

plan tests => 13;

ok -e 't/files/meta/meta.test-pm.com';
ok -e 't/files/meta/stats.json';
ok -e 't/files/meta/test-pm.com';
ok -e 't/files/meta/translations.json';

$ENV{EMAIL_SENDER_TRANSPORT} = 'Test';

my $cookbook_url  = '/download/some_free_product/some_free_product_v0.01.txt';
my $cookbook_text = basename $cookbook_url;

my $prod1_download_url = '/download/product_a/file_0.2.txt';
my $prod1_text         = basename $prod1_download_url;

use Dancer2;    # importing: set

set( appdir => getcwd() );
use Perl::Maven;
use Perl::Maven::DB;
my $db = Perl::Maven::DB->new('test_abc.db');

my $app = Dancer2->psgi_app;

my $w = Test::WWW::Mechanize::PSGI->new( app => $app );

my $visitor = Test::WWW::Mechanize::PSGI->new( app => $app );

diag 'subscribe to free newsletter, let them download the cookbook';

subtest static => sub {
	plan tests => 15;

	$visitor->get_ok("$url/robots.txt");
	is $visitor->content, <<"END";
Sitemap: $url/sitemap.xml

User-agent: *
Disallow: /media/*
END

	$visitor->get_ok("$url/favicon.ico");
	is $visitor->content, Path::Tiny::path('t/files/images/favicon.ico')->slurp;
	$visitor->get_ok("$url/atom");
	$visitor->get_ok("$url/rss");

	#diag $visitor->content;
	my $expected = q{<?xml version="1.0"?>
<rss xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" version="2.0">
<channel>
  <title>Test Maven</title>
  <link>https://test-pm.com/</link>
  <pubDate>2016-08-25T12:33:30 GMT</pubDate>
  <description>Test description for feed</description>
  <language>en-us</language>
  <copyright>2014 Gabor Szabo</copyright>
  <itunes:subtitle>A show about Perl and Perl users</itunes:subtitle>
  <itunes:author>Gabor Szabo</itunes:author>
  <itunes:summary>Test description for feed</itunes:summary>
  <itunes:image href="https://code-maven.com/img/code_maven_128.png" />
  <itunes:keywords>code-maven, open source, software, development, news</itunes:keywords>
  <itunes:owner>
    <itunes:name>Gabor Szabo</itunes:name>
    <itunes:email>szabgab@gmail.com</itunes:email>
  </itunes:owner>
  <itunes:explicit>no</itunes:explicit>
  <itunes:category text="Technology" />
  <item>
    <title>Testing with Perl</title>
    <link>https://test-pm.com/testing</link>
    <guid>https://test-pm.com/testing</guid>
    <description><![CDATA[<p>
A series of articles about testing, and test automation using Perl.
<p>
]]></description>
    <author>Gabor Szabo</author>
  </item>
</channel>
</rss>
};

	#my $n = 200;
	#diag length $expected;
	#is substr($visitor->content, 0, $n), substr($expected, 0, $n);
	my @expected  = grep { $_ !~ /pubDate/ } split /\n/, $expected;
	my @received  = split /\n/, $visitor->content;
	my ($pubDate) = grep {/pubDate/} @received;
	@received = grep { $_ !~ /pubDate/ } @received;
	is_deeply \@received, \@expected;

	#$visitor->get_ok("$url/rss?tag=abc");
	#diag $visitor->content;

	$visitor->get_ok("$url/tv/atom");
	$visitor->get_ok("$url/sitemap.xml");
	$visitor->get_ok("$url/css/style.css");
	is $visitor->content, Path::Tiny::path('public/css/style.css')->slurp;
	$visitor->get_ok("$url/img/feed-icon16x16.png");
	is $visitor->content, Path::Tiny::path('t/files/images/feed-icon16x16.png')->slurp;
	$visitor->get_ok("$url/img/perl_maven_150x212.png");
	is $visitor->content, Path::Tiny::path('t/files/images/perl_maven_150x212.png')->slurp;
};

subtest pages => sub {
	plan tests => 19;

	$visitor->get_ok($url);
	$visitor->content_like(qr/Some text comes here/);

	$visitor->get_ok("$url/testing");
	$visitor->content_like(qr/A series of articles about testing, and test automation using Perl./);
	$visitor->content_like(qr{A bunch of links.});

	$visitor->get("$url/abc");
	is $visitor->status, 404, 'status is 404';
	$visitor->content_like(qr{No such article});

	$visitor->get_ok("$url/pro/paid");
	$visitor->content_like(qr{This is the abstract of a paid pro page.});
	$visitor->content_unlike(qr{This it the content of a paid pro page});
	is $visitor->base, "$url/pro/paid", 'stayed on the page';

	$visitor->get_ok($cookbook_url);
	is $visitor->base, "$url/", 'redirected to root';

	$visitor->get_ok($prod1_download_url);
	is $visitor->base, "$url/", 'redirected to root';

	$visitor->get_ok('/pm/account');
	is $visitor->base, "$url/pm/login", 'redirected to login page';

	# strangely for this post() request I had to supply the full URL or it would go to http://localhost/
	$visitor->post_ok("$url/pm/change-email");
	is $visitor->base, "$url/pm/login", 'redirected to login page';

	#diag $visitor->content;
};

# TODO test the various cases of no or bad e-mail addresses and also duplicate registration (and different case).
# TODO do this both on the main page and on the /perl-maven-cookbook page
subtest 'subscribe' => sub {
	plan tests => 43;
	$w->get_ok("$url/pm/register");
	$w->content_like(qr/register to our web site/);

	$w->submit_form_ok(
		{
			form_name => 'registration_form',
			fields    => {
				email => $EMAIL,
			},
		},
		'has registeration form'
	);

	my @mails = Email::Sender::Simple->default_transport->deliveries;

	# Returns a list of hashesh. Each has has 4 keys:
	# successes, failures, envelope, email
	#diag join ', ', keys %{ $mails[0] };
	is_deeply $mails[0]{successes}, [$EMAIL];
	is_deeply $mails[0]{failures},  [];

	#diag explain $mails[0]{successes};
	#diag explain $mails[0]{failures};
	is_deeply $mails[0]{envelope},
		{
		'from' => 'test@perlmaven.com',
		'to'   => ['gabor@perlmaven.com']
		};

	#diag explain $mails[0]{email}; # Email::Abstract object
	my $o    = $mails[0]{email}->object;
	my $mail = $mails[0]{email}->as_string;

	#	diag $mail;

	#my $mail_regex = qr{<a href="($url/pm/verify/1/\w+)">verify</a>};
	my $mail_regex = qr{verify\s+\[\s+($url/pm/verify2/\w+)};
	my ($set_url) = $mail =~ $mail_regex;
	ok $set_url, "mail with url address to $set_url";

	#diag $set_url;
	#diag explain $db->{dbh}->selectall_arrayref('SELECT * FROM user');
	$w->get_ok("$url/pm/verify2/1234567");
	$w->content_like( qr{Invalid or expired verification code.}, 'no such code' );
	cmp_deeply $db->{dbh}->selectall_arrayref('SELECT * FROM user'),
		[ [ 1, 'gabor@perlmaven.com', undef, undef, undef, $EPOCH, undef, undef, undef, undef, undef ] ],
		'user table';
	cmp_deeply $db->{dbh}->selectall_arrayref('SELECT * FROM product'),
		[
		[ 1, 'some_free_product',         'Perl Maven Cookbook',        0 ],
		[ 2, 'beginner_perl_maven_ebook', 'Beginner Perl Maven e-book', '0.01' ]
		],
		'product table';
	cmp_deeply $db->{dbh}->selectall_arrayref('SELECT * FROM subscription'), [], 'subscription table';

	$w->get_ok($set_url);
	$w->content_unlike(qr{Internal verification error});
	cmp_deeply $db->{dbh}->selectall_arrayref('SELECT * FROM user'),
		[ [ 1, 'gabor@perlmaven.com', undef, undef, undef, $EPOCH, undef, $EPOCH, undef, undef, undef ] ],
		'user table';
	cmp_deeply $db->{dbh}->selectall_arrayref('SELECT * FROM product'),
		[
		[ 1, 'some_free_product',         'Perl Maven Cookbook',        0 ],
		[ 2, 'beginner_perl_maven_ebook', 'Beginner Perl Maven e-book', '0.01' ]
		],
		'product table';
	my $subscription = $db->{dbh}->selectall_arrayref('SELECT * FROM subscription');

	#diag Dumper $subscription;
	cmp_deeply $subscription, [ [ 1, 1, undef ] ], 'subscription table';

	#diag $w->content;
	# the new page does not contain a link to the cookbook.
	#$w->content_like( qr{<a href="$cookbook_url">$cookbook_text</a>}, 'download link' );
	$w->get_ok("$url/pm/user-info");
	is_deeply from_json( $w->content ), { logged_in => 1, code_maven_pro => 0, admin => 0 };

	# check e-mails
	@mails = Email::Sender::Simple->default_transport->deliveries;
	is scalar @mails, 3;
	my $mail2 = $mails[1]{email}->as_string;
	my $mail3 = $mails[2]{email}->as_string;

	like $mail2, qr{Thank you for registering}, 'thank you mail';
	like $mail3, qr{$EMAIL has registered},     'self reporting';

	# hit it again
	$w->get_ok($set_url);

	@mails = Email::Sender::Simple->default_transport->deliveries;
	is scalar @mails, 3;

	$w->get_ok("$url/pm/account");
	cmp_deeply $db->{dbh}->selectall_arrayref('SELECT * FROM user'),
		[ [ 1, 'gabor@perlmaven.com', undef, undef, undef, $EPOCH, undef, $EPOCH, undef, undef, undef ] ],
		'user table';
	cmp_deeply $db->{dbh}->selectall_arrayref('SELECT * FROM product'),
		[
		[ 1, 'some_free_product',         'Perl Maven Cookbook',        0 ],
		[ 2, 'beginner_perl_maven_ebook', 'Beginner Perl Maven e-book', '0.01' ]
		],
		'product table';
	$subscription = $db->{dbh}->selectall_arrayref('SELECT * FROM subscription');

	#diag Dumper $subscription;
	cmp_deeply $subscription, [ [ 1, 1, undef ] ], 'subscription table';

	#diag $w->content;
	$w->follow_link_ok(
		{
			text => $cookbook_text,
		},
		'download_pdf'
	);
	my $src_pdf = read_file("t/files/$cookbook_url");
	$w->content_is( $src_pdf, 'content of the file we downloaded is the same that is on the disk' );

	# go to main page
	$w->get_ok($url);
	$w->get_ok($cookbook_url);
	$w->content_is( $src_pdf, 'direct download works' );

	# registered users cannot download a product they don't own.
	$w->get_ok($prod1_download_url);
	is $w->base, "$url/", 'redirected to root';

	$w->get_ok('/pm/account');
	$w->content_like( qr{<a href="$cookbook_url">$cookbook_text</a>}, 'download link' );
	$w->content_like( qr{<a href="/pm/logout">logout</a>},            'logout link' );
	$w->get_ok('/pm/logout');
	$w->get_ok('/pm/account');
	$w->content_unlike( qr{<a href="$cookbook_url">$cookbook_text</a>}, 'download link' );
	$w->get_ok("$url/pm/user-info");
	is_deeply from_json( $w->content ), { logged_in => 0, code_maven_pro => 0, admin => 0 };
};

{
	my $id = $db->add_registration( { email => $EMAIL3 } );
	$db->set_password( $id, $PASSWORD[2] );
}

# ask the system to send a password reminder, use the link to set the password
# log out and then login again
subtest 'ask for password reset, then login' => sub {

	plan tests => 28;
	$w->get_ok('/pm/account');
	$w->content_like(qr{Login});
	$w->content_like(qr{Forgot your password or don't have one yet});

	#diag('try invalid e-mail address, see error message');
	$w->submit_form_ok(
		{
			form_name => 'send_reset_pw',
			fields    => {
				email => 'gabor@nosuch.com',
			},
		},
		'ask to reset password for bad e-mail address'
	);
	$w->content_like(qr{Could not find this e-mail address in our database});
	$w->back;

	#diag('try the correct e-mail address');
	$w->submit_form_ok(
		{
			form_name => 'send_reset_pw',
			fields    => {
				email => $EMAIL,
			},
		},
		'ask to reset password'
	);
	$w->content_like(qr{E-mail sent with code to reset password});

	my @mails = Email::Sender::Simple->default_transport->deliveries;
	my $mail  = $mails[3]{email}->as_string;

	#diag $mail;
	my $mail_regex = qr{set new password \[ ($url/pm/verify2/(?:\w+))=\s*(\w+) \]};
	my ( $url1, $url2 ) = $mail =~ $mail_regex;
	my $set_url = "$url1$url2";
	ok $set_url, 'mail with set url address';
	diag $set_url;

	#diag 'click on the link received in the e-mail';
	$w->get_ok($set_url);
	$w->submit_form_ok(
		{
			form_name => 'set_password',
			fields    => {
				password => $PASSWORD[0],
			},
		},
		'set password'
	);

	#diag($w->content);
	$w->get_ok("$url/pm/user-info");
	is_deeply from_json( $w->content ), { logged_in => 1, code_maven_pro => 0, admin => 0 };

	# white-box:
	my $user = $db->get_user_by_email($EMAIL);
	is substr( $user->{password}, 0, 7 ), '{CRYPT}';

	#diag('now logout');
	$w->get_ok("$url/pm/logout");
	$w->get_ok("$url/pm/user-info");
	is_deeply from_json( $w->content ), { logged_in => 0, code_maven_pro => 0, admin => 0 };

	#diag('login now that we have a password');
	$w->get_ok("$url/pm/login");
	$w->submit_form_ok(
		{
			form_name => 'login',
			fields    => {
				email    => $EMAIL,
				password => $PASSWORD[0],
			},
		},
		'login'
	);
	$w->content_like( qr{<a href="$cookbook_url">$cookbook_text</a>}, 'download link' );
	$w->get_ok("$url/pm/user-info");
	is_deeply from_json( $w->content ), { logged_in => 1, code_maven_pro => 0, admin => 0 };

	#diag $w->content;
	$w->get_ok("$url/pm/register");
	$w->content_like( qr{Why would you want to register if you are already logged in},
		'register form when already logged in' );
	$w->content_unlike(qr/register to our web site/);

	$w->get_ok("$url/pm/login");
	$w->content_like( qr{You are already logged in. Go to your <a href="/pm/account">account</a>},
		'/pm/login when already logged in' );

	$w->get_ok("$url/pm/user-info");
	is_deeply from_json( $w->content ), { logged_in => 1, code_maven_pro => 0, admin => 0 };
};

# now change password while logged in,
# log out and check if we fail to log in with
# the old password but we can log in with the new.
subtest 'change password while logged in' => sub {
	plan tests => 20;

	$w->get_ok('/pm/account');

	#diag('different passwords');
	$w->submit_form_ok(
		{
			form_name => 'change_password',
			fields    => {
				password  => $PASSWORD[1],
				password2 => "$PASSWORD[1]x",
			},
		},
		'different password'
	);
	$w->content_like( qr{Passwords don't match}, q{passwords don't match} );
	$w->back;

	# white-box:
	my $user = $db->get_user_by_email($EMAIL);
	is substr( $user->{password}, 0, 7 ), '{CRYPT}';

	$w->submit_form_ok(
		{
			form_name => 'change_password',
			fields    => {
				password  => $PASSWORD[1],
				password2 => $PASSWORD[1],
			},
		},
		'change password'
	);

	#diag($w->content);
	$w->content_like( qr{The password was set successfully}, 'password was reset' );
	$w->get_ok("$url/pm/logout");
	$w->get_ok("$url/pm/user-info");
	is_deeply from_json( $w->content ), { logged_in => 0, code_maven_pro => 0, admin => 0 };

	$w->get_ok("$url/pm/login");
	$w->submit_form_ok(
		{
			form_name => 'login',
			fields    => {
				email    => $EMAIL,
				password => $PASSWORD[0],
			},
		},
		'login'
	);
	$w->content_like(qr{Invalid });
	$w->get_ok("$url/pm/user-info");
	is_deeply from_json( $w->content ), { logged_in => 0, code_maven_pro => 0, admin => 0 };

	$w->back;
	$w->get_ok("$url/pm/login");
	$w->submit_form_ok(
		{
			form_name => 'login',
			fields    => {
				email    => $EMAIL,
				password => $PASSWORD[1],
			},
		},
		'login'
	);
	$w->content_like( qr{<a href="$cookbook_url">$cookbook_text</a>}, 'download link' );

	$w->get_ok("$url/pm/user-info");
	is_deeply from_json( $w->content ), { logged_in => 1, code_maven_pro => 0, admin => 0 };

	#diag($w->content);

	my $other_user = $db->get_user_by_id(2);
	is $other_user->{password}, $PASSWORD[2], 'other use still exists with old password';
};

subtest 'name' => sub {
	plan tests => 5;

	$w->get_ok('/pm/account');
	my $form1 = $w->form_name('user');

	#diag($form1->value('name'));
	$w->submit_form_ok(
		{
			form_name => 'user',
			fields    => {
				name => $NAMES[0],
			},
		},
		'user form'
	);
	$w->content_like(qr{Updated});
	$w->get_ok('/pm/account');
	my $form2 = $w->form_name('user');

	#diag($form2->value('name'));
	is( $form2->value('name'), $NAMES[0], 'name displayed' );

	#diag(explain($form));
};

subtest change_email => sub {
	plan tests => 12;

	$w->get_ok('/pm/account');
	$w->submit_form_ok(
		{
			form_name => 'change_email',
			fields    => {
				email => $EMAIL2,
			},
		},
		'change_email'
	);

	my @mails = Email::Sender::Simple->default_transport->deliveries;
	my $mail  = $mails[4]{email}->as_string;

	#diag $mail;
	#my $mail_regex = qr{<a href="($url/pm/verify2/\w+)">verify</a>};
	my $mail_regex = qr{verify \[ ($url/pm/verify2/\w+)};
	my ($set_url) = $mail =~ $mail_regex;
	ok $set_url, 'mail with set url address';
	diag $set_url;

	$w->get_ok("$url/pm/verify2/1234567");
	$w->content_like( qr{Invalid or expired verification code.}, 'invalid verification code' );

	my $before = $db->get_user_by_id(1);
	is $before->{email}, $EMAIL, 'old email';

	$w->get_ok($set_url);
	$w->content_like( qr{Email updated successfully.}, 'updated successfully mesage' );

	my $after = $db->get_user_by_id(1);
	is $after->{email}, $EMAIL2, 'old email';

	$w->get_ok($set_url);
	$w->content_like( qr{Invalid or expired verification code.}, 'invalid verification code' );

	my $other_user = $db->get_user_by_id(2);
	is $other_user->{email}, $EMAIL3, 'other use still exists with old email';
};

subtest whitelist => sub {
	plan tests => 9;

	$w->get_ok('/pm/account');
	my $form = $w->form_name('enable_white_list');
	ok $form, 'form found';
	$w->submit_form_ok(
		{
			form_name => 'enable_white_list',
		},
		'enable whitelist'
	);

	$w->content_like(qr{Whitelist enabled});
	$w->follow_link_ok( { text => 'account' }, 'back to account' );
	my $form2 = $w->form_name('enable_white_list');
	ok !$form2, 'form not found';

	$w->submit_form_ok(
		{
			form_name => 'disable_white_list',
		},
		'disable whitelist'
	);
	$w->follow_link_ok( { text => 'account' }, 'back to account' );
	my $form3 = $w->form_name('enable_white_list');
	ok $form3, 'form found';

};

subtest register_with_password => sub {
	plan tests => 6;

	my $x = Test::WWW::Mechanize::PSGI->new( app => $app );
	$x->get_ok("$url/pm/register");
	$x->submit_form_ok(
		{
			form_name => 'registration_form',
			fields    => {
				email    => $EMAIL4,
				password => $PASSWORD[3],
			},
		},
		'registeration form filled'
	);

	#diag $x->content;
	$x->content_like(qr{<a href="/pm/login">Login</a>});
	$x->follow_link_ok( { text => 'Login' } );
	$x->submit_form_ok(
		{
			form_name => 'login',
			fields    => {
				email    => $EMAIL4,
				password => $PASSWORD[3],
			},
		},
		'login'
	);
	$x->content_like(qr{<a href="/pm/logout">logout</a>});

	#diag $x->content;
};

