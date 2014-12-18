package Perl::Maven;
use Dancer2;

use Dancer2::Plugin::Passphrase qw(passphrase);

our $VERSION = '0.11';
my $PM_VERSION = 7;    # Version number to force JavaScript and CSS files reload

use Cwd qw(abs_path);
use Data::Dumper qw(Dumper);
use DateTime;
use Digest::SHA;
use Email::Valid;
use Fcntl qw(:flock SEEK_END);
use List::MoreUtils qw(uniq);
use POSIX       ();
use Time::HiRes ();
use YAML qw(LoadFile);
use MongoDB;
use Path::Tiny ();    # the path function would clash with the path function of Dancer

use Web::Feed;

use Perl::Maven::DB;
use Perl::Maven::Config;
use Perl::Maven::Page;
use Perl::Maven::Tools;
use Perl::Maven::WebTools
	qw(logged_in get_ip mymaven _generate_code pm_error _registration_form _template read_tt pm_show_abstract pm_show_page authors pm_message);
use Perl::Maven::Sendmail qw(send_mail);
use Perl::Maven::Account;

prefix '/foobar';
require Perl::Maven::MetaSyntactic;
prefix '/';

require Perl::Maven::CodeExplain;
require Perl::Maven::Admin;
require Perl::Maven::PayPal;

