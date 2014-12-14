package Perl::Maven;
use Dancer2;

use Dancer2::Plugin::Passphrase qw(passphrase);

our $VERSION = '0.11';
my $PM_VERSION         = 3;    # Version number to force JavaScript and CSS files reload
my $CODE_EXPLAIN_LIMIT = 20;

use Business::PayPal;
use Cwd qw(cwd abs_path);
use Data::Dumper qw(Dumper);
use DateTime;
use Digest::SHA;
use Email::Valid;
use Fcntl qw(:flock SEEK_END);
use File::Basename qw(fileparse);
use List::MoreUtils qw(uniq);
use POSIX       ();
use Time::HiRes ();
use YAML qw(LoadFile);
use MongoDB;
use Path::Tiny ();    # the path function would clash with the path function of Dancer
sub tpath { goto &Path::Tiny::path }

use Web::Feed;

use Perl::Maven::DB;
use Perl::Maven::Config;
use Perl::Maven::Page;
use Perl::Maven::Tools;
use Perl::Maven::WebTools qw(logged_in get_ip mymaven _generate_code);
use Perl::Maven::Sendmail qw(send_mail);

# delayed load, I think in order to allow the before hook to instantiate the Perl::Maven::DB singleton
require Perl::Maven::Admin;
require Perl::Maven::PayPal;

## configure relative pathes
my $db;
my %authors;

hook before => sub {
	set start_time => Time::HiRes::time;

	#if (not is_bot()) {
	#	set session => 'YAML';
	#	set session_domain => '.' . mymaven->{domain} . ( in_development() ? '.local' : '' );
	#}
	set session_domain => '.' . mymaven->{domain} . ( in_development() ? '.local' : '' );

	my $appdir = abs_path config->{appdir};

	$db ||= Perl::Maven::DB->new( config->{appdir} . '/pm.db' );
	set db => $db;

	# Create a new Template::Toolkit object for every call because we cannot access the existing object
	# and thus we cannot change the include path before rendering
	my $engines = config->{engines};
	$engines->{template_toolkit}{INCLUDE_PATH}
		= ["$appdir/views"];
	Dancer2::Template::TemplateToolkit->new(
		name   => 'template_toolkit',
		type   => 'template',
		config => $engines->{template_toolkit}
	);

	read_authors();
	my $p = $db->get_products;

	set products => $p;

	set tools => Perl::Maven::Tools->new(
		host => request->host,
		meta => mymaven->{meta}
	);

	set sid => session('id');

	return;
};
hook after => sub {
	my ($response) = @_;
	log_request($response);
	return;
};

sub log_request {
	my ($response) = @_;

	# It seems uri is not set when accessing images on the development server
	my $uri = request->uri;
	return if not defined $uri;
	return if $uri =~ m{^/img/};
	return if $uri =~ m{^/download/};

	my $time = time;
	my $dir = path( config->{appdir}, 'logs' );
	mkdir $dir if not -e $dir;
	my $file = path( $dir, POSIX::strftime( '%Y-%m-%d-requests.log', gmtime($time) ) );

	my $ip = get_ip();

	my %details = (
		sid        => setting('sid'),
		time       => $time,
		host       => request->host,
		page       => request->uri,
		referrer   => scalar( request->referer ),
		ip         => $ip,
		user_agent => scalar( request->user_agent ),
		status     => response->status,
	);
	my $start_time = setting('start_time');

	if ($start_time) {
		$details{elapsed_time} = Time::HiRes::time - $start_time;
	}

	# TODO if there are entries in the session, move them to the database
	if (logged_in) {
		$details{uid} = session('uid');
	}

	log_to_mongodb( \%details );

	return if $response->status != 200;
	return if $uri =~ m{^/atom};
	return if $uri =~ m{^/robots.txt};
	return if $uri =~ m{^/search};

	return if is_bot();

	#my %SKIP = map { $_ => 1 } qw(/pm/user-info);
	#return if $SKIP{$uri};

	if ( open my $fh, '>>', $file ) {
		flock( $fh, LOCK_EX ) or return;
		seek( $fh, 0, SEEK_END ) or return;
		say $fh to_json \%details, { pretty => 0, canonical => 1 };
		close $fh;
	}
	return;
}

