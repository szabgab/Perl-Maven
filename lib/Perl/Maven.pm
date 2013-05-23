package Perl::Maven;
use Dancer ':syntax';
use Perl::Maven::DB;

our $VERSION = '0.1';
my $TIMEOUT = 60*60*24*365;

use Business::PayPal;
use Cwd qw(cwd abs_path);
use Data::Dumper qw(Dumper);
use DateTime;
use Digest::SHA;
use Email::Valid;
#use YAML qw(DumpFile LoadFile);
use MIME::Lite;
use File::Basename qw(fileparse);
use POSIX ();

use Perl::Maven::Page;
use Perl::Maven::Config;

sub mymaven {
	my $mymaven = Perl::Maven::Config->new(path(config->{appdir}, config->{mymaven}));
	return $mymaven->config(request->host);
};

my $sandbox = 0;

my $sandbox_url = 'https://www.sandbox.paypal.com/cgi-bin/webscr';
my %products;

## configure relative pathes
my $db = Perl::Maven::DB->new( config->{appdir} . "/pm.db" );
my %authors;

hook before => sub {
	my $appdir = abs_path config->{appdir};

	# Create a new Template::Toolkit object for every call because we cannot access the existing object
	# and thus we cannot change the include path before rendering
	my $engines = config->{engines};
	$engines->{template_toolkit}{INCLUDE_PATH} = [mymaven->{site}. '/templates', "$appdir/views"];
	Dancer::Template::TemplateToolkit->new( name => 'template_toolkit', type => 'template' , config => $engines->{template_toolkit});

	read_authors();
	my $p = $db->get_products;
	%products = %$p;
};

hook before_template => sub {
	my $t = shift;
	$t->{title} ||= '';
	if (logged_in()) {
		($t->{username}) = split /@/, session 'email';
	}


	# we assume that the whole complex is written in one leading language
	# and some of the pages are to other languages The domain-site give the name of the
	# default language and this is the same content that is displayed on the site
	# without a hostname: 	# http://domain.com
	my $original_language = mymaven->{domain}{site};
	my $language = mymaven->{lang};
	$t->{"lang_$language"} = 1;
	my $data = read_meta('keywords') || {};
	$t->{keywords} = to_json([sort keys %$data]);
	#$t->{keyword_mapper} = to_json($data) || '{}';

    $t->{conf}                 = mymaven->{conf};
    $t->{resources}            = read_resources();
	$t->{comments}           &&= mymaven->{conf}{enable_comments};

	# linking to translations
	my $sites = read_sites();
	my $translations = read_meta_meta('translations');
	delete $sites->{$language}; # no link to the curren site
	my $path = request->path;
	my %links;
	if ($path ne '/') {
		my $original = $language eq $original_language ? substr($path, 1) : $t->{original};
		if ($original) {
			foreach my $language_code ( keys %{ $translations->{$original} } ) {
				$sites->{$language_code}{url} .= $translations->{$original}{$language_code};
				$links{$language_code} = $sites->{$language_code};
			}
			if ($language ne $original_language) {
				$sites->{$original_language}{url} .= $original;
				$links{$original_language} = $sites->{$original_language};
			}
		}
	} else {
		%links = %$sites;
	}

	my $url = request->uri_base . request->path;
	foreach my $field (qw(reddit_url twitter_data_url twitter_data_counturl google_plus_href facebook_href)) {
		$t->{$field} = $url;
	}

	# on May 1 2013 the site was redirected from perl5maven.com to perlmaven.com
	# we try to salvage some of the social proof.
	if ($t->{date} le '2013-05-01') {
		foreach my $field (qw(reddit_url twitter_data_counturl)) {
			$t->{$field} =~ s/perlmaven.com/perl5maven.com/;
		}
	}

	#my $host = Perl::Maven::Config::host(request->host);
	#$t->{uri_base}  = request->uri_base;
	$t->{languages} = \%links;

	return;
};

