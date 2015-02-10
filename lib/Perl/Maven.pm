package Perl::Maven;
use Dancer2;

use Dancer2::Plugin::Passphrase qw(passphrase);

our $VERSION = '0.11';
my $PM_VERSION = 9;    # Version number to force JavaScript and CSS files reload

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
	qw(logged_in get_ip mymaven pm_error pm_template read_tt pm_show_abstract pm_show_page authors pm_message pm_user_info);
use Perl::Maven::Sendmail qw(send_mail);
use Perl::Maven::Account;

prefix '/foobar';
require Perl::Maven::MetaSyntactic;
prefix '/';

require Perl::Maven::Consultants;
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

		if ( grep { $_ eq 'perl_maven_pro' } @{ $user->{subscriptions} } ) {
			$t->{conf}{show_ads} = 0;
		}
	}

	if ( $t->{books} ) {
		my @logos;
		foreach my $book ( @{ $t->{books} } ) {
			if ( mymaven->{logos}{$book} ) {
				push @logos, mymaven->{logos}{$book};
			}
		}
		$t->{books} = \@logos;
	}

	# we assume that the whole complex is written in one leading language
	# and some of the pages are to other languages The domain-site give the name of the
	# default language and this is the same content that is displayed on the site
	# without a hostname: 	# http://domain.com
	my $original_language = mymaven->{main_site};
	my $language          = mymaven->{lang};
	$t->{"lang_$language"} = 1;
	$t->{brand_name} = mymaven->{title};

	$t->{domain}    = mymaven->{domain};
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

	$t->{pm_version} = in_development() ? time : $PM_VERSION;

	$t->{user_info}      = pm_user_info();
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

get '/search/:keyword' => sub {
	my ($keyword) = param('keyword');
	return pm_show_page { article => 'search', template => 'search', },
		{
		title   => $keyword,
		results => _search(),
		keyword => $keyword,
		};
};

get '/search' => sub {
	my ($keyword) = param('keyword');
	return pm_show_page { article => 'search', template => 'search', },
		{
		title   => $keyword,
		results => _search(),
		keyword => $keyword,
		};
};

get '/search.json' => sub {
	return to_json _search();
};

sub _search {
	my $data = setting('tools')->read_meta_hash('keywords');

	my ($keyword) = param('keyword');
	if ( defined $keyword ) {

		# check if there is an exact keyword match
		my $result = $data->{$keyword};
		if ($result) {
			return $result;
		}

		# check if search was for the exact title:
		foreach my $kw ( keys %$data ) {
			my ($entry) = grep { $_->{title} eq $keyword } @{ $data->{$kw} };
			if ($entry) {
				return { $entry->{url} => $keyword };
			}
		}

		# TODO we should do better here for no exact matches
		return {};
	}

	my ($query) = param('query');
	if ( defined $query ) {

		$query = quotemeta $query;
		my @titles;
		foreach my $v ( values %$data ) {
			push @titles, map { $_->{title} } @$v;
		}
		my @hits = uniq sort grep {/$query/i} ( @titles, keys %$data );
		my $LIMIT = 20;
		if ( @hits > $LIMIT ) {
			@hits = @hits[ 0 .. $LIMIT - 1 ];
		}
		return \@hits;
	}

	return {};
}

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

get qr{^/try/(.+)} => sub {
	my ($try_file) = splat;

	#send_file( path(mymaven->{root}, $try_file) , system_path => 1 );
	my $p       = Path::Tiny::path( path( mymaven->{root}, $try_file ) );
	my $content = $p->slurp_utf8;
	my $tt      = Template->new(
		{ INCLUDE_PATH => abs_path( config->{appdir} ) . '/views', START_TAG => '<%', END_TAG => '%>' } );
	my %data;
	$data{conf}{google_analytics} = mymaven->{conf}{google_analytics};
	my $ga;
	$tt->process( 'incl/google_analytics.tt', \%data, \$ga ) or die Template->error();
	return $content . $ga;
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

# temporary solution
get '/verify2/:code' => sub {
	return redirect '/pm/verify2/' . param('code');
};
get '/verify/:id/:code' => sub {
	return redirect '/pm/verify/' . param('id') . '/' . param('code');
};

get qr{^/(.+)} => sub {
	my ($article) = splat;

	if ( mymaven->{redirect}{$article} ) {
		return redirect mymaven->{redirect}{$article};
	}
	pass;
};

get '/category' => sub {
	my $categories = setting('tools')->read_meta('categories');
	return pm_show_page(
		{
			article  => 'category',
			template => 'categories',
		},
		{
			categories => [ sort keys %$categories ],
		}
	);
};

get '/category/:name' => sub {
	my $name       = param('name');
	my $categories = setting('tools')->read_meta('categories');
	return "No such category '$name'" if not $categories->{$name};
	pm_show_page(
		{ article => 'archive', template => 'archive', },
		{
			pages    => $categories->{$name},
			abstract => 0,
		}
	);
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
	my $path    = mymaven->{site} . '/pages/pro.txt';
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

	my $path = mymaven->{dirs}{$dir} . "/$article.txt";
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

	my $path = mymaven->{dirs}{mail} . "/$article.txt";
	return 'NO path' if not -e $path;

	my $tt = read_tt($path);
	return pm_template 'error', { 'no_such_article' => 1 }
		if not $tt->{status}
		or $tt->{status} ne 'show';

	$tt->{code}  = $code;
	$tt->{email} = $email;
	my $url = request->base;

	$tt->{url}          = $url;
	$tt->{email_footer} = 1;

	return template 'email_newsletter', $tt, { layout => 'email' };
};

get '/favicon.ico' => sub {
	_send_file('favicon.ico');
};

get '/img/:file' => sub {
	my $file = param('file');
	_send_file($file);
};

sub _send_file {
	my ($file) = @_;

	return if $file !~ /^[\w-]+\.(\w+)$/;
	my $ext = $1;
	my %content_type_map = ( svg => 'image/svg+xml', ico => 'image/x-icon' );
	send_file(
		path( mymaven->{dirs}{img}, $file ),
		content_type => ( $content_type_map{$ext} // $ext ),
		system_path => 1,
	);
}

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
	return if $uri =~ m{^/search.json};

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

true;