hook before => sub {
	set start_time => Time::HiRes::time;

	#if (not is_bot()) {
	#	set session => 'YAML';
	#	set session_domain => '.' . mymaven->{domain} . ( in_development() ? '.local' : '' );
	#}

	#config->{engines}{session}{YAML}{cookie_domain} = ".perlmaven.com.local";
	#set session_domain => '.' . mymaven->{domain} . ( in_development() ? '.local' : '' );

	my $appdir = abs_path config->{appdir};

	my $db = Perl::Maven::DB->new( config->{appdir} . '/pm.db' );
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

hook before_template => sub {
	my $t = shift;
	$t->{title} ||= '';
	if ( logged_in() ) {
		my $uid   = session('uid');
		my $db    = setting('db');
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

	$t->{user_info}      = user_info();
	$t->{user_info_json} = to_json $t->{user_info};

	#die Dumper $t;

	return;
};

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

get '/contributor/:name' => sub {
	my $name = param('name');
	if ( request->host !~ /^meta\./ ) {
		my $host = Perl::Maven::Config::host( request->host );
		if ( $host ne 'perlmaven.com' ) {    #TODO remove hardcoding
			$host =~ s/^\w+\.//;
		}
		return redirect "http://meta.$host/contributor/$name";
	}

	return "$name could not be found" if not authors->{$name};
	my $data = setting('tools')->read_meta('archive');
	my @articles = grep { $_->{author} eq $name or ( $_->{translator} and $_->{translator} eq $name ) } @$data;

	return pm_show_page(
		{
			article  => 'contributor',
			template => 'contributor',
		},
		{
			author   => authors->{$name},
			articles => \@articles,
		}
	);
};

get '/search' => sub {
	my $data = setting('tools')->read_meta_hash('keywords');

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
		return pm_show_page(
			{ article => 'index', template => 'meta', },
			{
				authors => authors(),
				stats   => setting('tools')->read_meta_meta('stats'),
			}
		);
	}

	my $pages = setting('tools')->read_meta_array( 'archive', limit => mymaven->{main_page_entries} );
	_replace_tags($pages);

	pm_show_page( { article => 'index', template => 'index', }, { pages => $pages } );
};

get '/keywords' => sub {
	my $kw = setting('tools')->read_meta_hash('keywords');
	delete $kw->{keys};    # TODO: temporarily deleted as this break TT http://www.perlmonks.org/?node_id=1022446
	                       #die Dumper $kw->{__WARN__};
	pm_show_page( { article => 'keywords', template => 'keywords', }, { kw => $kw } );
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
		$contributors{$name} = authors->{$name};
	}

	pm_show_page(
		{ article => 'about', template => 'about', },
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

	pm_show_page(
		{ article => 'archive', template => 'archive', },
		{
			pages    => $pages,
			abstract => param('abstract'),
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

get '/login' => sub {
	template 'login';
};

post '/login' => sub {
	my $email    = param('email');
	my $password = param('password');

	return pm_error('missing_data')
		if not $password or not $email;

	my $db   = setting('db');
	my $user = $db->get_user_by_email($email);
	if ( not $user->{password} ) {
		return template 'login', { no_password => 1 };
	}

	if ( substr( $user->{password}, 0, 7 ) eq '{CRYPT}' ) {
		return pm_error('invalid_pw')
			if not passphrase($password)->matches( $user->{password} );
	}
	else {
		return pm_error('invalid_pw')
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

post '/pm/whitelist-delete' => sub {
	return redirect '/login' if not logged_in();

	my $uid = session('uid');
	my $id  = param('id');
	my $db  = setting('db');
	$db->delete_from_whitelist( $uid, $id );
	pm_message('whitelist_entry_deleted');
};

get '/pm/user-info' => sub {
	to_json user_info();
};

# TODO probably we would want to move the show_right control from here to a template file (if we really need it here)
get '/register' => sub {
	return template 'registration_form', { show_right => 0, };
};

post '/pm/register.json' => sub {
	register();
};

post '/register' => sub {
	register();
};
get '/logout' => sub {
	session logged_in => 0;
	redirect '/';
};

get '/account' => sub {
	return redirect '/login' if not logged_in();

	my $db   = setting('db');
	my $uid  = session('uid');
	my $user = $db->get_user_by_id($uid);

	my @owned_products;
	foreach my $code ( @{ $user->{subscriptions} } ) {

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

get qr{^/(.+)} => sub {
	my ($article) = splat;

	if ( mymaven->{redirect}{$article} ) {
		return redirect mymaven->{redirect}{$article};
	}
	pass;
};

get '/download/:dir/:file' => sub {
	my $dir  = param('dir');
	my $file = param('file');

	# TODO better error reporting or handling when not logged in
	return redirect '/'
		if not logged_in();
	return redirect '/' if not setting('products')->{$dir};    # no such product

	# check if the user is really subscribed to the newsletter?
	my $db = setting('db');
	return redirect '/' if not $db->is_subscribed( session('uid'), $dir );

	send_file( path( mymaven->{dirs}{download}, $dir, $file ), system_path => 1 );
};

# special treatment of the /pro pages
# TODO: they should probably be moved to the top-level directory and the
# fact that they are only available to 'pro' subscribers should be part of the header of the page
# and not the path of the file
# actually, probably the first thing should be to add a 'pro' tag to the headers and use that
# information to decide who can see the file
# and then we should probably just handle directories seenlessly
get qr{^/pro/?$} => sub {
	my $product = 'perl_maven_pro';
	my $path    = mymaven->{site} . '/pages/pro.tt';
	my $promo   = 1;
	my $db      = setting('db');
	if ( logged_in() and $db->is_subscribed( session('uid'), $product ) ) {
		$promo = 0;
	}
	return pm_show_abstract( { path => $path, promo => $promo } );
};

get qr{^/pro/(.+)} => sub {
	my ($article) = splat;
	error if $article =~ /\.\./;
	my $product = 'perl_maven_pro';
	my $dir     = 'pro';

	my $path = mymaven->{dirs}{$dir} . "/$article.tt";
	pass if not -e $path;    # will show invalid page

	my $db = setting('db');
	pass if is_free("/pro/$article");
	pass
		if logged_in()
		and $db->is_subscribed( session('uid'), $product );

	session url => request->path;

	pm_show_abstract( { path => $path } );
};

get qr{^/pro/(.+)} => sub {
	my ($article) = splat;

	return pm_show_page(
		{
			path     => mymaven->{dirs}{pro},
			article  => $article,
			template => 'page',
		}
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

	$tt->{url}          = $url;
	$tt->{email_footer} = 1;

	return template 'email_newsletter', $tt, { layout => 'email' };
};

get '/verify2/:code' => sub {
	my $code = param('code');

	return pm_error('missing_verification_code') if not $code;

	# TODO Shall we expect here the same user to be logged in already? Can we expect that?

	my $db           = setting('db');
	my $verification = $db->get_verification($code);
	return pm_error('invalid_verification_code')
		if not $verification;

	my $details = eval { from_json $verification->{details} };
	my $uid     = $verification->{uid};
	my $user    = $db->get_user_by_id($uid);

	if ( $verification->{action} eq 'verify_email' ) {
		$db->delete_verification_code($code);
		return verify_registration( $uid, $user->{email} );
	}

	if ( $verification->{action} eq 'change_email' ) {
		$db->replace_email( $user->{email}, $details->{new_email} );

		$db->delete_verification_code($code);

		return pm_message('email_updated_successfully');
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
		return pm_message( 'whitelist_updated', ip => $ip );
	}

	return pm_error('internal_verification_error');
};

get '/verify/:id/:code' => sub {
	my $uid  = param('id');
	my $code = param('code');

	my $db   = setting('db');
	my $user = $db->get_user_by_id($uid);

	if ( not $user ) {
		return pm_error('invalid_uid');
	}

	if (   not $user->{verify_code}
		or not $code
		or $user->{verify_code} ne $code )
	{
		return pm_error('invalid_code');
	}

	if ( $user->{verify_time} ) {
		return template 'thank_you';
	}

	verify_registration( $uid, $user->{email} );
};

sub verify_registration {
	my ( $uid, $email ) = @_;
	my $db = setting('db');

	if ( not $db->verify_registration($uid) ) {
		return template 'verify_form', { error => 1, };
	}

	$db->subscribe_to( uid => $uid, code => 'perl_maven_cookbook' );

	session uid       => $uid;
	session logged_in => 1;
	session last_seen => time;

	my $url = request->base;
	$url =~ s{/+$}{};

	my $mymaven = mymaven;
	my $err     = send_mail(
		{
			From    => $mymaven->{from},
			To      => $email,
			Subject => 'Thank you for registering',
		},
		{
			html => template(
				'email_after_verification',
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
			html => "$email has registered",
		}
	);

	template 'thank_you';
}

get '/img/:file' => sub {
	my $file = param('file');
	return if $file !~ /^[\w-]+\.(\w+)$/;
	my $ext = $1;
	my %map = ( svg => 'image/svg+xml', );
	send_file(
		path( mymaven->{dirs}{img}, $file ),
		content_type => ( $map{$ext} // $ext ),
		system_path => 1,
	);
};

get '/tv' => sub {
	pm_show_page(
		{ article => 'tv', template => 'archive' },
		{
			pages => setting('tools')->read_meta_array( 'archive', filter => 'interview' )
		}
	);
};

get qr{^/media/(.+)} => sub {
	my ($item) = splat;
	error if $item =~ /\.\./;

	my $db = setting('db');
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

get qr{^/(.+)} => sub {
	my ($article) = splat;

	return pm_show_page( { article => $article, template => 'page' } );
};

##########################################################################################
sub get_download_files {
	my ($subdir) = @_;

	my $manifest = path( mymaven->{dirs}{download}, $subdir, 'manifest.csv' );

	#debug $manifest;
	my @files;
	eval {
		foreach my $line ( Path::Tiny::path($manifest)->lines ) {
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
	my $p = Path::Tiny::path( mymaven->{root} . '/sites.yml' );
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
			$e{author}{name} = authors->{ $p->{author} }{author_name};
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

sub register {
	my $mymaven = mymaven;

	my %data = (
		password => param('password'),
		email    => param('email'),
		name     => param('name'),
	);
	if ( $mymaven->{require_password} ) {
		$data{password} //= '';
		$data{password} =~ s/^\s+|\s+$//g;
		if ( not $data{password} ) {
			return _registration_form( %data, error => 'missing_password' );
		}
		if ( length $data{password} < $mymaven->{require_password} ) {
			return _registration_form(
				%data,
				error  => 'password_short',
				params => [ $mymaven->{require_password} ]
			);
		}
	}

	if ( not $data{email} ) {
		return _registration_form( %data, error => 'no_email_provided' );
	}
	$data{email} = lc $data{email};
	$data{email} =~ s/^\s+|\s+$//;
	if ( not Email::Valid->address( $data{email} ) ) {
		return _registration_form( %data, error => 'invalid_mail' );
	}

	my $db   = setting('db');
	my $user = $db->get_user_by_email( $data{email} );

	#debug Dumper $user;
	if ($user) {
		if ( $user->{verify_time} ) {
			return _registration_form( %data, error => 'already_registered_and_verified' );
		}
		else {
			return _registration_form( %data, error => 'already_registered_not_verified' );
		}

	}

	my $code = _generate_code();
	my $uid = $db->add_registration( { email => $data{email} } );
	$db->save_verification(
		code      => $code,
		action    => 'verify_email',
		timestamp => time,
		uid       => $uid,
		details   => to_json {
			new_email => $data{email},
		},
	);

	my $err = send_verification_mail(
		'email_first_verification_code',
		$data{email},
		"Please finish the $mymaven->{title} registration",
		{
			url  => uri_for('/verify2'),
			code => $code,
		},
	);
	if ($err) {
		return pm_error( 'could_not_send_email', params => [ $data{email} ], );
	}

	my $html_from = $mymaven->{from};
	$html_from =~ s/</&lt;/g;
	return _template 'response', { from => $html_from };
}

post '/pm/change-email' => sub {
	my $mymaven = mymaven;
	if ( not logged_in() ) {
		return redirect '/login';
	}
	my $email = param('email') || '';
	if ( not $email ) {
		return pm_error('no_email_provided');
	}
	if ( not Email::Valid->address($email) ) {
		return pm_error('broken_email');
	}

	# check for uniqueness after lc
	$email = lc $email;
	my $db         = setting('db');
	my $other_user = $db->get_user_by_email($email);
	if ($other_user) {
		return pm_error('email_exists');
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
	my $err = send_verification_mail(
		'email_verification_code',
		$email,
		"Please verify your new e-mail address for $mymaven->{title}",
		{
			url  => uri_for('/verify2'),
			code => $code,
		},
	);
	if ($err) {
		return pm_error( 'could_not_send_email', params => [$email], );
	}

	pm_message('verification_email_sent');
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

sub in_development {
	return request->host =~ /local(:\d+)?$/;
}

sub _replace_tags {
	my ($pages) = @_;

	foreach my $p (@$pages) {
		$p->{tags} ||= [];
		$p->{tags} = { map { $_ => 1 } @{ $p->{tags} } };
	}
	return;
}

sub user_info {
	my %data = ( logged_in => logged_in(), );
	my $uid = session('uid');
	if ($uid) {
		my $db = setting('db');
		$data{perl_maven_pro} = $db->is_subscribed( $uid, 'perl_maven_pro' );
		my $user = $db->get_user_by_id($uid);
		$data{admin} = $user->{admin} ? 1 : 0;
	}

	# adding popups:

	#my @popups = (
	#	{
	#		logged_in => 1,
	#		what => 'popup_logged_in',
	#		when => 1000,
	#	 	frequency => 60*60*24,   # not more than
	# } );
	my $referrer = request->referer || '';
	my $url      = request->base    || '';
	my $path     = request->path    || '';

	$referrer =~ s{^(https?://[^/]*/).*}{$1};

	#debug("referrer = '$referrer'");
	#debug("url = '$url'");
	return \%data if $path =~ m{^(/pm/|/account|/login)};

	if ( $url ne $referrer ) {
		if ( logged_in() ) {

			# if not a pro subscriber yet
			if ( not $data{perl_maven_pro} ) {
				my $seen = session('popup_logged_in');

				if ( not $seen or $seen < time - 60 * 60 * 24 ) {

					#if ( not $seen or $seen < time - 10 ) {}
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

	return \%data;
}

true;