# Dynamic robots.txt generation to allow dynamic Sitemap URL
get '/robots.txt' => sub {
	my $host = request->host;
	my $txt = <<"END_TXT";
Sitemap: http://$host/sitemap.xml
Disallow: /media/*
END_TXT

	content_type 'text/plain';
	return $txt;
};

get qr{/(.+)} => sub {
	my ($article) = splat;

	if (mymaven->{redirect}{$article}) {
		return redirect mymaven->{redirect}{$article};
	}
	pass;
};

get '/search' => sub {
	my ($keyword) = param('keyword');
	push_header 'Access-Control-Allow-Origin' => '*';
	return to_json({}) if not defined $keyword;
	my $data = read_meta('keywords') || {};
	$data->{$keyword} ||= {};
	return to_json($data->{$keyword});
};

get '/' => sub {
	if (request->host =~ /^meta\./) {
		return _show({ article => 'index',  template => 'page', layout => 'meta' }, {
			authors => \%authors,
			stats   => read_meta_meta('stats'),
#			pages => (read_meta('index') || []),
		});
	}

	_show({ article => 'index', template => 'page', layout => 'index' }, { pages => (read_meta('index') || []) });
};

get '/keywords' => sub {
	my $kw = read_meta('keywords') || {};
	delete $kw->{keys}; # TODO: temporarily deleted as this break TT http://www.perlmonks.org/?node_id=1022446
	#die Dumper $kw->{__WARN__};
	_show({ article => 'keywords', template => 'page', layout => 'keywords' }, { kw  => $kw });
};

get '/archive' => sub {
	_show({ article => 'archive', template => 'archive', layout => 'system' }, { pages => (read_meta('archive') || []) });
};

get '/sitemap.xml' => sub {
	my $pages = read_meta('sitemap') || [];
	my $url = request->base;
	$url =~ s{/$}{};
	content_type 'application/xml';

	my $xml = qq{<?xml version="1.0" encoding="UTF-8"?>\n};
	$xml .= qq{<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n};
	foreach my $p (@$pages) {
		$xml .= qq{  <url>\n};
      	$xml .= qq{    <loc>$url/$p->{filename}</loc>\n};
		if ($p->{timestamp}) {
      		$xml .= sprintf qq{    <lastmod>%s</lastmod>\n}, substr($p->{timestamp}, 0, 10);
		}
      	#$xml .= qq{    <changefreq>monthly</changefreq>\n};
      	#$xml .= qq{    <priority>0.8</priority>\n};
   		$xml .= qq{  </url>\n};
	}
	$xml .= qq{</urlset>\n};
	return $xml;
};
get '/atom' => sub {
	my $pages = read_meta('feed') || [];
	my $mymaven = mymaven;

	my $ts = DateTime->now;

	my $url = request->base;
	$url =~ s{/$}{};
	my $title = $mymaven->{title};

	my $xml = '';
	$xml .= qq{<?xml version="1.0" encoding="utf-8"?>\n};
	$xml .= qq{<feed xmlns="http://www.w3.org/2005/Atom">\n};
	$xml .= qq{<link href="$url/atom" rel="self" />\n};
	$xml .= qq{<title>$title</title>\n};
	$xml .= qq{<id>$url/</id>\n};
	$xml .= qq{<updated>${ts}Z</updated>\n};
	foreach my $p (@$pages) {
		$xml .= qq{<entry>\n};
		$xml .= qq{  <title>$p->{title}</title>\n};
		$xml .= qq{  <summary type="html"><![CDATA[$p->{abstract}]]></summary>\n};
		$xml .= qq{  <updated>$p->{timestamp}Z</updated>\n};
		$url = $p->{url} ? $p->{url} : $url;
		$xml .= qq{  <link rel="alternate" type="text/html" href="$url/$p->{filename}?utm_campaign=rss" />};
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

	my $mymaven = mymaven;
	sendmail(
		From    => $mymaven->{from},
		To      => $email,
		Subject => "Code to reset your $mymaven->{title} password",
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
			showright => 0,
		};
};

post '/register' => sub {
	my $email = param('email');
	if (not $email) {
		return template 'registration_form', {
			no_mail => 1,
			showright => 0,
		};
	}
	if (not Email::Valid->address($email)) {
		return template 'registration_form', {
			invalid_mail => 1,
			showright => 0,
		};
	}

	# check for uniqueness after lc
	$email = lc $email;

	my $user = $db->get_user_by_email($email);
	#debug Dumper $user;
	if ($user and $user->{verify_time}) {
		return template 'registration_form', {
			duplicate_mail => 1,
			showright => 0,
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
	my $mymaven = mymaven;
	sendmail(
		From    => $mymaven->{from},
		To      => $email,
		Subject => "Please finish the $mymaven->{title} registration",
		html    => $html,
	);
	my $html_from = $mymaven->{from};
	$html_from =~ s/</&lt;/g;
	return template 'response', { from => $html_from };
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
		my @files = get_download_files($code);
		foreach my $f (@files) {
			#debug "$code -  $f->{file}";
			push @owned_products, {
				name     => "$products{$code}{name} $f->{title}",
				filename => "/download/$code/$f->{file}",
				linkname => $f->{file},
			};
		}
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

	send_file(path(mymaven->{dirs}{download}, $dir, $file), system_path => 1);
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
		my ($cookbook) = get_download_files('perl_maven_cookbook');

		return template 'thank_you', {
			filename => "/download/perl_maven_cookbook/$cookbook->{file}",
			linkname => $cookbook->{file},
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

	my $mymaven = mymaven;
	sendmail(
		From    => $mymaven->{from},
		To      => $user->{email},
		Subject => 'Thank you for registering',
		html    => template('post_verification_mail', {
			url => uri_for('/account'),
		}, { layout => 'email', }),
#		attachments => ['/home/gabor/save/perl_maven_cookbook_v0.01.pdf'],
	);

	sendmail(
		From    => $mymaven->{from},
		To      => $mymaven->{admin}{email},
		Subject => "New $mymaven->{title} newsletter registration",
		html    => "$user->{email} has registered",
	);

	my ($cookbook) = get_download_files('perl_maven_cookbook');

	template 'thank_you', {
		filename => "/download/perl_maven_cookbook/$cookbook->{file}",
		linkname => $cookbook->{file},
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
	send_file(
		mymaven->{dirs}{img} . "/$file",
		content_type => $ext,
		system_path => 1,
	);
};

get '/mail/:article' => sub {

	my $article = param('article');

	my $path = mymaven->{dirs}{mail} . "/$article.tt";
	return 'NO path' if not -e $path;

	my $tt = read_tt($path);
	return template 'error', {'no_such_article' => 1}
		if not $tt->{status} or $tt->{status} ne 'show';

	return template 'mail', $tt, {	layout => 'newsletter' };
};

get '/tv' => sub {
	my $tag = 'interview';
	_show({ article => 'tv', template => 'archive', layout => 'system' }, { pages => (read_meta("archive_$tag") || []) });
};

# TODO this should not be here!!
get qr{/(perldoc)/(.+)} => sub {
	my ($dir, $article) = splat;

	return _show({ path => mymaven->{dirs}{$dir}, article => $article, template => 'page', layout => 'page' });
};

# TODO move this to a plugin
get '/svg.xml' => sub {
	my %query = params();
	require Perl::Maven::SVG;
	my $xml = Perl::Maven::SVG::circle(\%query);
	return $xml;
};

get qr{/media/(.+)} => sub {
	my ($article) = splat;
	if ($article =~ /\.(mp4|webm)$/) {
		my $ext = $1;
		send_file(
			mymaven->{dirs}{media} . "/$article",
			content_type => "video/$ext",
			system_path => 1,
		);
	} elsif ($article =~ /\.(mp3)$/) {
		my $ext = $1;
		send_file(
			mymaven->{dirs}{media} . "/$article",
			content_type => "audio/mpeg",
			system_path => 1,
		);
	}

	return 'media error';
};



get qr{/(.+)} => sub {
	my ($article) = splat;

	return _show({ article => $article, template => 'page', layout => 'page' });
};

##########################################################################################

sub _show {
	my ($params, $data) = @_;
	$data ||= {};

	my $path = (delete $params->{path} || (mymaven->{site} . "/pages" )) . "/$params->{article}.tt";
	return template 'error', {'no_such_article' => 1} if not -e $path;

	my $tt = read_tt($path);
	return template 'error', {'no_such_article' => 1}
		if not $tt->{status} or $tt->{status} ne 'show';
	($tt->{date}) = split /T/, $tt->{timestamp};

	my $nick = $tt->{author};
	if ($nick and $authors{$nick}) {
		$tt->{author_name} = $authors{$nick}{author_name};
		$tt->{author_img} = $authors{$nick}{author_img};
		$tt->{author_google_plus_profile} = $authors{$nick}{author_google_plus_profile};
	} else {
		delete $tt->{author};
	}
	my $translator = $tt->{translator};
	if ($translator and $authors{$translator}) {
		$tt->{translator_name} = $authors{$translator}{author_name};
		$tt->{translator_img} = $authors{$translator}{author_img};
		$tt->{translator_google_plus_profile} = $authors{$translator}{author_google_plus_profile};
	} else {
		if ($translator) {
			error("'$translator'");
		}
		delete $tt->{translator};
	}

	my $books = delete $tt->{books};
	if ($books) {
		$books =~ s/^\s+|\s+$//g;
		foreach my $name (split /\s+/, $books) {
			$tt->{$name} = 1;
		}
	}

	$tt->{$_} = $data->{$_} for keys %$data;

	return template $params->{template}, $tt, { layout => $params->{layout} };
};

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
		business       => mymaven->{paypal}{email},
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
	my $tt = eval { Perl::Maven::Page->new(file => $file)->read };
	if ($@) {
		return {}; # hmm, this should have been caught when the meta files were generated...
	} else {
		return $tt;
	}
}


sub read_file {
	my $file = shift;
	open my $fh, '<encoding(UTF-8)', $file or return '';
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

sub get_download_files {
	my ($subdir) = @_;

	my $manifest = path mymaven->{dirs}{download}, $subdir, 'manifest.csv';
	#debug $manifest;
	my @files;
	if (open my $fh, $manifest) {
		while (my $line = <$fh>) {
			chomp $line;
			my ($file, $title) = split /;/, $line;
			push @files, {
				file => $file,
				title => $title,
			}
		}
	} else {
		error "Could not open $manifest : $!";
	}
	return @files;
}

sub read_sites {
	open my $fh, '<encoding(UTF-8)', mymaven->{root} . "/sites.yml" or return {};
	my $yaml = do { local $/ = undef; <$fh> };
	return from_yaml $yaml
}

sub read_resources {
    my %resources;
	open my $fh, '<encoding(UTF-8)', mymaven->{site} . "/resources.txt" or return \%resources;
	while (my $line = <$fh>) {
		chomp $line;
		my ($field, $value) = split /=/, $line;
		$resources{$field} = $value;
	}
	return \%resources;
}

sub read_authors {
	return if %authors;

	open my $fh, '<encoding(UTF-8)', mymaven->{root} . "/authors.txt" or return;
	while (my $line = <$fh>) {
		chomp $line;
		my ($nick, $name, $img, $google_plus_profile) = split /;/, $line;
		$authors{$nick} = {
			author_name => $name,
			author_img  => ($img || 'white_square.png'),
			author_google_plus_profile => $google_plus_profile,
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

sub read_meta {
	my ($file) = @_;

	my $host = Perl::Maven::Config::host(request->host);
	return read_json(path(mymaven->{meta} . "/$host/meta/$file.json"));
}

sub read_meta_meta {
	my ($file) = @_;

	return read_json(path(mymaven->{meta} . "/$file.json"));
}
sub read_json {
	my ($file) = @_;

	if (open my $fh, '<encoding(UTF-8)', $file) {
		local $/ = undef;
		my $json = <$fh>;
		return from_json $json, {utf8 => 1};
	}
	return;
}


true;

# vim:noexpandtab

