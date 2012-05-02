package Perl::Maven;
use Dancer ':syntax';

our $VERSION = '0.1';
use Email::Valid;
use MIME::Lite;

get '/' => sub {
    template 'main';
};

post '/register' => sub {
	my $email = param('email');
	if (not $email) {
		return template 'main', {
			no_mail => 1,
		};
	}
	if (not Email::Valid->address($email)) {
		return template 'main', {
			invalid_mail => 1,
		};
	}

	# check for uniqueness after lc
	$email = lc $email;

	# generate code
	my @chars = ('a' .. 'z', 'A' .. 'Z', 0 .. 9);
	my $code = '';
	$code .= $chars[ rand(scalar @chars) ] for 1..10;

	# save  email and code (and date)
	my $html = template 'verification_mail', {
		url => uri_for('/verify'),
		code => $code,
	};
	# send e-mail
	my $mail = MIME::Lite->new(
		From    => 'gabor@szabgab.com',
		To      => $email,
		Subject => 'Finish the Registration',
		Type    => 'multipart/mixed',
	);
	$mail->attach(
		Type => 'text/html',
		Data => $html,
	);
	$mail->send;
	return template => 'response';
};

get '/verify' => sub {
	my $code = param('code');

};


true;

