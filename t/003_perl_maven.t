use strict;
use warnings;

use t::lib::Test qw(start read_file);

use Cwd qw(abs_path);
use File::Basename qw(basename);
use Data::Dumper qw(Dumper);
#use JSON qw(from_json);

my $run = start();

eval "use Test::More";
eval "use Test::Deep";
require Test::WWW::Mechanize;
plan( skip_all => 'Unsupported OS' ) if not $run;

my $url = "http://localhost:$ENV{PERL_MAVEN_PORT}";
my $URL = "$url/";

#diag($url);
#sleep 30;
plan( tests => 20 );

my $w = Test::WWW::Mechanize->new;

{
	$w->get_ok("$url/login");
	$w->content_like(qr/Login/);
	$w->submit_form_ok( {
		form_name => 'send_reset_pw',
		fields => {
			email => 'szabgab@gmail.com', # from t/data.yml
		},
	}, 'ask to reset password');

	my $mail = read_file($ENV{PERL_MAVEN_MAIL});
	unlink $ENV{PERL_MAVEN_MAIL};
	#diag $mail;
	my $mail_regex = qr{<a href="(http://localhost:$ENV{PERL_MAVEN_PORT}/set-password/1/(\w+))">set new password</a>};
	my ($set_url) = $mail =~ $mail_regex;
	ok($set_url, 'mail with set url address');
	diag($set_url);
}

diag('subscribe to free Perl Maven newsletter, let them download the cookbook');
# TODO test the various cases of no or bad e-mail addresses and also duplicate registration (and different case).
# TODO do this both on the main page and on the /perl-maven-cookbook page
{
	$w->get_ok($URL);
	$w->content_like(qr/Perl Maven/);
	$w->submit_form_ok( {
		form_name => 'registration_form',
		fields => {
			email => 'gabor@szabgab.com',
		},
	}, 'register form');
	my $mail = read_file($ENV{PERL_MAVEN_MAIL});
	unlink $ENV{PERL_MAVEN_MAIL};
	#diag($mail);
	my $mail_regex = qr{<a href="(http://localhost:$ENV{PERL_MAVEN_PORT}/verify/2/\w+)">verify</a>};
	my ($set_url) = $mail =~ $mail_regex;
	ok($set_url, 'mail with set url address');
	diag($set_url);

	$w->get_ok("http://localhost:$ENV{PERL_MAVEN_PORT}/verify/20/1234567");
	$w->content_like(qr{User not found}, 'no such user');

	$w->get_ok("http://localhost:$ENV{PERL_MAVEN_PORT}/verify/2/1234567");
	$w->content_like(qr{Invalid or missing code}, 'incorrect code');
	#diag($w->content);

	my $cookbook_url = '/download/perl_maven_cookbook/perl_maven_cookbook_v0.01.pdf';
	my $cookbook_text = basename $cookbook_url;
	$w->get_ok($set_url);
	$w->content_like(qr{<a href="$cookbook_url">$cookbook_text</a>}, 'download link');

	# check e-mails
	my $mail2 = read_file($ENV{PERL_MAVEN_MAIL});
	unlink $ENV{PERL_MAVEN_MAIL};
	#diag($mail2);

	like($mail2, qr{Thank you for registering}, 'thank you mail');
	like($mail2, qr{gabor\@szabgab.com has registered}, 'self reporting');

	# hit it again
	$w->get_ok($set_url);
	ok( !-e $ENV{PERL_MAVEN_MAIL}. 'no mails were sent' );
	#diag($w->content);

	$w->follow_link_ok({
		text => $cookbook_text,
	}, 'download_pdf');

	my $src_pdf = read_file("../articles$cookbook_url");
	ok($w->content eq $src_pdf, 'pdf downloaded');
	#open my $t, '>', 'a.pdf' or die;
	#print $out $w->content;
	#diag($w->content);
}


# login
# reset password (send code, allow typing in a password 6+ characters)
# After reseting the password and after verifying the e-mail address the user should be already logged in
# Allow user to mark "unregistered" from the Perl Maven newsletter (but keep e-mail, passsword)
#
# Allow admin to send e-mail to all the subscribers
#
# Allow user to buy another item
# A hisory of purchases