sub log_to_mongodb {
	my ($data) = @_;

	my $client     = MongoDB::MongoClient->new( host => 'localhost', port => 27017 );
	my $database   = $client->get_database('PerlMaven');
	my $collection = $database->get_collection('logging');
	$collection->insert($data);
}
hook before_template => sub {
	my $t = shift;
	$t->{title} ||= '';
	if ( logged_in() ) {
		my $uid   = session('uid');
		my $user  = $db->get_user_by_id($uid);
		my $email = $user->{email};
		( $t->{username} ) = split /@/, $email;
	}

	# we assume that the whole complex is written in one leading language
	# and some of the pages are to other languages The domain-site give the name of the
	# default language and this is the same content that is displayed on the site
	# without a hostname: 	# http://domain.com
	my $original_language = mymaven->{main_site};
	my $language          = mymaven->{lang};
	$t->{"lang_$language"} = 1;

	#my $data = setting('tools')->read_meta_hash('keywords');
	#$t->{keywords} = to_json( [ sort keys %$data ] );
	#$t->{keywords} =  '{}';

	$t->{resources} = read_resources();

	# linking to translations
	my $sites        = read_sites();
	my $translations = setting('tools')->read_meta_meta('translations');
	my $path         = request->path;
	my %links;

	if ( $path ne '/' ) {
		my $original
			= $language eq $original_language
			? substr( $path, 1 )
			: $t->{original};
		if ($original) {
			foreach my $language_code ( keys %{ $translations->{$original} } ) {
				$sites->{$language_code}{url}
					.= $translations->{$original}{$language_code};
				$links{$language_code} = $sites->{$language_code};
			}

			#if ($language ne $original_language) {
			$sites->{$original_language}{url} .= $original;
			$links{$original_language} = $sites->{$original_language};

			#}
		}
	}
	else {
		%links = %$sites;
	}

	# For cases where our language code does not match the standard:
	# See http://support.google.com/webmasters/bin/answer.py?hl=en&answer=189077&topic=2370587&ctx=topic
	# http://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
	my %ISO_LANG = (
		br => 'pt',
		cn => 'zh-Hans',
		tw => 'zh-Hant',
	);
	my %localized = map { ( $ISO_LANG{$_} || $_ ) => $links{$_} } keys %links;
	$t->{localized_versions} = \%localized;

	delete $links{$language};    # no link to the curren site
	$t->{languages} = \%links;

	my $url = request->uri_base . request->path;
	foreach my $field (qw(reddit_url twitter_data_url twitter_data_counturl google_plus_href facebook_href)) {
		$t->{$field} = $url;
	}

	if ( $t->{no_such_article} ) {
		$t->{conf}{clicky}           = 0;
		$t->{conf}{google_analytics} = 0;
	}

	# TODO start using a separate development configuration file and remove this code from here:
	if ( in_development() ) {
		$t->{conf}{show_social} = 0;

		$t->{conf}{comments_disqus_enable} = 0;
		$t->{conf}{clicky}                 = 0;
		$t->{conf}{google_analytics}       = 0;
	}

	$t->{pm_version} = in_development() ? time : $PM_VERSION;

	$t->{user_info} = user_info();

	#die Dumper $t;

	return;
};

sub in_development {
	return request->host =~ /local(:\d+)?$/;
}

