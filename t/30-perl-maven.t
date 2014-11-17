use strict;
use warnings;

use t::lib::Test qw(psgi_start read_file);

use Cwd qw(abs_path getcwd);
use File::Basename qw(basename);
use Data::Dumper qw(Dumper);

use Test::More;
use Test::Deep;
use Test::WWW::Mechanize::PSGI;

psgi_start();

my $url      = 'http://test-perl-maven.com';
my $EMAIL    = 'gabor@perlmaven.com';
my @PASSWORD = ( '123456', 'abcdef', );
my @NAMES    = ( 'Foo Bar', );

plan tests => 5;

my $cookbook_url
	= '/download/perl_maven_cookbook/perl_maven_cookbook_v0.01.txt';
my $cookbook_text = basename $cookbook_url;

my $prod1_download_url = '/download/product_a/file_0.2.txt';
my $prod1_text         = basename $prod1_download_url;

use Dancer qw(:tests);

Dancer::set( appdir => getcwd() );
use Perl::Maven;

my $app = Dancer::Handler->psgi_app;

my $w = Test::WWW::Mechanize::PSGI->new( app => $app );

my $visitor = Test::WWW::Mechanize::PSGI->new( app => $app );

diag
	'subscribe to free Perl Maven newsletter, let them download the cookbook';

# There can be products downloadable by any visitor
#                                    by registered user
#                                    by user subscribed to mailing list (a free product)
#                                    by owner of a product
# There can be individual pages viewable
#                                    by
#                                    by registered user
#                                    by owner of a product

subtest pages => sub {
	plan tests => 17;

	$visitor->get_ok($url);
	$visitor->content_like(qr/Some text comes here/);

	$visitor->get_ok("$url/testing");
	$visitor->content_like(
		qr/A series of articles about testing, and test automation using Perl./
	);
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

	$visitor->get_ok('/account');
	is $visitor->base, "$url/login", 'redirected to login page';

	#diag $visitor->content;
};

# TODO test the various cases of no or bad e-mail addresses and also duplicate registration (and different case).
# TODO do this both on the main page and on the /perl-maven-cookbook page
subtest 'subscribe' => sub {
	plan tests => 31;
	$w->get_ok($url);
	$w->content_like(qr/Perl Maven/);

	$w->submit_form_ok(
		{
			form_name => 'registration_form',
			fields    => {
				email => $EMAIL,
			},
		},
		'has registeration form'
	);
	my $mail = read_file( $ENV{PERL_MAVEN_MAIL} );
	unlink $ENV{PERL_MAVEN_MAIL};

	my $mail_regex = qr{<a href="($url/verify/1/\w+)">verify</a>};
	my ($set_url) = $mail =~ $mail_regex;
	ok $set_url, 'mail with set url address';
	diag $set_url;

	$w->get_ok("$url/verify/20/1234567");
	$w->content_like( qr{User not found}, 'no such user' );

	$w->get_ok("$url/verify/1/1234567");
	$w->content_like( qr{Invalid or missing code}, 'incorrect code' );

	$w->get_ok($set_url);
	$w->content_like( qr{<a href="$cookbook_url">$cookbook_text</a>},
		'download link' );
	$w->get_ok("$url/logged-in");
	$w->content_is(1);

	# check e-mails
	my $mail2 = read_file( $ENV{PERL_MAVEN_MAIL} );
	unlink $ENV{PERL_MAVEN_MAIL};

	like $mail2, qr{Thank you for registering}, 'thank you mail';
	like $mail2, qr{$EMAIL has registered},     'self reporting';

	# hit it again
	$w->get_ok($set_url);

	ok !-e $ENV{PERL_MAVEN_MAIL}, 'no additional mail was sent';

	$w->follow_link_ok(
		{
			text => $cookbook_text,
		},
		'download_pdf'
	);
	my $src_pdf = read_file("t/files/$cookbook_url");
	$w->content_is( $src_pdf,
		'content of the file we downloaded is the same that is on the disk' );

	# go to main page
	$w->get_ok($url);
	$w->get_ok($cookbook_url);
	$w->content_is( $src_pdf, 'direct download works' );

	# registered users cannot download a product they don't own.
	$w->get_ok($prod1_download_url);
	is $w->base, "$url/", 'redirected to root';

	$w->get_ok('/account');
	$w->content_like( qr{<a href="$cookbook_url">$cookbook_text</a>},
		'download link' );
	$w->content_like( qr{<a href="/logout">logout</a>}, 'logout link' );
	$w->get_ok('/logout');
	$w->get_ok('/account');
	$w->content_unlike( qr{<a href="$cookbook_url">$cookbook_text</a>},
		'download link' );
	$w->get_ok("$url/logged-in");
	is $w->content, 0;
};

# ask the system to send a password reminder, use the link to set the password
# log out and then login again
subtest 'ask for password reset, then login' => sub {

	plan tests => 20;
	$w->get_ok('/account');
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

	my $mail = read_file( $ENV{PERL_MAVEN_MAIL} );
	unlink $ENV{PERL_MAVEN_MAIL};

	#diag $mail;
	my $mail_regex
		= qr{<a href="($url/set-password/1/(\w+))">set new password</a>};
	my ($set_url) = $mail =~ $mail_regex;
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
	$w->get_ok("$url/logged-in");
	$w->content_is(1);

	#diag('now logout');
	$w->get_ok("$url/logout");
	$w->get_ok("$url/logged-in");
	$w->content_is(0);

	#diag('login now that we have a password');
	$w->get_ok("$url/login");
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
	$w->content_like( qr{<a href="$cookbook_url">$cookbook_text</a>},
		'download link' );

	#diag $w->content;

	$w->get_ok("$url/logged-in");
	$w->content_is(1);
};

# now change password while logged in,
# log out and check if we fail to log in with
# the old password but we can log in with the new.
subtest 'change password while logged in' => sub {
	plan tests => 18;

	$w->get_ok('/account');

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
	$w->content_like( qr{The password was set successfully},
		'password was reset' );
	$w->get_ok("$url/logout");
	$w->get_ok("$url/logged-in");
	$w->content_is(0);

	$w->get_ok("$url/login");
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
	$w->get_ok("$url/logged-in");
	$w->content_is(0);

	$w->back;
	$w->get_ok("$url/login");
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
	$w->content_like( qr{<a href="$cookbook_url">$cookbook_text</a>},
		'download link' );

	$w->get_ok("$url/logged-in");
	$w->content_is(1);

	#diag($w->content);
};

subtest 'name' => sub {
	plan tests => 5;

	$w->get_ok('/account');
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
	$w->get_ok('/account');
	my $form2 = $w->form_name('user');

	#diag($form2->value('name'));
	is( $form2->value('name'), $NAMES[0], 'name displayed' );

	#diag(explain($form));
};

# when a user sets his password consider that user to have been verified (after all he got the code)
# even he did not click on the verify link.

# after verifying the e-mail allow the user to set his her password
# after logging in
#   Allow user to mark "unregistered" from the Perl Maven newsletter (but keep e-mail, passsword)
#   If registered to the mailing list, let the person download the latest edition of the cookbook

# login
# reset password (send code, allow typing in a password 6+ characters)
# After reseting the password and after verifying the e-mail address the user should be already logged in
#
# Allow admin to send e-mail to all the subscribers
#
# Allow user to buy another item
# A hisory of purchases

