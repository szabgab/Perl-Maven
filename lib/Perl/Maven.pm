package Perl::Maven;
use Dancer ':syntax';
use Perl::Maven::DB;

our $VERSION = '0.1';
my $TIMEOUT = 60*60*24*365;
my $FROM = 'Gabor Szabo <gabor@szabgab.com>';

use Business::PayPal;
use Data::Dumper qw(Dumper);
use DateTime;
use Digest::SHA;
use Email::Valid;
#use YAML qw(DumpFile LoadFile);
use MIME::Lite;
use File::Basename qw(fileparse);
use POSIX ();

use Perl::Maven::Page;

my $sandbox = 0;

my $sandbox_url = 'https://www.sandbox.paypal.com/cgi-bin/webscr';
my %products;
if (not config->{appdir}) {
	require Cwd;
	set appdir => Cwd::cwd;
}

my $db = Perl::Maven::DB->new( config->{appdir} . "/pm.db" );
my %authors;

hook before => sub {
	read_authors();
	my $p = $db->get_products;
	#debug Dumper $p;
	%products = %$p;
};

hook before_template => sub {
	my $t = shift;
	$t->{title} ||= 'Perl 5 Maven - for people who want to get the most out of programming in Perl';
	if (logged_in()) {
		($t->{username}) = split /@/, session 'email';
	}
	return;
};

get '/' => sub {
	_display('index', 'main', 'index');
};
get '/archive' => sub {
	_display('archive', 'archive', 'system');
};
get '/atom' => sub {
	my $pages;
	my $file = 'feed';
	if (open my $fh, '<', path(config->{articles}, 'meta', "$file.json")) {
		local $/ = undef;
		my $json = <$fh>;
		$pages = from_json $json;
	}

	my $ts = DateTime->now;

	my $url = 'http://perl5maven.com';
	my $xml = '';
	$xml .= qq{<?xml version="1.0" encoding="utf-8"?>\n};
	$xml .= qq{<feed xmlns="http://www.w3.org/2005/Atom">\n};
	$xml .= qq{<link href="$url/atom" rel="self" />\n};
	$xml .= qq{<title>Perl 5 Maven</title>\n};
	$xml .= qq{<id>$url/</id>\n};
	$xml .= qq{<updated>${ts}Z</updated>\n};
	foreach my $p (@$pages) {
		$xml .= qq{<entry>\n};
		$xml .= qq{  <title>$p->{title}</title>\n};
		$xml .= qq{  <summary type="html"><![CDATA[$p->{abstract}]]></summary>\n};
		$xml .= qq{  <updated>$p->{timestamp}Z</updated>\n};
		$xml .= qq{  <link rel="alternate" type="text/html" href="$url/$p->{filename}" />};
		my $id = $p->{id} ? $p->{id} : "$url/$p->{filename}";
		$xml .= qq{  <id>$id</id>\n};
		$xml .= qq{  <content type="html"><![CDATA[$p->{abstract}]]></content>\n};
		if ($p->{author}) {
			$xml .= qq{    <author>\n};
			$xml .= qq{      <name>$authors{$p->{author}}{author_name}</name>\n};
			#$xml .= qq{      <email></email>\n};
			$xml .= qq{    </author>\n};
		}
		$xml .= qq{</entry>\n};
	}
	$xml .= qq{</feed>\n};

	content_type 'application/atom+xml';
	return $xml;
};

sub _display {
	my ($file, $template, $layout) = @_;

	my $tt;
	if (open my $fh, '<', path(config->{articles}, 'meta', "$file.json")) {
		local $/ = undef;
		my $json = <$fh>;
		$tt->{pages} = from_json $json;
	}
	template $template, $tt, { layout => $layout };
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
	}, {
		layout => 'email',
	};

	sendmail(
		From    => $FROM,
		To      => $email,
		Subject => 'Code to reset your Perl 5 Maven password',
		html    => $html,
	);


	template 'error', {
		reset_password_sent => 1,
	};
};

get '/set-password/:id/:code' => sub {
	my $error = pw_form();
	return $error if $error;
	template 'set_password', {
		id   => param('id'),
		code => param('code'),
	};
};