# Dynamic robots.txt generation to allow dynamic Sitemap URL
get '/robots.txt' => sub {
	my $host = request->host;
	my $txt  = <<"END_TXT";
Sitemap: http://$host/sitemap.xml
Disallow: /media/*
END_TXT

	content_type 'text/plain';
	return $txt;
};

get '/foobar' => sub {
	require Acme::MetaSyntactic;
	my $ams = Acme::MetaSyntactic->new;

	my $theme = param('theme');
	my @names;
	if ( $theme and $ams->has_theme($theme) ) {
		@names = sort $ams->name( $theme, 0 );
	}

	_show(
		{ article => 'foobar', template => 'foobar', layout => 'system' },
		{
			themes     => [ $ams->themes ],
			name_count => scalar @names,
			names      => \@names,
		}
	);
};

get '/contributor/:name' => sub {
	my $name = param('name');
	if ( request->host !~ /^meta\./ ) {
		my $host = Perl::Maven::Config::host( request->host );
		if ( $host ne 'perlmaven.com' ) {    #TODO remove hardcoding
			$host =~ s/^\w+\.//;
		}
		return redirect "http://meta.$host/contributor/$name";
	}

	return "$name could not be found" if not $authors{$name};
	my $data = setting('tools')->read_meta('archive');
	my @articles = grep { $_->{author} eq $name or ( $_->{translator} and $_->{translator} eq $name ) } @$data;

	return _show(
		{
			article  => 'contributor',
			template => 'page',
			layout   => 'contributor'
		},
		{
			author   => $authors{$name},
			articles => \@articles,
		}
	);
};

post '/pm/whitelist' => sub {
	if ( not logged_in() ) {

		#session url => request->path;
		return redirect '/login';
	}
	my $do  = param('do');
	my $uid = session('uid');
	if ($do) {
		if ( $do eq 'enable' ) {
			if ( $db->set_whitelist( $uid, 1 ) ) {
				my $ip   = get_ip();
				my $mask = '255.255.255.255';

				my $whitelist = $db->get_whitelist($uid);
				my $found = grep { $whitelist->{$_}{ip} eq $ip and $whitelist->{$_}{mask} eq $mask } keys %$whitelist;
				if ( not $found ) {
					$db->add_to_whitelist(
						{
							uid  => $uid,
							ip   => $ip,
							mask => $mask,
							note => 'Added automatically when whitelist was enabled'
						}
					);
				}
				return template 'error', { whitelist_enabled => 1 };
			}
			else {
				return template 'error', { internal_error => 1 };
			}
		}
		elsif ( $do eq 'disable' ) {
			$db->set_whitelist( $uid, 0 );
			return template 'error', { whitelist_disabled => 1 };
		}
		else {
			return template 'error', { invalid_value_provided => 1 };

			# TODO report error
		}
	}
	return 'parameter missing';
};

get qr{/(.+)} => sub {
	my ($article) = splat;

	if ( mymaven->{redirect}{$article} ) {
		return redirect mymaven->{redirect}{$article};
	}
	pass;
};

get '/search' => sub {
	my $data = setting('tools')->read_meta_hash('keywords');

	#TODO: I thin this is only needed if we want to allow other sites to search here.
	#push_header 'Access-Control-Allow-Origin' => '*';

	my ($keyword) = param('keyword');
	if ( defined $keyword ) {
		my $result = $data->{$keyword};
		if ($result) {
			return to_json($result);
		}
		foreach my $kw ( keys %$data ) {
			my ($url) = grep { $data->{$kw}{$_} eq $keyword } keys %{ $data->{$kw} };
			if ($url) {
				return to_json { $url => $keyword };
			}
		}
		return to_json {};
	}

	my ($query) = param('query');
	if ( defined $query ) {

		$query = quotemeta $query;
		my @titles = map { values %$_ } values %$data;
		my @hits = uniq sort grep {/$query/i} ( @titles, keys %$data );
		my $LIMIT = 20;
		if ( @hits > $LIMIT ) {
			@hits = @hits[ 0 .. $LIMIT - 1 ];
		}
		return to_json( \@hits );
	}

	return to_json( {} );
};

get '/' => sub {
	if ( request->host =~ /^meta\./ ) {
		return _show(
			{ article => 'index', template => 'page', layout => 'meta' },
			{
				authors => \%authors,
				stats   => setting('tools')->read_meta_meta('stats'),
			}
		);
	}

	my $pages = setting('tools')->read_meta_array( 'archive', limit => mymaven->{main_page_entries} );
	_replace_tags($pages);

	_show( { article => 'index', template => 'page', layout => 'index' }, { pages => $pages } );
};

sub _replace_tags {
	my ($pages) = @_;

	foreach my $p (@$pages) {
		$p->{tags} ||= [];
		$p->{tags} = { map { $_ => 1 } @{ $p->{tags} } };
	}
	return;
}

get '/keywords' => sub {
	my $kw = setting('tools')->read_meta_hash('keywords');
	delete $kw->{keys};    # TODO: temporarily deleted as this break TT http://www.perlmonks.org/?node_id=1022446
	                       #die Dumper $kw->{__WARN__};
	_show( { article => 'keywords', template => 'page', layout => 'keywords' }, { kw => $kw } );
};

get '/about' => sub {
	my $pages = setting('tools')->read_meta_array('archive');
	my %cont;
	foreach my $p (@$pages) {
		if ( $p->{translator} ) {
			$cont{ $p->{translator} }++;
		}
		if ( $p->{author} ) {
			$cont{ $p->{author} }++;
		}
	}
	my %contributors;
	foreach my $name ( keys %cont ) {
		$contributors{$name} = $authors{$name};
	}

	_show(
		{ article => 'about', template => 'about', layout => 'system' },
		{
			contributors => \%contributors,
		}
	);
};

get '/archive' => sub {
	my $tag = param('tag');
	my $pages
		= $tag
		? setting('tools')->read_meta_array( 'archive', filter => $tag )
		: setting('tools')->read_meta_array('archive');
	_replace_tags($pages);

	_show(
		{ article => 'archive', template => 'archive', layout => 'system' },
		{
			pages    => $pages,
			abstract => param('abstract'),
		}
	);
};

get '/consultants' => sub {
	return redirect '/perl-training-consulting';
};

get '/perl-training-consulting' => sub {
	_show(
		{
			article  => 'perl-training-consulting',
			template => 'consultants',
			layout   => 'system'
		},
		{
			people => setting('tools')->read_meta_meta('consultants'),
		}
	);
};

get '/sitemap.xml' => sub {
	my $pages = setting('tools')->read_meta_array('sitemap');
	my $url   = request->base;
	$url =~ s{/$}{};
	content_type 'application/xml';

	my $xml = qq{<?xml version="1.0" encoding="UTF-8"?>\n};
	$xml .= qq{<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n};
	foreach my $p (@$pages) {
		$xml .= qq{  <url>\n};
		$xml .= qq{    <loc>$url/$p->{filename}</loc>\n};
		if ( $p->{timestamp} ) {
			$xml .= sprintf qq{    <lastmod>%s</lastmod>\n}, substr( $p->{timestamp}, 0, 10 );
		}

		#$xml .= qq{    <changefreq>monthly</changefreq>\n};
		#$xml .= qq{    <priority>0.8</priority>\n};
		$xml .= qq{  </url>\n};
	}
	$xml .= qq{</urlset>\n};
	return $xml;
};
get '/rss' => sub {
	my $tag = param('tag');
	return redirect '/rss?tag=tv' if $tag and $tag eq 'interview';

	return $tag
		? rss( 'archive', $tag )
		: rss('archive');
};
get '/atom' => sub {
	my $tag = param('tag');
	return $tag
		? atom( 'archive', $tag )
		: atom('archive');
};
get '/tv/atom' => sub {
	return atom( 'archive', 'interview', ' - Interviews' );
};

post '/send-reset-pw-code' => sub {
	my $email = param('email');
	if ( not $email ) {
		return template 'error', { no_email => 1 };
	}
	$email = lc $email;
	my $user = $db->get_user_by_email($email);
	if ( not $user ) {
		return template 'error', { invalid_email => 1 };
	}
	if ( not $user->{verify_time} ) {

		# TODO: send e-mail with verification code
		return template 'error', { not_verified_yet => 1 };
	}

	my $code = _generate_code();
	$db->set_password_code( $user->{email}, $code );

	my $html = template 'reset_password_mail',
		{
		url  => uri_for('/set-password'),
		id   => $user->{id},
		code => $code,
		},
		{ layout => 'email', };

	my $mymaven = mymaven;
	my $err     = send_mail(
		{
			From    => $mymaven->{from},
			To      => $email,
			Subject => "Code to reset your $mymaven->{title} password",
		},
		{
			html => $html,
		}
	);
	if ($err) {
		return template 'error', { could_not_send_email => 1, email => $email };
	}

	template 'error', { reset_password_sent => 1, };
};

get '/set-password/:id/:code' => sub {
	my $error = pw_form();
	return $error if $error;
	template 'set_password',
		{
		id   => param('id'),
		code => param('code'),
		};
};

post '/change-password' => sub {
	if ( not logged_in() ) {
		session url => request->path;
		return redirect '/login';
	}

	my $password  = param('password')  || '';
	my $password2 = param('password2') || '';

	return template 'error', { no_password => 1, }
		if not $password;

	return template 'error', { passwords_dont_match => 1, }
		if $password ne $password2;

	return template 'error', { bad_password => 1, }
		if length($password) < 6;

	my $uid = session('uid');
	$db->set_password( $uid, passphrase($password)->generate->rfc2307 );

	template 'error', { password_set => 1 };
};

post '/set-password' => sub {
	my $error = pw_form();
	return $error if $error;

	my $password = param('password');
	my $id       = param('id');
	my $user     = $db->get_user_by_id($id);

	return template 'error', { bad_password => 1, }
		if not $password
		or length($password) < 6;

	session uid       => $user->{id};
	session logged_in => 1;
	session last_seen => time;

	$db->set_password( $id, passphrase($password)->generate->rfc2307 );

	template 'error', { password_set => 1 };
};

post '/update-user' => sub {
	if ( not logged_in() ) {
		session url => request->path;
		return redirect '/login';
	}

	my $name = param('name') || '';

	my $uid = session('uid');
	$db->update_user( $uid, name => $name );

	template 'error', { user_updated => 1 };
};

get '/login' => sub {

	#session referer => request->referer;
	template 'login';
};

post '/login' => sub {
	my $email    = param('email');
	my $password = param('password');

	return template 'error', { missing_data => 1, }
		if not $password or not $email;

	my $user = $db->get_user_by_email($email);
	if ( not $user->{password} ) {
		return template 'login', { no_password => 1 };
	}

	if ( substr( $user->{password}, 0, 7 ) eq '{CRYPT}' ) {
		return template 'error', { invalid_pw => 1 }
			if not passphrase($password)->matches( $user->{password} );
	}
	else {
		return template 'error', { invalid_pw => 1 }
			if $user->{password} ne Digest::SHA::sha1_base64($password);

		# password is good, we need to update it
		$db->set_password( $user->{id}, passphrase($password)->generate->rfc2307 );
	}

	session uid       => $user->{id};
	session logged_in => 1;
	session last_seen => time;

	#my $url = session('referer') // '/account';
	#session referer => undef;
	my $url = session('url') // '/account';
	session url => undef;

	redirect $url;
};

get '/unsubscribe' => sub {
	return redirect '/login' if not logged_in();

	my $uid = session('uid');

	$db->unsubscribe_from( uid => $uid, code => 'perl_maven_cookbook' );
	template 'error', { unsubscribed => 1 };
};

get '/subscribe' => sub {
	return redirect '/login' if not logged_in();

	my $uid = session('uid');
	$db->subscribe_to( uid => $uid, code => 'perl_maven_cookbook' );
	template 'error', { subscribed => 1 };
};

post '/pm/whitelist-delete' => sub {
	return redirect '/login' if not logged_in();

	my $uid = session('uid');
	my $id  = param('id');
	$db->delete_from_whitelist( $uid, $id );
	template 'error', { whitelist_entry_deleted => 1 };
};

any '/pm/unsubscribe' => sub {
	my $code  = param('code');
	my $email = param('email');

	my $mymaven       = mymaven;
	my $expected_code = Digest::SHA::sha1_hex("unsubscribe$mymaven->{unsubscribe_salt}$email");
	if ( $code ne $expected_code ) {
		return template 'error', { invalid_unsubscribe_code => 1 };
	}

	my $user = $db->get_user_by_email($email);
	if ( not $user ) {
		return template 'error', { could_not_find_registration => 1 };
	}

	# TODO maybe we will want some stonger checking for confirmation?
	if ( param('confirm') ) {
		$db->unsubscribe_from( uid => $user->{id}, code => 'perl_maven_cookbook' );
		my $html    = template 'email_after_unsubscribe', { url => uri_for('/'), }, { layout => 'email' };
		my $mymaven = mymaven;
		my $err     = send_mail(
			{
				From    => $mymaven->{from},
				To      => $email,
				Subject => 'You were unsubscribed from the Perl Maven newsletter',
			},
			{
				html => $html,
			}
		);

		return template 'error', { unsubscribed => 1 };
	}

	return template 'confirm_unsubscribe',
		{
		code  => $code,
		email => $email,
		};
};

get '/pm/user-info' => sub {
	user_info();
};

sub user_info {
	my %data = ( logged_in => logged_in(), );

	# adding popups:

	#my @popups = (
	#	{
	#		logged_in => 1,
	#		what => 'popup_logged_in',
	#		when => 1000,
	#	 	frequency => 60*60*24,   # not more than
	my $referrer = request->referer || '';
	my $url      = request->base    || '';
	my $path     = request->path    || '';

	$referrer =~ s{^(https?://[^/]*/).*}{$1};

	#debug("referrer = '$referrer'");
	#debug("url = '$url'");
	return to_json \%data if $path =~ m{^(/pm/|/account|/login)};

	if ( $url ne $referrer ) {
		if ( logged_in() ) {

			# if not a pro subscriber yet
			if ( not $db->is_subscribed( session('uid'), 'perl_maven_pro' ) ) {
				my $seen = session('popup_logged_in');

				if ( not $seen or $seen < time - 60 * 60 * 24 ) {

					#if ( not $seen or $seen < time - 10 ) {
					session( 'popup_logged_in' => time );
					$data{delayed} = {
						what => 'popup_logged_in',
						when => 1000,
					};
				}
			}
		}
		else {
			my $seen = session('popup_logged_in');
			if ( not $seen or $seen < time - 60 * 60 * 24 ) {
				session( 'popup_logged_in' => time );
				$data{delayed} = {
					what => 'popup_visitor',
					when => 1000,
				};
			}
		}
	}

	return to_json \%data;
}

