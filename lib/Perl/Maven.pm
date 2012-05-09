package Perl::Maven;
use Dancer ':syntax';

our $VERSION = '0.1';

use Business::PayPal;
use Data::Dumper qw(Dumper);
use Email::Valid;
use MIME::Lite;
use YAML qw(DumpFile LoadFile);

hook before_template => sub {
    my $t = shift;
    $t->{title} ||= 'Perl Maven - for people who want to get the most out of programming in Perl';
	return;
};

get '/' => sub {
	my $tt;
	$tt->{registration_form} = read_file(config->{appdir} . "/views/registration_form.tt");
    template 'main', $tt;
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
	if ($data->{$email} and $data->{$email}{verified}) {
		return template 'main', {
			duplicate_mail => 1,
		};
	}

	# generate code
	my @chars = ('a' .. 'z', 'A' .. 'Z', 0 .. 9);
	my $code = '';
	$code .= $chars[ rand(scalar @chars) ] for 1..20;

	# basically resend the old code
	if ($data->{$email}) {
		$code = $data->{$email}{code};
	} else {
		add_registration($email, $code);
	}

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
		Subject => 'Please finish the Perl Maven registration',
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

	my $selfmail = MIME::Lite->new(
		From    => 'Perl Maven registration <gabor@perlmaven.com>',
		To      => 'Gabor Szabo <gabor@szabgab.com>',
		Subject => 'New Perl Maven newsletter registration',
		Data    => "New registration from $email",
	);
	$selfmail->send;

	template 'thank_you';
};

get '/buy' => sub {
	return paypal();
};
get '/canceled' => sub {
	debug Dumper params();
	return 'canceled';
};
get '/paid'  => sub {
	debug Dumper params();
	return 'paid';
};
get '/paypal_notify'  => sub {
	debug Dumper params();
	return 'paypal_notify';
};

get '/img/:file' => sub {
    my $file = param('file');
	return if $file !~ /^[\w-]+\.(\w+)$/;
	my $ext = $1;
#	return config->{appdir} . "/../articles/img/$file";
    send_file(
	  config->{appdir} . "/../articles/img/$file",
#	  "d:\\work\\articles\\img\\$file",
	  content_type => $ext,
	  system_path => 1,
	);
};

get qr{/(.+)} => sub {
	my ($article) = splat;

	my $path = config->{appdir} . "/../articles/$article.tt";
	return template 'error', {'no_such_article' => 1} if not -e $path;

	my $tt = read_tt($path);
	return template 'error', {'no_such_article' => 1}
		if not $tt->{status} or $tt->{status} ne 'show';

	my $registration_form = read_file(config->{appdir} . "/views/registration_form.tt");
	$tt->{mycontent} =~ s/<%\s+registration_form\s+%>/$registration_form/g;
    $tt->{title} = $tt->{head1};

	return template 'page' => $tt;
};

##############  pseudo database handling code

sub paypal {

	my $sandbox = 'https://www.sandbox.paypal.com/cgi-bin/webscr';
#	my $paypal = Business::PayPal->new(address => $sandbox);
	my $paypal = Business::PayPal->new();

	# uri_for returns an URI::http object but because Business::PayPal is using CGI.pm
	# and the hidden() method of CGI.pm checks if this is a reference and then blows up.
	# so we have to forcibly stringify these values. At least for now in Business::PayPal 0.04
	my $cancel_url = uri_for('/canceled');
	my $return_url = uri_for('/paid');
	my $notify_url = uri_for('/paypal_notify');
	my $button = $paypal->button(
    	business => 'gabor@szabgab.com',
		item_name => 'Donation',
		return        => "$return_url",
		cancel_return => "$cancel_url",
		amount => '0.01',
		quantity => 1,
		notify_url => "$notify_url",
	);
	my $id = $paypal->id;

	my $paypal_data = session('paypal') || {};
	$paypal_data->{$id} = { item => 'Donation' };
	session paypal => $paypal_data;
	#debug Dumper $button;

	return $button;
}




sub read_tt {
	my $file = shift;
	my %data = (content => '', abstract => '');
	my $cont = '';
	my $in_code;
	if (open my $fh, '<', $file) {
		while (my $line = <$fh>) {
			if ($line =~ /^=abstract start/ .. $line =~ /^=abstract end/) {
				next if $line =~ /^=abstract/;
				$data{abstract} .= $line;
			}
			if ($line =~ /^=(\w+)\s+(.*?)\s*$/) {
				$data{$1} = $2;
				next;
			}
			if ($line =~ m{^<code lang="([^"]+)">}) {
				$in_code = $1;
				$cont .= qq{<pre>\n};
				next;
			}
			if ($line =~ m{^</code>}) {
				$in_code = undef;
				$cont .= qq{</pre>\n};
				next;
			}
			if ($in_code) {
				$line =~ s{<}{&lt;}g;
				$cont .= $line;
				next;
			}

			if ($line =~ /^\s*$/) {
				$cont .= "<p>\n";
			}
			$cont .= $line;
		}
	}
	$data{mycontent} = $cont;
	return \%data;
}

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

sub read_file {
	my $file = shift;
	open my $fh, '<', $file or return '';
	local $/ = undef;
	return scalar <$fh>;
}

true;