post '/set-password' => sub {
	my $error = pw_form();
	return $error if $error;

	my $password = param('password');
	my $id = param('id');
	my $user = $db->get_user_by_id($id);

	return template 'error', {
		bad_password => 1,
	} if not $password or length($password) < 6;

	session email => $user->{email};
	session logged_in => 1;
	session last_seen => time;

	$db->set_password($id, Digest::SHA::sha1_base64($password));

	template 'error', { password_set => 1 };
};

get '/login' => sub {
	template 'login';
};

post '/login' => sub {
	my $email    = param('email');
	my $password = param('password');

	return template 'error', {
		missing_data => 1,
	} if not $password or not $email;

	my $user = $db->get_user_by_email($email);
	if (not $user->{password}) {
		return template 'login', { no_password => 1 };
	}

	return template 'error', { invalid_pw => 1 }
		if $user->{password} ne Digest::SHA::sha1_base64($password);

	session email => $user->{email};
	session logged_in => 1;
	session last_seen => time;

	redirect '/account';
};

get '/unsubscribe' => sub {
	return redirect '/login' if not logged_in();

	my $email = session('email');

	$db->unsubscribe_from($email, 'perl_maven_cookbook');
	template 'error', { unsubscribed => 1 }
};

get '/subscribe' => sub {
	return redirect '/login' if not logged_in();

	my $email = session('email');
	$db->subscribe_to($email, 'perl_maven_cookbook');
	template 'error', { subscribed => 1 }
};


get '/logged-in' => sub {
	return logged_in() ? 1 : 0;
};

get '/register' => sub {
		return template 'registration_form', {
			standalone => 1,
		};
};

