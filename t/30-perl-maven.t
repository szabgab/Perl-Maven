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

my $url            = 'http://test-perl-maven.com';
my $EMAIL          = 'gabor@perlmaven.com';
my $EMAIL2         = 'other@perlmaven.com';
my $EMAIL3         = 'zorg@perlmaven.com';
my @PASSWORD       = ( '123456', 'abcdef', 'secret' );
my $sha1_of_abcdef = 'H4rBDyPFtbwRZ72oS4M+XAV6d9I';
my @NAMES          = ( 'Foo Bar', );

plan tests => 7;

$ENV{EMAIL_SENDER_TRANSPORT} = 'Test';

my $cookbook_url  = '/download/perl_maven_cookbook/perl_maven_cookbook_v0.01.txt';
my $cookbook_text = basename $cookbook_url;

my $prod1_download_url = '/download/product_a/file_0.2.txt';
my $prod1_text         = basename $prod1_download_url;

use Dancer qw(:tests);

Dancer::set( appdir => getcwd() );
use Perl::Maven;
use Perl::Maven::DB;
my $db = Perl::Maven::DB->new('pm.db');

my $app = Dancer::Handler->psgi_app;

my $w = Test::WWW::Mechanize::PSGI->new( app => $app );

my $visitor = Test::WWW::Mechanize::PSGI->new( app => $app );

diag 'subscribe to free newsletter, let them download the cookbook';

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

	$visitor->get_ok('/account');
	is $visitor->base, "$url/login", 'redirected to login page';

	# strangely for this post() request I had to supply the full URL or it would go to http://localhost/
	$visitor->post_ok("$url/change-email");
	is $visitor->base, "$url/login", 'redirected to login page';

	#diag $visitor->content;
};

# TODO test the various cases of no or bad e-mail addresses and also duplicate registration (and different case).
# TODO do this both on the main page and on the /perl-maven-cookbook page
subtest 'subscribe' => sub {
	plan tests => 35;
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

	#my $mail = read_file( $ENV{PERL_MAVEN_MAIL} );
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

	#diag $mail;

	#my $mail_regex = qr{<a href="($url/verify/1/\w+)">verify</a>};
	my $mail_regex = qr{verify\s+\[\s+($url/verify/1/\w+)=};
	my ($set_url) = $mail =~ $mail_regex;
	ok $set_url, 'mail with set url address';

	#diag $set_url;
	#diag explain $db->{dbh}->selectall_arrayref('SELECT * FROM user');
	$w->get_ok("$url/verify/20/1234567");
	$w->content_like( qr{User not found}, 'no such user' );

	$w->get_ok("$url/verify/1/1234567");
	$w->content_like( qr{Invalid or missing code}, 'incorrect code' );
	$w->get_ok($set_url);

	#diag $w->content;
	# the new page does not contain a link to the cookbook.
	#$w->content_like( qr{<a href="$cookbook_url">$cookbook_text</a>}, 'download link' );
	$w->get_ok("$url/logged-in");
	$w->content_is(1);

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

	#ok !-e $ENV{PERL_MAVEN_MAIL}, 'no additional mail was sent';

	$w->get_ok("$url/account");
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

	$w->get_ok('/account');
	$w->content_like( qr{<a href="$cookbook_url">$cookbook_text</a>}, 'download link' );
	$w->content_like( qr{<a href="/logout">logout</a>},               'logout link' );
	$w->get_ok('/logout');
	$w->get_ok('/account');
	$w->content_unlike( qr{<a href="$cookbook_url">$cookbook_text</a>}, 'download link' );
	$w->get_ok("$url/logged-in");
	is $w->content, 0;
};

{
	my $id = $db->add_registration( $EMAIL3, '123' );
	$db->set_password( $id, $PASSWORD[2] );
}

# ask the system to send a password reminder, use the link to set the password
# log out and then login again
subtest 'ask for password reset, then login' => sub {

	plan tests => 21;
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

	my @mails = Email::Sender::Simple->default_transport->deliveries;
	my $mail  = $mails[3]{email}->as_string;

	#diag $mail;
	#my $mail_regex
	#	= qr{<a href="($url/set-password/1/(\w+))">set new password</a>};
	my $mail_regex = qr{set new password \[ ($url/set-password/1/(?:\w+))=\s*(\w+) \]};
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
	$w->get_ok("$url/logged-in");
	$w->content_is(1);

	# white-box:
	my $user = $db->get_user_by_email($EMAIL);
	is substr( $user->{password}, 0, 7 ), '{CRYPT}';

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
	$w->content_like( qr{<a href="$cookbook_url">$cookbook_text</a>}, 'download link' );

	#diag $w->content;

	$w->get_ok("$url/logged-in");
	$w->content_is(1);
};

# now change password while logged in,
# log out and check if we fail to log in with
# the old password but we can log in with the new.
subtest 'change password while logged in' => sub {
	plan tests => 20;

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
	$w->content_like( qr{<a href="$cookbook_url">$cookbook_text</a>}, 'download link' );

	$w->get_ok("$url/logged-in");
	$w->content_is(1);

	#diag($w->content);

	my $other_user = $db->get_user_by_id(2);
	is $other_user->{password}, $PASSWORD[2], 'other use still exists with old password';
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

# we inject an old-style password and check if after the first login it is upgraded
subtest 'upgrade_pw' => sub {
	plan tests => 7;

	$w->get_ok('/logout');
	$w->get_ok('/account');
	is $w->base, "$url/login", 'redirected to login page';

	# white-box:
	my $user_before = $db->get_user_by_email($EMAIL);
	$db->set_password( $user_before->{id}, $sha1_of_abcdef );
	my $user_midi = $db->get_user_by_email($EMAIL);
	is $user_midi->{password}, $sha1_of_abcdef, 'just making sure we set the old pw';

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

	# white-box:
	my $user_after = $db->get_user_by_email($EMAIL);
	is substr( $user_after->{password}, 0, 7 ), '{CRYPT}';
};

subtest change_email => sub {
	plan tests => 12;

	$w->get_ok('/account');
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
	#my $mail_regex = qr{<a href="($url/verify2/\w+)">verify</a>};
	my $mail_regex = qr{verify \[ ($url/verify2/\w+)};
	my ($set_url) = $mail =~ $mail_regex;
	ok $set_url, 'mail with set url address';
	diag $set_url;

	$w->get_ok("$url/verify2/1234567");
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

