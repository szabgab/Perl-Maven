package Perl::Maven;
use Dancer ':syntax';

our $VERSION = '0.1';
use Email::Valid;
use MIME::Lite;
use YAML qw(DumpFile LoadFile);

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
	
	my $data = get_data();
	if ($data->{$email}) {
		return template 'main', {
			duplicate_mail => 1,
		};
	}

	# generate code
	my @chars = ('a' .. 'z', 'A' .. 'Z', 0 .. 9);
	my $code = '';
	$code .= $chars[ rand(scalar @chars) ] for 1..10;
	
	add_registration($email, $code);

	# save  email and code (and date)
	my $html = template 'verification_mail', {
		url => uri_for('/verify'),
		email => $email,
		code => $code,
	};
	# send e-mail
	my $mail = MIME::Lite->new(
		From    => 'Gabor Szabo <gabor@szabgab.com>',
		To      => $email,
		Subject => 'Finish the Registration',
		Type    => 'multipart/mixed',
	);
	$mail->attach(
		Type => 'text/html',
		Data => $html,
	);
	$mail->send;
	return template 'response';
};

get '/verify' => sub {
	my $email = param('email');
	my $code = param('code');

	if (not verify_registration($email, $code)) {
		return template 'verify_form', {
			error => 1,
		};
	}

	my $html = template 'post_verification_mail';

	my $mail = MIME::Lite->new(
		From    => 'Gabor Szabo <gabor@szabgab.com>',
		To      => $email,
		Subject => 'Thank you for registering',
		Type    => 'multipart/mixed',
	);
	$mail->attach(
		Type => 'text/html',
		Data => $html,
	);

	use File::Basename qw(basename);
	my $file = '/home/gabor/save/perl_maven_cookbook_v0.01.pdf';
	$mail->attach(
		Type => 'application/pdf',
		Path => $file,
		Filename => basename($file),
		Disposition => 'attachment',
    );
	$mail->send;
	
	
	template 'thank_you';
};


##############  pseudo database handling code

sub _file {
	path config->{appdir}, 'data.yml';
}

sub get_data {
	my $file = _file();
	if (not -e $file) {
		DumpFile($file, {});
	}

	LoadFile $file;
}
sub _save {
	my ($code) = @_;
	
	use Fcntl qw(:flock);
	my $file = _file();
	if (open my $fh, '<', $file) {
		flock $fh, LOCK_EX;
		my $data = LoadFile $file;
		if ($code->($data)) {
			DumpFile($file, $data);
		}
	}
}

sub add_registration {
	my ($email, $code) = @_;
	
	_save(sub {
		my $data = shift;
		if (not $data->{$email}) {
			$data->{$email} = {code => $code, register => time};
			return 1;
		}
		return;
	});
}

sub verify_registration {
	my ($email, $code) = @_;

	_save(sub {
		my $data = shift;
		if ($data->{$email} and $data->{$email}{code} eq $code) {
			if (not $data->{$email}{verified}) {
				$data->{$email}{verified} = time;
				return 1;
			}
		}
		return;
	});
	
}



true;