post '/register' => sub {
	my $email = param('email');
	if (not $email) {
		return template 'registration_form', {
			no_mail => 1,
			standalone => 1,
		};
	}
	if (not Email::Valid->address($email)) {
		return template 'registration_form', {
			invalid_mail => 1,
			standalone => 1,
		};
	}

	# check for uniqueness after lc
	$email = lc $email;

	my $user = $db->get_user_by_email($email);
	#debug Dumper $user;
	if ($user and $user->{verify_time}) {
		return template 'registration_form', {
			duplicate_mail => 1,
			standalone => 1,
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
	}, {
		layout => 'email',
	};
	sendmail(
		From    => $FROM,
		To      => $email,
		Subject => 'Please finish the Perl 5 Maven registration',
		html    => $html,
	);
	return template 'response';
};

get '/logout' => sub {
	session logged_in => 0;
	redirect '/';
};

get '/account' => sub {
	return redirect '/login' if not logged_in();

	my $email = session('email');
	my @subscriptions = $db->get_subscriptions($email);
	my @owned_products;
	foreach my $code (@subscriptions) {
		my $file = get_download_file($code);
		#debug "$code -  $file";
		push @owned_products, {
			name     => $products{$code}{name},
			filename => "/download/$code/$file",
			linkname => $file,
		};
	}

	template 'account', {
		subscriptions => \@owned_products,
		subscribed => $db->is_subscribed($email, 'perl_maven_cookbook'),
	};
};

get '/download/:dir/:file' => sub {
	my $dir  = param('dir');
	my $file = param('file');

	# TODO better error reporting or handling when not logged in
	return redirect '/'
		if not logged_in();
	return redirect '/' if not $products{$dir}; # no such product

	# check if the user is really subscribed to the newsletter?
	return redirect '/' if not $db->is_subscribed(session('email'), $dir);

	send_file(path(config->{articles}, 'download', $dir, $file), system_path => 1);
};

get '/verify/:id/:code' => sub {
	my $id = param('id');
	my $code = param('code');

	my $user = $db->get_user_by_id($id);

	if (not $user) {
		return template 'error', { invalid_uid => 1 };
	}

	if (not $user->{verify_code} or not $code or $user->{verify_code} ne $code) {
		return template 'error', { invalid_code => 1 };
	}

	if ($user->{verify_time}) {
		my $cookbook = get_download_file('perl_maven_cookbook');

		return template 'thank_you', {
			filename => "/download/perl_maven_cookbook/$cookbook",
			linkname => $cookbook,
		};
	}

	if (not $db->verify_registration($id, $code)) {
		return template 'verify_form', {
			error => 1,
		};
	}

	$db->subscribe_to($user->{email}, 'perl_maven_cookbook');

	session email => $user->{email};
	session logged_in => 1;
	session last_seen => time;

	sendmail(
		From    => $FROM,
		To      => $user->{email},
		Subject => 'Thank you for registering',
		html    => template('post_verification_mail', {
			url => uri_for('/account'),
		}, { layout => 'email', }),
#		attachments => ['/home/gabor/save/perl_maven_cookbook_v0.01.pdf'],
	);

	sendmail(
		From    => 'Perl 5 Maven <gabor@perl5maven.com>',
		To      => 'Gabor Szabo <gabor@szabgab.com>',
		Subject => 'New Perl 5 Maven newsletter registration',
		html    => "$user->{email} has registered",
	);

	my $cookbook = get_download_file('perl_maven_cookbook');

	template 'thank_you', {
		filename => "/download/perl_maven_cookbook/$cookbook",
		linkname => $cookbook,
	};
};

get '/buy' => sub {
	if (not logged_in()) {
		return template 'error', {please_log_in => 1};
		# TODO redirect back the user once logged in!!!
	}
	my $what = param('product');
	if (not $what) {
		return template 'error', {'no_product_specified' => 1};
	}
	if (not $products{$what}) {
		return template 'error', {'invalid_product_specified' => 1};
	}
	return template 'buy', {
		%{ $products{$what} },
		button => paypal_buy($what, 1),
	};
};
get '/canceled' => sub {
	#debug 'get canceled ' . Dumper params();
	return template 'error', { canceled => 1};
	return 'canceled';
};
any '/paid'  => sub {
	#debug 'paid ' . Dumper params();
	return template 'thank_you_buy';
};
any '/paypal'  => sub {
	my %query = params();
	#debug 'paypal ' . Dumper \%query;
	my $id = param('custom');
	my $paypal = paypal( id => $id );

	my ($txnstatus, $reason) = $paypal->ipnvalidate(\%query);
	if (not $txnstatus) {
		log_paypal("IPN-no $reason", \%query);
		return 'ipn-transaction-failed';
	}

	my $paypal_data = from_yaml $db->get_transaction($id);
	if (not $paypal_data) {
		log_paypal('IPN-unrecognized-id', \%query);
		return 'ipn-transaction-invalid';
	}
	my $payment_status = $query{payment_status} || '';
	if ($payment_status eq 'Completed' or $payment_status eq 'Pending') {
		my $email = $paypal_data->{email};
		#debug "subscribe '$email' to '$paypal_data->{what}'" . Dumper $paypal_data;
		$db->subscribe_to($email, $paypal_data->{what});
		log_paypal('IPN-ok', \%query);
		return 'ipn-ok';
	}

	log_paypal('IPN-failed', \%query);
	return 'ipn-failed';
};

	# Start by requireing the user to be loged in first

	# Plan:
	# If user logged in, add purchase information to his account

	# If user is not logged in
	#  If the e-mail supplied by Paypal is in our database already
	#     assume they are the same user and add the purchase to that account
	#     and even log the user in (how?)
	# If the e-mail exists but not yet verified in the system ????

	# If this is a new e-mail, save the data as a new user and
	# at the end of the transaction ask the user if he already
	# has an account or if a new one should be created?
	# If he wants to use the existing account, ask for credentials,
	# after successful login merge the two accounts

	# last_name
	# first_name
	# payer_email

get '/img/:file' => sub {
	my $file = param('file');
	return if $file !~ /^[\w-]+\.(\w+)$/;
	my $ext = $1;
#	return config->{articles} . "img/$file";
	send_file(
		config->{articles} . "/img/$file",
#		"d:\\work\\articles\\img\\$file",
		content_type => $ext,
		system_path => 1,
	);
};

get '/mail/:article' => sub {

	my $article = param('article');

	my $path = config->{articles} . "/mail/$article.tt";
	return 'NO path' if not -e $path;

	my $tt = read_tt($path);
	return template 'error', {'no_such_article' => 1}
		if not $tt->{status} or $tt->{status} ne 'show';

	return template 'mail', $tt, {	layout => 'newsletter' };
};

get qr{/(.+)} => sub {
	my ($article) = splat;


	my $path = config->{articles} . "/$article.tt";
	return template 'error', {'no_such_article' => 1} if not -e $path;

	my $tt = read_tt($path);
	return template 'error', {'no_such_article' => 1}
		if not $tt->{status} or $tt->{status} ne 'show';
	($tt->{date}) = split /T/, $tt->{timestamp};

	my $nick = $tt->{author};
	if ($nick and $authors{$nick}) {
		$tt->{author_name} = $authors{$nick}{author_name};
		$tt->{author_img} = $authors{$nick}{author_img};
		$tt->{google_plus_profile} = $authors{$nick}{google_plus_profile};
	} else {
		delete $tt->{author};
	}

	return template 'page', $tt, { layout => 'page' };
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
		or not $user->{password_reset_timeout};
	return template 'error', {old_password_code => 1}
		if $user->{password_reset_timeout} < time;

	return;
}

sub paypal_buy {
	my ($what, $quantity) = @_;

	my $item = $products{$what}{name};
	my $usd  = $products{$what}{price};

	my $paypal = paypal();

	# uri_for returns an URI::http object but because Business::PayPal is using CGI.pm
	# and the hidden() method of CGI.pm checks if this is a reference and then blows up.
	# so we have to forcibly stringify these values. At least for now in Business::PayPal 0.04
	my $cancel_url = uri_for('/canceled');
	my $return_url = uri_for('/paid');
	my $notify_url = uri_for('/paypal');
	my $button = $paypal->button(
		business       => 'gabor@szabgab.com',
		item_name      => $item,
		amount         => $usd,
		quantity       => $quantity,
		return         => "$return_url",
		cancel_return  => "$cancel_url",
		notify_url     => "$notify_url",
	);
	my $id = $paypal->id;
	#debug $button;

	my $paypal_data = session('paypal') || {};

	my $email = logged_in() ? session('email') : '';
	my %data = (what => $what, quantity => $quantity, usd => $usd, email => $email );
	$paypal_data->{$id} = \%data;
	session paypal => $paypal_data;
	$db->save_transaction($id, to_yaml \%data);

	log_paypal('buy_button', {id => $id, %data});

	return $button;
}

sub log_paypal {
	my ($action, $data) = @_;

	my $ts = time;
	my $logfile = config->{appdir} . '/logs/paypal_' . POSIX::strftime("%Y%m%d", gmtime($ts));
	#debug $logfile;
	if (open my $out, '>>', $logfile) {
		print $out POSIX::strftime("%Y-%m-%d", gmtime($ts)), " - $action\n";
		print $out Dumper $data;
		close $out;
	}
	return;
}


sub read_tt {
	my $file = shift;

	return Perl::Maven::Page->new(file => $file)->read;
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
	if ($ENV{PERL_MAVEN_MAIL}) {
		if (open my $out, '>>', $ENV{PERL_MAVEN_MAIL}) {
			print $out $mail->as_string;
		} else {
			error "Could not open $ENV{PERL_MAVEN_MAIL} $!";
		}
		return;
	}

	$mail->send;
	return;
}

sub logged_in {
	if (session('logged_in') and session('email') and session('last_seen') > time - $TIMEOUT) {
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

sub get_download_file {
	my ($subdir) = @_;

	my $dir = path config->{articles}, 'download', $subdir;
	#debug $dir;
	my $file;
	if (opendir my $dh, $dir) {
		($file) = sort grep {$_ !~ /^\./} readdir $dh;
	} else {
		error "$dir : $!";
	}
	return $file;
}

sub read_authors {
	return if %authors;

	open my $fh, '<', config->{appdir} . "/authors.txt" or return;
	while (my $line = <$fh>) {
		chomp $line;
		my ($nick, $name, $img, $google_plus_profile) = split /;/, $line;
		$authors{$nick} = {
			author_name => $name,
			author_img  => $img,
			google_plus_profile => $google_plus_profile,
		};
	}
	return;
}

sub paypal {
	my @params = @_;

	if ($sandbox) {
		push @params, address => $sandbox_url;
	}
	Business::PayPal->new(@params);
}

true;