# TODO probably we would want to move the show_right control from here to a template file (if we really need it here)
get '/register' => sub {
	return template 'registration_form', { show_right => 0, };
};

post '/register' => sub {
	my $email = param('email');
	if ( not $email ) {
		return template 'registration_form',
			{
			no_mail    => 1,
			show_right => 0,
			};
	}
	if ( not Email::Valid->address($email) ) {
		return template 'registration_form',
			{
			invalid_mail => 1,
			show_right   => 0,
			};
	}

	# check for uniqueness after lc
	$email = lc $email;

	my $user = $db->get_user_by_email($email);

	#debug Dumper $user;
	if ( $user and $user->{verify_time} ) {
		return template 'registration_form',
			{
			duplicate_mail => 1,
			show_right     => 0,
			};
	}

	my $code = _generate_code();

	# basically resend the old code
	my $id;
	if ($user) {
		$code = $user->{verify_code};
		$id   = $user->{id};
	}
	else {
		$id = $db->add_registration( { email => $email, code => $code } );
	}

	my $mymaven = mymaven;
	my $err     = send_verification_mail(
		'first_verification_mail',
		$email,
		"Please finish the $mymaven->{title} registration",
		{
			url  => uri_for('/verify'),
			id   => $id,
			code => $code,
		},
	);
	if ($err) {
		return template 'error', { could_not_send_email => 1, email => $email };
	}

	my $html_from = $mymaven->{from};
	$html_from =~ s/</&lt;/g;
	return template 'response', { from => $html_from };
};

