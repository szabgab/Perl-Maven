use strict;
use warnings;

use t::lib::Test qw(start read_file);

use Cwd qw(abs_path);
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
plan( tests => 6 );

my $w = Test::WWW::Mechanize->new;
$w->get_ok($URL);
$w->content_like(qr/Perl Maven/);

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
	#diag $mail;
	my $mail_regex = qr{<a href="(http://localhost:$ENV{PERL_MAVEN_PORT}/set-password/1/(\w+))">set new password</a>};
	like($mail, $mail_regex, 'mail');
	my ($set_url) = $mail =~ $mail_regex;
	diag($set_url);
}


# subscribe to free Perl Maven newsletter, let them download the cookbook
# login
# reset password (send code, allow typing in a password 6+ characters)
# After reseting the password and after verifying the e-mail address the user should be already logged in
# Allow user to mark "unregistered" from the Perl Maven newsletter (but keep e-mail, passsword)
#
# Allow admin to send e-mail to all the subscribers
#
# Allow user to buy another item
# A hisory of purchases

