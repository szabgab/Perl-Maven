package Perl::Maven;
use Dancer2;

use Dancer2::Plugin::Passphrase;    # qw(passphrase);

our $VERSION = '0.11';
my $PM_VERSION = 16;                # Version number to force JavaScript and CSS files reload

use Cwd qw(abs_path);
use Data::Dumper qw(Dumper);
use DateTime ();
use Fcntl qw(:flock SEEK_END);
use List::MoreUtils qw(uniq);
use List::Util qw(min);
use POSIX       ();
use Time::HiRes ();
use YAML::XS qw(LoadFile);
use MongoDB;
use Path::Tiny ();                  # the path function would clash with the path function of Dancer
use Cpanel::JSON::XS ();
use Encode qw(encode);

use Web::Feed;

use Perl::Maven::DB;
use Perl::Maven::Config;
use Perl::Maven::Page;
use Perl::Maven::Tools;
use Perl::Maven::WebTools
	qw(logged_in get_ip mymaven pm_error pm_template read_tt pm_show_abstract pm_show_page authors pm_message pm_user_info);
use Perl::Maven::Account;

prefix '/digger';
require Perl::Maven::AnalyzeWeb;

prefix '/foobar';
require Perl::Maven::MetaSyntactic;
prefix '/';

require Perl::Maven::Consultants;
require Perl::Maven::CodeExplain;
require Perl::Maven::Admin;
require Perl::Maven::PayPal;

hook before => sub {
	set start_time => Time::HiRes::time;

	my $appdir = abs_path config->{appdir};

	my $db = Perl::Maven::DB->new( config->{appdir} . '/pm.db' );
	set db => $db;

	#set views => ["$appdir/views"]; # Cannot set array!

	# Create a new Template::Toolkit object for every call because we cannot access the existing object
	# and thus we cannot change the include path before rendering
	#my $engines = config->{engines};
	#$engines->{template_toolkit}{INCLUDE_PATH}
	#	= ["$appdir/views"];
	#Dancer2::Template::TemplateToolkit->new(
	#	name   => 'template_toolkit',
	#	type   => 'template',
	#	config => $engines->{template_toolkit}
	#);

	my $p = $db->get_products;

	set products => $p;

	set tools => Perl::Maven::Tools->new(
		host => request->host,
		meta => mymaven->{meta}
	);

	set sid => session('id');

	# Job server
	if (1) {
		my %jobs;
		my @files = grep { !/(links|skeleton).yml/ } glob path( config->{appdir}, 'config/jobs', '*.yml' );
		foreach my $file (@files) {
			my ($job_id) = $file =~ m{([^/]+)\.yml$};
			my $job_data = eval { LoadFile($file) };
			if ($@) {
				error("While loading '$file':\n$@");
				next;
			}
			next if not $job_data->{show};
			$jobs{$job_id} = $job_data;
			$jobs{$job_id}{id} = $job_id;
		}
		set jobs => \%jobs;
		my $links_file = path( config->{appdir}, 'config/jobs/links.yml' );
		if ( -e $links_file ) {
			set job_links => eval { LoadFile($links_file) };
		}
	}

	return;
};