sub send_verification_mail {
	my ( $template, $email, $subject, $params ) = @_;

	my $html = template $template, $params, { layout => 'email', };
	my $mymaven = mymaven;
	return send_mail(
		{
			From    => $mymaven->{from},
			To      => $email,
			Subject => $subject,
		},
		{
			html => $html,
		}
	);
}

post '/change-email' => sub {
	if ( not logged_in() ) {
		return redirect '/login';
	}
	my $email = param('email') || '';
	if ( not $email ) {
		return template 'error', { no_email => 1, };
	}
	if ( not Email::Valid->address($email) ) {
		return template 'error', { broken_email => 1, };
	}

	# check for uniqueness after lc
	$email = lc $email;
	my $other_user = $db->get_user_by_email($email);
	if ($other_user) {
		return template 'error', { email_exists => 1 };
	}

	my $uid = session('uid');

	my $code = _generate_code();
	$db->save_verification(
		code      => $code,
		action    => 'change_email',
		timestamp => time,
		uid       => $uid,
		details   => to_json {
			new_email => $email,
		},
	);

	my $mymaven = mymaven;
	my $err     = send_verification_mail(
		'verification_mail',
		$email,
		"Please verify your new e-mail address for $mymaven->{title}",
		{
			url  => uri_for('/verify2'),
			code => $code,
		},
	);
	if ($err) {
		return template 'error', { could_not_send_email => 1, email => $email };
	}

	return template 'error', { verification_email_sent => 1 }

		#my $html_from = $mymaven->{from};
		#$html_from =~ s/</&lt;/g;
		#return template 'response', { from => $html_from };

};

get '/logout' => sub {
	session logged_in => 0;
	redirect '/';
};

get '/account' => sub {
	return redirect '/login' if not logged_in();

	my $uid  = session('uid');
	my $user = $db->get_user_by_id($uid);

	my @subscriptions = $db->get_subscriptions( $user->{email} );
	my @owned_products;
	foreach my $code (@subscriptions) {

		# TODO remove the hard-coded special case of the perl_maven_pro
		if ( $code eq 'perl_maven_pro' ) {
			push @owned_products,
				{
				name     => 'Perl Maven Pro',
				filename => '/archive?tag=pro',
				linkname => 'List of pro articles',
				};
		}
		else {
			my @files = get_download_files($code);
			foreach my $f (@files) {

				#debug "$code -  $f->{file}";
				push @owned_products,
					{
					name     => ( setting('products')->{$code}{name} . " $f->{title}" ),
					filename => "/download/$code/$f->{file}",
					linkname => $f->{file},
					};
			}
		}
	}

	my %params = (
		subscriptions   => \@owned_products,
		subscribed      => $db->is_subscribed( $uid, 'perl_maven_cookbook' ),
		name            => $user->{name},
		email           => $user->{email},
		login_whitelist => ( $user->{login_whitelist} ? 1 : 0 ),
	);
	if ( $user->{login_whitelist} ) {
		$params{whitelist} = $db->get_whitelist($uid);
	}
	if ( $db->get_product_by_code('perl_maven_pro') and not $db->is_subscribed( $uid, 'perl_maven_pro' ) ) {
		$params{perl_maven_pro_buy_button}
			= Perl::Maven::PayPal::paypal_buy( 'perl_maven_pro', 'trial', 1, 'perl_maven_pro_1_9' );
	}
	template 'account', \%params;
};

get '/download/:dir/:file' => sub {
	my $dir  = param('dir');
	my $file = param('file');

	# TODO better error reporting or handling when not logged in
	return redirect '/'
		if not logged_in();
	return redirect '/' if not setting('products')->{$dir};    # no such product

	# check if the user is really subscribed to the newsletter?
	return redirect '/' if not $db->is_subscribed( session('uid'), $dir );

	send_file( path( mymaven->{dirs}{download}, $dir, $file ), system_path => 1 );
};

