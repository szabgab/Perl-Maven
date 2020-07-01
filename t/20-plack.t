use strict;
use warnings;

use Test::Most;
use Plack::Test;
use HTTP::Request::Common;
use Cwd qw(getcwd);
use Carp::Always;
use Path::Tiny;
plan tests => 19;

use t::lib::Test;
t::lib::Test::setup();

use Dancer2;    # importing: set, config

set( appdir => getcwd() );

is config->{'appdir'}, getcwd(), 'appdir';
is config->{'mymaven_yml'}, 'config/mymaven.yml', 'mymaven';

use Perl::Maven;

my $app = Dancer2->psgi_app;
is( ref $app, 'CODE', 'Got app' );

my $url = "https://$t::lib::Test::DOMAIN";

test_psgi $app, sub {
	my $cb  = shift;
	my $res = $cb->( GET $url );
	is $res->code, 200, "code 200 for GET $url";
	like( $res->content, qr{<title>Perl Maven - for people who want to get the most out of programming in Perl</title>},
		'main page' );
};

test_psgi $app, sub {
	my $cb = shift;

	my $res = $cb->( GET "$url/robots.txt" );
	is $res->code, 200, "code 200 for GET $url/robots.txt";

	is $res->content, <<"END", 'content';
Sitemap: $url/sitemap.xml

User-agent: *
Disallow: /media/*
END

	my $favicon = $cb->( GET "$url/favicon.ico" );
	is $favicon->code, 200, "code 200for GET $url/favicon.ico";
	is $favicon->content, Path::Tiny::path('t/files/images/favicon.ico')->slurp, 'content';

	foreach my $path (qw(atom rss tv/atom sitemap.xml)) {
		my $res = $cb->( GET "$url/$path" );
		is $res->code, 200, "code 200 for GET $url/$path";
	}
	my $css = $cb->( GET "$url/css/style.css" );
	is $css->code, 200, "code 200 for GET $url/css/style.css";
	is $css->content, Path::Tiny::path('public/css/style.css')->slurp, 'content';

	my $feed_icon = $cb->( GET "$url/img/feed-icon16x16.png" );
	is $feed_icon->code, 200, "code 200 for GET $url/img/feed-icon16x16.png";
	is $feed_icon->content, Path::Tiny::path('t/files/images/feed-icon16x16.png')->slurp, 'content';

	my $perl_maven = $cb->( GET "$url/img/perl_maven_150x212.png" );
	is $perl_maven->code, 200, "code 200 for GET $url/img/perl_maven_150x212.png";
	is $perl_maven->content, Path::Tiny::path('t/files/images/perl_maven_150x212.png')->slurp, 'content';
};