hook after => sub {
	my ($response) = @_;
	log_request();
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

	# If these pages are sales piches then we should not show other ads.
	if ( request->path =~ m{^/pro/} ) {
		$t->{conf}{show_ads} = 0;
	}

	$t->{domain} = mymaven->{domain};

	sub _conv {
		my ( $domain, $file ) = @_;
		return $file if $file =~ m{^incl/};
		return "sites/$domain/templates/$file";
	}

	# Don't show right-hand ads to pro subscribers
	my @right = @{ mymaven->{right} || [] };
	foreach my $r (@right) {
		if ( $r->{file} ) {
			$r->{file} = _conv( $t->{domain}, $r->{file} );
		}
		if ( $r->{files} ) {
			$r->{files} = [ map { _conv( $t->{domain}, $_ ) } @{ $r->{files} } ];
		}
	}

	#die Dumper \@right;
	if ( $t->{conf}{show_ads} ) {
		$t->{right} = \@right;
	}
	else {
		$t->{right} = [ grep { not $_->{ad} } @right ];
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
	elsif ( mymaven->{default_image} ) {
		$t->{books} = [
			sprintf q{<a href="/"><img src="%s" alt="%s" title="%s" /></a>}, mymaven->{default_image},
			mymaven->{title},                                                mymaven->{title}
		];
	}

	# we assume that the whole complex is written in one leading language
	# and some of the pages are to other languages The domain-site give the name of the
	# default language and this is the same content that is displayed on the site
	# without a hostname: 	# http://domain.com
	my $original_language = mymaven->{main_site};
	my $language          = mymaven->{lang};
	$t->{"lang_$language"} = 1;
	$t->{brand_name}       = mymaven->{title};
	$t->{default_image}    = mymaven->{default_image};

	if ( $t->{conf}{show_jobs} ) {
		my $jobs    = setting('jobs');
		my @job_ids = sort keys %$jobs;
		$t->{jobs} = [];
		my $n = min( $t->{conf}{featured_jobs}, scalar @job_ids );    # number of featured ads
		foreach ( 1 .. $n ) {
			my $jid = int rand scalar @job_ids;
			push @{ $t->{jobs} }, $jobs->{ splice @job_ids, $jid, 1 };
		}
	}

	# Adserver
	if ( $t->{conf}{show_ads} and mymaven->{ads} ) {
		foreach my $place ( keys %{ mymaven->{ads} } ) {

			#next if not mymaven->{ads}{$place};
			my $ads  = mymaven->{ads}{$place};
			my $file = $ads->[ rand @$ads ];
			$t->{ads}{$place}
				= Path::Tiny::path( path( config->{appdir}, "config/$t->{domain}/ads", $file ) )->slurp_utf8;
		}
	}

	$t->{resources} = read_resources();

	# linking to translations
	my $sites        = read_sites();
	my $translations = setting('tools')->read_meta_meta('translations');
	my $path         = request->path;
	my %links;

	my $lookup_series = setting('tools')->read_meta('lookup_series');
	my $series = $lookup_series->{ substr( $path, 1 ) };
	if ($series) {
		my $all_series = setting('tools')->read_meta('series');
		$t->{series} = $all_series->{$series};
		if ( $t->{series}{url} eq $path ) {
			$t->{series}{current} = 1;
			$t->{next}{url}       = $t->{series}{chapters}[0]{sub}[0]{url};
			$t->{next}{title}     = $t->{series}{chapters}[0]{sub}[0]{title};
		}
	CHAPTER:
		foreach my $ch ( 0 .. @{ $t->{series}{chapters} } - 1 ) {
			foreach my $e ( 0 .. @{ $t->{series}{chapters}[$ch]{sub} } - 1 ) {
				if ( $t->{series}{chapters}[$ch]{sub}[$e]{url} eq $path ) {
					$t->{series}{chapters}[$ch]{sub}[$e]{current} = 1;
					if ( $e > 0 ) {
						$t->{prev}{url}   = $t->{series}{chapters}[$ch]{sub}[ $e - 1 ]{url};
						$t->{prev}{title} = $t->{series}{chapters}[$ch]{sub}[ $e - 1 ]{title};
					}
					elsif ( $ch > 0 ) {
						$t->{prev}{url}   = $t->{series}{chapters}[ $ch - 1 ]{sub}[-1]{url};
						$t->{prev}{title} = $t->{series}{chapters}[ $ch - 1 ]{sub}[-1]{title};
					}
					else {
						$t->{prev}{url}   = $t->{series}{url};
						$t->{prev}{title} = $t->{series}{title};
					}
					if ( $e < @{ $t->{series}{chapters}[$ch]{sub} } - 1 ) {
						$t->{next}{url}   = $t->{series}{chapters}[$ch]{sub}[ $e + 1 ]{url};
						$t->{next}{title} = $t->{series}{chapters}[$ch]{sub}[ $e + 1 ]{title};
					}
					elsif ( $ch < @{ $t->{series}{chapters} } - 1 ) {
						$t->{next}{url}   = $t->{series}{chapters}[ $ch + 1 ]{sub}[0]{url};
						$t->{next}{title} = $t->{series}{chapters}[ $ch + 1 ]{sub}[0]{title};
					}
					last CHAPTER;
				}
			}
		}
	}

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

	$links{$language}{current} = 1;    # mark the current language
	$t->{languages} = [ sort { $a->{name} cmp $b->{name} } values %links ];

	my $url = request->uri_base . request->path;
	foreach my $field (qw(reddit_url twitter_data_url twitter_data_counturl google_plus_href facebook_href)) {
		$t->{$field} = $url;
	}

	if ( mymaven->{github} and -e path( mymaven->{root}, 'sites', $language, 'pages', "$path.txt" ) ) {
		$t->{edit} = mymaven->{github} . "/tree/main/sites/$language/pages/$path.txt";
	}

	if ( $t->{no_such_article} ) {
		$t->{conf}{google_analytics} = 0;
	}

	$t->{pm_version} = in_development() ? time : $PM_VERSION;
	if ( in_development() ) {
		$t->{google_prettify} = q{<link href="/google-code-prettify/prettify.css" rel="stylesheet">};
		$t->{google_prettify} .= q{<script src="/google-code-prettify/prettify.js"></script>};
		$t->{jquery_cdn}  = '/javascripts';
		$t->{angular_cdn} = '';
	}
	else {
		$t->{google_prettify}
			= q{<script src="https://cdn.rawgit.com/google/code-prettify/master/loader/run_prettify.js"></script>};
		$t->{jquery_cdn}    = 'https://code.jquery.com';
		$t->{angular_cdn}   = 'https://ajax.googleapis.com/ajax/libs';
		$t->{bootstrap_cdn} = 'https://maxcdn.bootstrapcdn.com';
	}

	$t->{user_info}      = pm_user_info();
	$t->{user_info_json} = to_json $t->{user_info};

	#die Dumper $t;

	return;
};

# Dynamic robots.txt generation to allow dynamic Sitemap URL
get '/robots.txt' => sub {
	my $host = request->host;
	my $txt  = <<"END_TXT";
Sitemap: https://$host/sitemap.xml
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
		return redirect "https://meta.$host/contributor/$name";
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

get '/jobs' => sub {
	redirect '/jobs/';
};
get '/jobs/' => sub {
	my $jobs = setting('jobs');
	template 'jobs', { jobs => $jobs };
};

get '/jobs/:id' => sub {
	my ($job_id)  = param('id');
	my $jobs      = setting('jobs');
	my $job_links = setting('job_links');
	if ( $jobs->{$job_id} ) {
		if ( $jobs->{$job_id}{modules} ) {
			@{ $jobs->{$job_id}{modules} } = map { { name => $_, url => $job_links->{modules}{$_}, } }
				grep { $job_links->{modules}{$_} } @{ $jobs->{$job_id}{modules} };
		}
		template 'job', { job => $jobs->{$job_id} };
	}
	else {
		return 'No such job. Please check out the <a href="/jobs/">list of available Perl jobs</a>.';
	}
};

# autocomplete: given one or more letters return the existing, or the most popular search terms
# search: given one or more letters search various sources
#    special index file(s)
#    keywords in pages
#    match in title
#    match in abstact
#    match in text

get '/search/:query' => sub {
	my ($query) = param('query');

	my $LIMIT = 20;

	my $data = setting('tools')->read_meta_hash('keywords');
	$query =~ s/^\s+|\s+$//g;
	my @hits;
	if ( defined $query ) {

		# check if there is an exact keyword match
		my $result = $data->{$query};
		my %seen;
		if ($result) {
			push @hits, @$result;
		}
		foreach my $h (@hits) {
			$seen{ $h->{url} } = 1;
		}

		my $regex = quotemeta lc $query;

		# check if search matches the title:
		if ( @hits < $LIMIT ) {
			foreach my $kw ( keys %$data ) {
				foreach my $e ( @{ $data->{$kw} } ) {
					next if $seen{ $e->{url} };
					push @hits, $e if lc( $e->{title} ) =~ /$regex/;
					$seen{ $e->{url} } = 1;
				}
			}
		}

		#if (@hits < $LIMIT) {
		#	foreach my $word ( split /\W+/, lc $keyword ) {
		#		foreach my $k ( keys %$data ) {
		#			if ( $word eq lc $k ) {
		#				push @hits, @{ $data->{$k} };
		#			}
		#		}
		#	}
		#}
	}

	if ( @hits > $LIMIT ) {
		@hits = @hits[ 0 .. $LIMIT - 1 ];
	}

	return pm_show_page { article => 'search', template => 'search', },
		{
		title   => $query,
		results => \@hits,
		query   => $query,
		};
};

get '/api/1/recent' => sub {
	my @recent;
	my $limit = param('limit') || 100;
	eval {
		my $client     = MongoDB::MongoClient->new( host => 'localhost', port => 27017 );
		my $database   = $client->get_database('PerlMaven');
		my $collection = $database->get_collection('cpan');
		my $res        = $collection->find->sort(
			{ 'cpan.date' => -1 },
			{
				'_cm_.repository_url' => 1,
				'_cm_.travis_yml'     => 1,
				'cpan.distribution'   => 1,
				'cpan.abstract'       => 1,
				'cpan.date'           => 1,
				'cpan.license'        => 1,
			}
		)->limit($limit);
		while ( my $r = $res->next ) {
			my $repository_url = $r->{_cm_}{repository_url} || '';
			my %data = (
				repository_url => $r->{_cm_}{repository_url},
				travis_yml     => $r->{_cm_}{travis_yml},
				distribution   => $r->{cpan}{distribution},
				abstract       => $r->{cpan}{abstract},
				date           => $r->{cpan}{date},
				license        => $r->{cpan}{license},

			   # // var repo_url = d.cpan.metadata.resources.repository.web || d.cpan.metadata.resources.repository.url;
			);
			my ($repo) = $repository_url =~ m{https://github.com/(.*)};
			if ($repo) {
				$data{repo} = $repo;
			}
			push @recent, \%data;
		}
	};
	push_header 'Content-type' => 'application/json';
	my $json = Cpanel::JSON::XS->new->utf8;
	$json->convert_blessed(1);
	return $json->encode( \@recent );
};

get '/autocomplete.json/:query' => sub {
	my ($query) = param('query');

	my $LIMIT = 20;

	$query =~ s/^\s+|\s+$//g;
	return [] if not $query;
	my $data = setting('tools')->read_meta_hash('keywords');

	my @hits;

	# Include exact match
	if ( $data->{$query} ) {
		push @hits, $query;
	}

	my $regex = quotemeta lc $query;

	# include the keywords that match
	# TODO shall we rank shorter first?
	# shall we rank prefix before other hits?
	my @match;
	foreach my $k ( keys %$data ) {
		next if $k eq $query;    # we already have this in the first place
		if ( lc($k) =~ /$regex/ ) {
			push @match, $k;
		}
	}
	@match = sort { length $a <=> length $b or $a cmp $b } @match;
	push @hits, @match;

	if ( @hits < $LIMIT ) {

		# add more from other sources as well
		my %words;
		foreach my $title ( values %$data ) {
			foreach my $word ( split /\s+/, lc $title ) {
				$words{$word}++ if $word =~ /$regex/;
			}
		}
		push @hits, keys %words;
	}

	if ( @hits > $LIMIT ) {
		@hits = @hits[ 0 .. $LIMIT - 1 ];
	}
	if ( not @hits ) {
		push @hits, $query;
	}
	return to_json \@hits;
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

	my $MAIN_PAGE_ENTRIES = 10;
	my $pages             = setting('tools')
		->read_meta_array( 'archive', limit => ( mymaven->{main_page_entries} // $MAIN_PAGE_ENTRIES ) );
	_replace_tags($pages);

	pm_show_page( { article => 'index', template => 'index', }, { pages => $pages } );
};

get '/keywords' => sub {
	my $kw = setting('tools')->read_meta_hash('keywords');
	delete $kw->{keys};    # TODO: temporarily deleted as this break TT http://www.perlmonks.org/?node_id=1022446
	                       #die Dumper $kw->{__WARN__};
	pm_show_page( { article => 'keywords', template => 'keywords', }, { kw => $kw } );
};

#get qr{^/static/(.+)} => sub {
#	my ($static_file) = splat;
#	die if $static_file =~ /\.\./;
#	my $p = path( mymaven->{root}, "static/$static_file" );
#
#	if ( $static_file =~ /\.js$/ ) {
#		content_type 'text/javascript';
#	}
#	send_file( $p, system_path => 1 );
#};

get qr{^/try/(.+)} => sub {
	my ($try_file) = splat;
	die if $try_file =~ /\.\./;

	my $path = path( mymaven->{root}, $try_file );
	if ( $try_file =~ /\.html$/ ) {
		my $p       = Path::Tiny::path($path);
		my $content = $p->slurp_utf8;

		my $tt = Template->new(
			{ INCLUDE_PATH => abs_path( config->{appdir} ) . '/views', START_TAG => '<%', END_TAG => '%>' } );
		my %data;
		$data{conf}{google_analytics} = mymaven->{conf}{google_analytics};
		my $ga;
		$tt->process( 'incl/google_analytics.tt', \%data, \$ga ) or die Template->error();
		$content .= $ga;

		return $content;
	}

	if ( $try_file =~ /\.js$/ or $try_file =~ /\.json$/ or $try_file =~ /\.htm$/ ) {
		content_type 'text/javascript';
		send_file( $path, system_path => 1 );
	}
	die 'Dont know how to handle.';
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
	$url =~ s{http://}{https://};    # ???
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

get '/rss/:tag' => sub {
	my $tag = param('tag');
	return redirect '/rss/tv' if $tag and $tag eq 'interview';
	return rss( 'archive', $tag, '', 0 );
};
get '/rss' => sub {
	my $tag = param('tag');
	return redirect "/rss/$tag" if $tag;
	rss( 'archive', undef, '', 0 );
};
get '/atom' => sub {
	my $tag = param('tag');
	return $tag
		? atom( 'archive', $tag,  0 )
		: atom( 'archive', undef, 0 );
};

get '/rss-full' => sub {
	my $tag = param('tag');
	return redirect '/rss?tag=tv' if $tag and $tag eq 'interview';

	return $tag
		? rss( 'archive', $tag,  1 )
		: rss( 'archive', undef, 1 );
};
get '/atom-full' => sub {
	my $tag = param('tag');
	return $tag
		? atom( 'archive', $tag,  1 )
		: atom( 'archive', undef, 1 );
};

get '/tv/atom' => sub {
	return atom( 'archive', 'interview' );
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
			categories => [ map { { name => $_, count => scalar @{ $categories->{$_} } } } sort keys %$categories ],
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

get qr{^/pod/(.+)} => sub {
	my ($article) = splat;

	return pm_show_page(
		{
			path     => mymaven->{dirs}{pod},
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

get '/:name' => sub {
	my $name = param('name');
	if ( mymaven->{special}{$name} ) {
		pm_show_page(
			{ article => $name, template => 'archive' },
			{
				pages => setting('tools')->read_meta_array( 'archive', filter => $name ),
			}
		);
	}
	else {
		pass;
	}
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

	my $p = path( config->{appdir}, "config/pre/$article.yml" );
	my $data = -e $p ? LoadFile($p) : {};

	return pm_show_page( { article => $article, template => 'page' }, {}, $data );
};

##########################################################################################
sub read_sites {
	my $path = mymaven->{root} . '/sites.yml';
	return {} if not -e $path;
	return LoadFile $path;
}

# Each site can have a file called resources.txt with rows of key=value pairs
# This is text messages and translated text messages.
sub read_resources {
	my $default_file = mymaven->{root} . '/resources.yml';
	my $defaults = eval { LoadFile $default_file};

	#error("Could not load '$default_file' $@") if $@;

	my $resources_file = mymaven->{site} . '/resources.yml';
	my $data = eval { LoadFile $resources_file};
	error("Could not load '$resources_file' $@") if $@;
	$data ||= {};

	foreach my $key ( keys %{ $defaults->{text} } ) {
		$data->{text}{$key} ||= $defaults->{text}{$key};
	}
	return $data;
}

sub _feed {
	my ( $what, $tag, $pro ) = @_;

	my $pages;
	if ($tag) {
		$pages = setting('tools')->read_meta_array("rss_$tag");
	}
	else {
		$pages = setting('tools')->read_meta_array($what);
	}

	my $mymaven = mymaven;

	my $ts = DateTime->now;

	my $url = request->base;
	$url =~ s{/$}{};
	my $title = $mymaven->{title};

	my %fields;
	if ( $mymaven->{feeds} ) {
		my $hand = $tag || '__main__';
		if ( $mymaven->{feeds}{$hand} ) {

			# rss, itunes(rss)
			foreach my $f (qw(description subtitle copyright author image)) {
				$fields{$f} = $mymaven->{feeds}{$hand}{$f} || '';
			}
			foreach my $f (qw(keywords)) {
				$fields{$f} = $mymaven->{feeds}{$hand}{$f} || [];
			}
		}
	}

	my @entries;
	foreach my $p (@$pages) {
		my %e;

		next if $p->{filename} =~ m{^pro/} and not $pro;

		my $host = $p->{url} ? $p->{url} : $url;

		die 'no title ' . Dumper $p if not defined $p->{title};
		my $title = $p->{title};

		# TODO remove hard-coded pro check
		if ( grep { 'pro' eq $_ } @{ $p->{tags} } ) {
			$title = "Pro: $title";
		}

		$url = $p->{url} ? $p->{url} : $url;
		my $link = qq{$url/$p->{filename}};

		my $abstract = $p->{abstract};
		if ( $tag and mymaven->{special}{$tag} ) {
			$abstract .= qq{\n<a href="$link">Links and transcript</a>\n};
		}

		$e{title}   = $title;
		$e{summary} = qq{<![CDATA[$abstract]]>};
		$e{updated} = $p->{timestamp};

		if ( $p->{mp3} ) {    # itunes(rss)
			$e{itunes}{author}    = 'Gabor Szabo';
			$e{itunes}{summary}   = $e{summary};
			$e{enclosure}{url}    = "$host$p->{mp3}[0]";
			$e{enclosure}{length} = $p->{mp3}[1];
			$e{enclosure}{type}   = 'audio/mpeg';
			$e{itunes}{duration}  = $p->{mp3}[2];
		}

		$e{link} = $link;

		$e{id} = $p->{id} ? $p->{id} : $link;
		$e{content} = qq{<![CDATA[$abstract]]>};
		if ( $p->{author} ) {
			$e{author}{name} = authors->{ $p->{author} }{author_name};
		}

		push @entries, \%e;

		# TODO: we will want the main rss feed to be limited,
		# but the rss feed of the podcast to be unlimited.
		last if defined mymaven->{feed_size} and @entries >= mymaven->{feed_size};
	}

	my $pmf = Web::Feed->new(
		%fields,
		url      => $url,            # atom, rss
		path     => 'atom',          # atom
		title    => $title,          # atom, rss
		updated  => $ts,             # atom,
		entries  => \@entries,       # atom,
		language => 'en-us',         #       rss
		category => 'Technology',    # itunes
	);

	#<itunes:category text="Technology">
	#   <itunes:category text="Software How-To"/>
	#   <itunes:category text="Tech News"/>
	# </itunes:category>

	$pmf->{summary}      = $pmf->{description};    # itunes(rss)
	$pmf->{itunes_name}  = 'Gabor Szabo';
	$pmf->{itunes_email} = 'szabgab@gmail.com';

	return $pmf;
}

sub atom {
	my ( $what, $tag, $pro ) = @_;

	my $pmf = _feed( $what, $tag, $pro );

	content_type 'application/atom+xml';
	return encode( 'UTF-8', $pmf->atom );
}

sub rss {
	my ( $what, $tag, $pro ) = @_;

	my $pmf = _feed( $what, $tag, $pro );

	content_type 'application/rss+xml';
	return encode( 'UTF-8', $pmf->rss );
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
	my $page =

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

	if ( request->query_string ) {
		$details{query_string} = request->query_string;
	}
	if ( $details{page} =~ m{^/autocomplete.json/(.+)} ) {
		$details{autocomplete} = $1;
	}
	if ( $details{page} =~ m{^/search/(.+)} ) {
		$details{search} = $1;
	}
	my $start_time = setting('start_time');

	if ($start_time) {
		$details{elapsed_time} = Time::HiRes::time - $start_time;
	}

	# TODO if there are entries in the session, move them to the database
	if (logged_in) {
		$details{uid} = session('uid');
	}

	log_to_mongodb( \%details );

	return if response->status != 200;
	return if $uri =~ m{^/atom};
	return if $uri =~ m{^/robots.txt};

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
	return if not mymaven->{mongodb_logging};

	eval {
		my $client     = MongoDB::MongoClient->new( host => 'localhost', port => 27017 );
		my $database   = $client->get_database('PerlMaven');
		my $collection = $database->get_collection('logging');
		$collection->insert($data);
	};
	error("Could not log to MongoDB: $@") if $@;
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