get qr{^/pro/?$} => sub {
	my $product = 'perl_maven_pro';
	my $path    = mymaven->{site} . '/pages/pro.tt';
	my $promo   = 1;
	if ( logged_in() and $db->is_subscribed( session('uid'), $product ) ) {
		$promo = 0;
	}
	return _show_abstract( { path => $path, promo => $promo } );

	#my $tt = read_tt( $path );
	#return template 'prolist', $tt, { layout => 'page' };
};

get qr{/pro/(.+)} => sub {
	my ($article) = splat;
	error if $article =~ /\.\./;
	my $product = 'perl_maven_pro';
	my $dir     = 'pro';

	my $path = mymaven->{dirs}{$dir} . "/$article.tt";
	pass if not -e $path;    # will show invalid page

	pass if is_free("/pro/$article");
	pass
		if logged_in()
		and $db->is_subscribed( session('uid'), $product );

	session url => request->path;

	_show_abstract( { path => $path } );
};

get '/verify2/:code' => sub {
	my $code = param('code');

	return template 'error', { missing_verification_code => 1 } if not $code;

	# TODO Shall we expect here the same user to be logged in already? Can we expect that?

	my $verification = $db->get_verification($code);
	return template 'error', { invalid_verification_code => 1 }
		if not $verification;

	my $details = eval { from_json $verification->{details} };
	my $uid     = $verification->{uid};
	my $user    = $db->get_user_by_id($uid);

	if ( $verification->{action} eq 'change_email' ) {
		$db->replace_email( $user->{email}, $details->{new_email} );

		$db->delete_verification_code($code);

		return template 'error', { email_updated_successfully => 1 };
	}

	if ( $verification->{action} eq 'add_to_whitelist' ) {
		if ( not logged_in() ) {
			return 'You need to be logged in to validate the IP address';
		}
		my $ip        = $details->{ip};
		my $whitelist = $db->get_whitelist($uid);
		my $mask      = '255.255.255.255';
		my $found     = grep { $whitelist->{$_}{ip} eq $ip and $whitelist->{$_}{mask} eq $mask } keys %$whitelist;
		if ( not $found ) {
			$db->add_to_whitelist(
				{
					uid  => $uid,
					ip   => $ip,
					mask => $mask,
					note => 'Added at ' . gmtime(),
				}
			);
		}
		$db->delete_verification_code($code);
		return template 'error', { whitelist_updated => 1, ip => $ip };
	}

	return template 'error', { internal_verification_error => 1 };
};

get '/verify/:id/:code' => sub {
	my $id   = param('id');
	my $code = param('code');

	my $user = $db->get_user_by_id($id);

	if ( not $user ) {
		return template 'error', { invalid_uid => 1 };
	}

	if (   not $user->{verify_code}
		or not $code
		or $user->{verify_code} ne $code )
	{
		return template 'error', { invalid_code => 1 };
	}

	if ( $user->{verify_time} ) {
		return template 'thank_you';
	}

	if ( not $db->verify_registration( $id, $code ) ) {
		return template 'verify_form', { error => 1, };
	}

	$db->subscribe_to( uid => $user->{id}, code => 'perl_maven_cookbook' );

	session uid       => $user->{id};
	session logged_in => 1;
	session last_seen => time;

	my $url = request->base;
	$url =~ s{/+$}{};

	my $mymaven = mymaven;
	my $err     = send_mail(
		{
			From    => $mymaven->{from},
			To      => $user->{email},
			Subject => 'Thank you for registering',
		},
		{
			html => template(
				'post_verification_mail',
				{
					url => $url,
				},
				{ layout => 'email', }
			),
		}
	);

	send_mail(
		{
			From    => $mymaven->{from},
			To      => $mymaven->{admin}{email},
			Subject => "New $mymaven->{title} newsletter registration",
		},
		{
			html => "$user->{email} has registered",
		}
	);

	template 'thank_you';
};

get '/img/:file' => sub {
	my $file = param('file');
	return if $file !~ /^[\w-]+\.(\w+)$/;
	my $ext = $1;
	send_file(
		path( mymaven->{dirs}{img}, $file ),
		content_type => $ext,
		system_path  => 1,
	);
};

get '/mail/:article' => sub {
	my $article = param('article');
	my $code    = param('code') || '';
	my $email   = param('email') || '';

	my $path = mymaven->{dirs}{mail} . "/$article.tt";
	return 'NO path' if not -e $path;

	my $tt = read_tt($path);
	return template 'error', { 'no_such_article' => 1 }
		if not $tt->{status}
		or $tt->{status} ne 'show';

	$tt->{code}  = $code;
	$tt->{email} = $email;
	my $url = request->base;

	#$url =~ s{/+$}{};
	$tt->{url} = $url;

	return template 'mail', $tt, { layout => 'newsletter' };
};

get '/tv' => sub {
	_show(
		{ article => 'tv', template => 'archive', layout => 'system' },
		{
			pages => setting('tools')->read_meta_array( 'archive', filter => 'interview' )
		}
	);
};

# TODO this should not be here!!
get qr{/(pro|perldoc)/(.+)} => sub {
	my ( $dir, $article ) = splat;

	return _show(
		{
			path     => mymaven->{dirs}{$dir},
			article  => $article,
			template => 'page',
			layout   => 'page'
		}
	);
};

# TODO move this to a plugin
get '/svg.xml' => sub {
	my %query = params();
	require Perl::Maven::SVG;
	my $xml = Perl::Maven::SVG::circle( \%query );
	return $xml;
};

