package Perl::Maven;
use Dancer ':syntax';
use Perl::Maven::DB;

our $VERSION = '0.1';
my $TIMEOUT = 100;
my $FROM = 'Gabor Szabo <gabor@szabgab.com>';

use Business::PayPal;
use Data::Dumper qw(Dumper);
use Email::Valid;
use YAML qw(DumpFile LoadFile);
use MIME::Lite;
use File::Basename qw(fileparse);

my $db = Perl::Maven::DB->new( config->{appdir} . "/pm.db" );

hook before_template => sub {
	my $t = shift;
	$t->{title} ||= 'Perl Maven - for people who want to get the most out of programming in Perl';
	if (logged_in()) {
		($t->{username}) = split /@/, session 'email';
	}
	return;
};

get '/' => sub {
	my $tt;
	$tt->{registration_form} = read_file(config->{appdir} . "/views/registration_form.tt");
	template 'main', $tt;
};

post '/send-reset-pw-code' => sub {
	my $email = param('email');
	if (not $email) {
		return template 'error', { no_email => 1 };
	}
	$email = lc $email;
	my $user = $db->get_user_by_email($email);
	if (not $user) {
		return template 'error', {invalid_email => 1};
	}
	if (not $user->{verify_time}) {
		# TODO: send e-mail with verification code
		return template 'error', {not_verified_yet => 1};
	}

	my $code = _generate_code();
	$db->set_password_code($user->{email}, $code);

	my $html = template 'reset_password_mail', {
		url => uri_for('/set-password'),
		id => $user->{id},
		code => $code,
	};

	sendmail(
		From    => $FROM,
		To      => $email,
		Subject => 'Code to reset your Perl Maven password',
		html    => $html,
	);


	template 'error', {
		reset_password_sent => 1,
	};
};

get '/set-password/:id/:code' => sub {
	my $error = pw_form();
	return $error if $error;
	template 'set_password';
};

post '/set-password' => sub {
	my $error = pw_form();
	return $error if $error;

	my $password = param('password');
};

get '/login' => sub {
	template 'login';
};

post '/login' => sub {
	my $email    = param('email');
	my $password = param('password');

	my $user = $db->get_user_by_email($email);
	if (not $user->{password}) {
		return template 'login', { no_password => 1 };
	}
	return "TODO";
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

	my $user = $db->get_user_by_email($email);
	#debug Dumper $user;
	if ($user and $user->{verify_time}) {
		return template 'main', {
			duplicate_mail => 1,
		};
	}

	my $code = _generate_code();

	# basically resend the old code
	my $id;
	if ($user) {
		$code = $user->{verify_code};
		$id = $user->{id};
	} else {
		$id = $db->add_registration($email, $code);
	}

	# save  email and code (and date)
	my $html = template 'verification_mail', {
		url => uri_for('/verify'),
		id => $id,
		code => $code,
	};
	sendmail(
		From    => $FROM,
		To      => $email,
		Subject => 'Please finish the Perl Maven registration',
		html    => $html,
	);
	return template 'response';
};

get '/logout' => sub {
	session logged_in => 0;
	redirect '/';
};

get '/download/:dir/:file' => sub {
	my $dir  = param('dir');
	my $file = param('file');

	return redirect '/'
		if not logged_in();
	return redirect '/' if $dir ne 'perl_maven_cookbok';
	# check if the user is really subscribed to the newsletter?

	send_file path config->{appdir}, '..', 'download', $dir, $file;
};

get '/verify/:id/:code' => sub {
	my $id = param('id');
	my $code = param('code');

	my $user = $db->get_user_by_id($id);

	if (not $db->verify_registration($id, $code)) {
		return template 'verify_form', {
			error => 1,
		};
	}

	session email => $user->{email};
	session logged_in => 1;
	session last_seen => time;

	sendmail(
		From    => $FROM,
		To      => $user->{email},
		Subject => 'Thank you for registering',
		html    => template('post_verification_mail'),
#		attachments => ['/home/gabor/save/perl_maven_cookbook_v0.01.pdf'],
	);

	sendmail(
		From    => 'Perl Maven <gabor@perlmaven.com>',
		To      => 'Gabor Szabo <gabor@szabgab.com>',
		Subject => 'New Perl Maven newsletter registration',
		html    => "$user->{email} has registered",
	);

	my $dir = path config->{appdir}, '..', 'download', 'perl_maven_cookbook';
	#debug $dir;
	my $file;
	if (opendir my $dh, $dir) {
		($file) = sort grep {$_ !~ /^\./} readdir $dh;
	} else {
		error $!;
	}
	template 'thank_you', {
		filename => "/download/perl_maven_cookbook/$file",
		linkname => $file,
	};
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
#		"d:\\work\\articles\\img\\$file",
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

##########################################################################################

sub pw_form {
	my $id = param('id');
	my $code = param('code');
	# if there is such userid with such code and it has not expired yet
	# then show a form
	return template 'error', {missing_data => 1}
		if not $id or not $code;

	my $user = $db->get_user_by_id($id);
	return template 'error', {invalid_uid => 1}
		if not $user;
	return template 'error', {invalid_code => 1}
		if not $user->{password_reset_code} or
		$user->{password_reset_code} ne $code
		or not $user->{password_reset_timeout}
		or $user->{password_reset_timeout} < time;

	return;
}

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


sub read_file {
	my $file = shift;
	open my $fh, '<', $file or return '';
	local $/ = undef;
	return scalar <$fh>;
}



sub sendmail {
	my %args = @_;

	my $html  = delete $args{html};
	# TODO convert to text and add that too

	my $attachments = delete $args{attachments};

	my $mail = MIME::Lite->new(
		%args,
		Type    => 'multipart/mixed',
	);
	$mail->attach(
		Type => 'text/html',
		Data => $html,
	);
	foreach my $file (@$attachments) {
		my ($basename, $dir, $ext) = fileparse($file);
		$mail->attach(
			Type => "application/$ext",
			Path => $file,
			Filename => $basename,
			Disposition => 'attachment',
		);
	}
	if ($ENV{NOMAIL}) {
		debug $mail->as_string;
		return;
	}

	$mail->send;
	return;
}

sub logged_in {
	if (session('logged_in') and session('last_seen') > time - $TIMEOUT) {
		session last_seen => time;
		return 1;
	}
	return;
}

sub _generate_code {
	my @chars = ('a' .. 'z', 'A' .. 'Z', 0 .. 9);
	my $code = '';
	$code .= $chars[ rand(scalar @chars) ] for 1..20;
	return $code;
}

true;