get qr{/media/(.+)} => sub {
	my ($item) = splat;
	error if $item =~ /\.\./;

	if ( $item =~ m{^pro/} and not is_free("/$item") ) {
		my $product = 'perl_maven_pro';
		return 'error: not logged in' if not logged_in();
		return 'error: not a Pro subscriber'
			if not $db->is_subscribed( session('uid'), $product );
	}

	push_header 'X-Accel-Redirect' => "/send/$item";

	if ( $item =~ /\.(mp4|webm|avi|ogv)$/ ) {
		my $ext = $1;
		if ( $ext eq 'ogv' ) {
			$ext = 'ogg';
		}
		push_header 'Content-type' => "video/$ext";
		return;
	}
	elsif ( $item =~ /\.(mp3)$/ ) {
		my $ext = $1;
		push_header 'Content-type' => 'audio/mpeg';
		return;
	}

	return 'media error';
};

get '/explain' => sub {
	require Code::Explain;
	my %data = (
		code_explain_version => $Code::Explain::VERSION,
		limit                => $CODE_EXPLAIN_LIMIT,
	);
	return template 'explain', \%data;
};
post '/explain' => sub {
	my $code = params->{'code'};
	$code = '' if not defined $code;
	$code =~ s/^\s+|\s+$//g;

	my %data = (
		code_explain_version => $Code::Explain::VERSION,
		limit                => $CODE_EXPLAIN_LIMIT,
		code                 => $code,
	);
	if ($code) {
		$data{html_code} = _escape($code);
		if ( length $code > $CODE_EXPLAIN_LIMIT ) {
			$data{too_long} = length $code;
		}
		else {
			require Code::Explain;
			my $ce = Code::Explain->new( code => $code );
			$data{explanation} = $ce->explain();
			$data{ppi_dump} = [ map { _escape($_) } $ce->ppi_dump ];
			$data{ppi_explain}
				= [ map { $_->{code} = _escape( $_->{code} ); $_ } $ce->ppi_explain ];
		}

		my $time = time;
		my $log_file
			= path( config->{appdir}, 'logs', 'code_' . POSIX::strftime( '%Y%m', gmtime($time) ) );
		if ( open my $fh, '>>', $log_file ) {
			print $fh '-' x 20, "\n";
			print $fh scalar( gmtime $time ) . "\n";
			print $fh "$code\n\n";
			close $fh;
		}
	}
	return to_json \%data;
};

sub _escape {
	my $txt = shift;
	$txt =~ s/</&lt;/g;
	$txt =~ s/>/&gt;/g;
	return $txt;
}

get '/jobs-employer' => sub {
	template 'jobs_employer', { a => 1, };
};

get qr{/(.+)} => sub {
	my ($article) = splat;

	return _show( { article => $article, template => 'page', layout => 'page' } );
};

##########################################################################################
sub _show_abstract {
	my ($params) = @_;
	my $tt = read_tt( $params->{path} );
	$tt->{promo} = $params->{promo} // 1;

	#		if not logged_in(), tell the user to subscribe or log in
	#
	#		if logged in but not subscribed, tell the user to subscribe
	delete $tt->{mycontent};
	return template 'propage', $tt, { layout => 'page' };
}

sub _show {
	my ( $params, $data ) = @_;
	$data ||= {};

	my $path
		= ( delete $params->{path} || ( mymaven->{site} . '/pages' ) ) . "/$params->{article}.tt";
	if ( not -e $path ) {
		status 'not_found';
		return template 'error', { 'no_such_article' => 1 };
	}

	my $tt = read_tt($path);
	if ( not $tt->{status}
		or ( $tt->{status} !~ /^(show|draft|done)$/ ) )
	{
		status 'not_found';
		return template 'error', { 'no_such_article' => 1 };
	}
	( $tt->{date} ) = split /T/, $tt->{timestamp};

	my $nick = $tt->{author};
	if ( $nick and $authors{$nick} ) {
		$tt->{author_name} = $authors{$nick}{author_name};
		$tt->{author_img}  = $authors{$nick}{author_img};
		$tt->{author_google_plus_profile}
			= $authors{$nick}{author_google_plus_profile};
	}
	else {
		delete $tt->{author};
	}
	my $translator = $tt->{translator};
	if ( $translator and $authors{$translator} ) {
		$tt->{translator_name} = $authors{$translator}{author_name};
		$tt->{translator_img}  = $authors{$translator}{author_img};
		$tt->{translator_google_plus_profile}
			= $authors{$translator}{author_google_plus_profile};
	}
	else {
		if ($translator) {
			error("'$translator'");
		}
		delete $tt->{translator};
	}

	my $books = delete $tt->{books};
	if ($books) {
		$books =~ s/^\s+|\s+$//g;
		foreach my $name ( split /\s+/, $books ) {
			$tt->{$name} = 1;
		}
	}

	$tt->{$_} = $data->{$_} for keys %$data;

	return template $params->{template}, $tt, { layout => $params->{layout} };
}

sub pw_form {
	my $id   = param('id');
	my $code = param('code');

	# if there is such userid with such code and it has not expired yet
	# then show a form
	return template 'error', { missing_data => 1 }
		if not $id or not $code;

	my $user = $db->get_user_by_id($id);
	return template 'error', { invalid_uid => 1 }
		if not $user;
	return template 'error', { invalid_code => 1 }
		if not $user->{password_reset_code}
		or $user->{password_reset_code} ne $code
		or not $user->{password_reset_timeout};
	return template 'error', { old_password_code => 1 }
		if $user->{password_reset_timeout} < time;

	return;
}

sub read_tt {
	my $file = shift;
	my $tt   = eval {
		Perl::Maven::Page->new( file => $file, tools => setting('tools') )->read->merge_conf( mymaven->{conf} )->data;
	};
	if ($@) {

		# hmm, this should have been caught when the meta files were generated...
		error $@;
		return {};
	}
	else {
		return $tt;
	}
}

sub get_download_files {
	my ($subdir) = @_;

	my $manifest = path( mymaven->{dirs}{download}, $subdir, 'manifest.csv' );

	#debug $manifest;
	my @files;
	eval {
		foreach my $line ( tpath($manifest)->lines ) {
			chomp $line;
			my ( $file, $title ) = split /;/, $line;
			push @files,
				{
				file  => $file,
				title => $title,
				};
		}
		1;
	} or do {
		my $err = $@ // 'Unknown error';
		error "Could not open $manifest : $err";
	};
	return @files;
}

sub read_sites {
	my $p = tpath( mymaven->{root} . '/sites.yml' );
	return {} if not $p;
	return YAML::Load $p->slurp_utf8;
}

# Each site can have a file called resources.txt with rows of key=value pairs
# This is text messages and translated text messages.
sub read_resources {
	my $default_file = mymaven->{root} . '/resources.yml';
	my $defaults = eval { LoadFile $default_file};

	my $resources_file = mymaven->{site} . '/resources.yml';
	my $data = eval { LoadFile $resources_file};
	$data ||= {};

	foreach my $key ( keys %{ $defaults->{text} } ) {
		$data->{text}{$key} ||= $defaults->{text}{$key};
	}
	return $data;
}

sub read_authors {
	return if %authors;

	# Path::Tiny would throw an exception if it could not open the file
	# but we for Perl::Maven this file is optional
	eval {
		my $fh = tpath( mymaven->{root} . '/authors.txt' );

		# TODO add row iterator interface to Path::Tiny https://github.com/dagolden/Path-Tiny/issues/107
		foreach my $line ( $fh->lines_utf8 ) {
			chomp $line;
			my ( $nick, $name, $img, $google_plus_profile ) = split /;/, $line;
			$authors{$nick} = {
				author_name                => $name,
				author_img                 => ( $img || 'white_square.png' ),
				author_google_plus_profile => $google_plus_profile,
			};
		}
	};
	return;
}

sub _feed {
	my ( $what, $tag, $subtitle ) = @_;

	$subtitle ||= '';

	my $pages = setting('tools')->read_meta_array( $what, filter => $tag, limit => mymaven->{feed_size} );

	my $mymaven = mymaven;

	my $ts = DateTime->now;

	my $url = request->base;
	$url =~ s{/$}{};
	my $title = $mymaven->{title};

	my @entries;
	foreach my $p (@$pages) {
		my %e;

		my $host = $p->{url} ? $p->{url} : $url;

		die 'no title ' . Dumper $p if not defined $p->{title};
		my $title = $p->{title};

		# TODO remove hard-coded pro check
		if ( grep { 'pro' eq $_ } @{ $p->{tags} } ) {
			$title = "Pro: $title";
		}

		$e{title}   = $title;
		$e{summary} = qq{<![CDATA[$p->{abstract}]]>};
		$e{updated} = $p->{timestamp};

		if ( $p->{mp3} ) {    # itunes(rss)
			$e{itunes}{author}    = 'Gabor Szabo';
			$e{itunes}{summary}   = $e{summary};
			$e{enclosure}{url}    = "$host$p->{mp3}[0]";
			$e{enclosure}{length} = $p->{mp3}[1];
			$e{enclosure}{type}   = 'audio/x-mp3';
			$e{itunes}{duration}  = $p->{mp3}[2];
		}

		$url = $p->{url} ? $p->{url} : $url;
		$e{link} = qq{$url/$p->{filename}?utm_campaign=rss};

		$e{id} = $p->{id} ? $p->{id} : "$url/$p->{filename}";
		$e{content} = qq{<![CDATA[$p->{abstract}]]>};
		if ( $p->{author} ) {
			$e{author}{name} = $authors{ $p->{author} }{author_name};
		}
		push @entries, \%e;
	}

	my $pmf = Web::Feed->new(
		url       => $url,                  # atom, rss
		path      => 'atom',                # atom
		title     => "$title$subtitle",     # atom, rss
		updated   => $ts,                   # atom,
		entries   => \@entries,             # atom,
		language  => 'en-us',               #       rss
		copyright => '2014 Gabor Szabo',    #       rss
		description => 'The Perl Maven show is about the Perl programming language and about the people using it.'
		,                                   # rss, itunes(rss)

		subtitle => 'A show about Perl and Perl users',    # itunes(rss)
		author   => 'Gabor Szabo',                         # itunes(rss)
	);
	$pmf->{summary}      = $pmf->{description};            # itunes(rss)
	$pmf->{itunes_name}  = 'Gabor Szabo';
	$pmf->{itunes_email} = 'szabgab@gmail.com';

	return $pmf;
}

sub atom {
	my ( $what, $tag, $subtitle ) = @_;

	my $pmf = _feed( $what, $tag, $subtitle );

	content_type 'application/atom+xml';
	return $pmf->atom;
}

sub rss {
	my ( $what, $tag, $subtitle ) = @_;

	my $pmf = _feed( $what, $tag, $subtitle );

	content_type 'application/rss+xml';
	return $pmf->rss;
}

sub is_free {
	my ($path) = @_;
	return Perl::Maven::Tools::_any( $path, mymaven->{free} );
}

sub is_bot {
	my $user_agent = request->user_agent || '';
	return $user_agent
		=~ /Googlebot|AhrefsBot|TweetmemeBot|bingbot|YandexBot|MJ12bot|heritrix|Baiduspider|Sogou web spider|Spinn3r|robots|thumboweb_bot|Blekkobot|Exabot|LWP::Simple/;

}

true;

