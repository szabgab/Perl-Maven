use strict;
use warnings;

use Test::More;
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

my $url = "http://$t::lib::Test::DOMAIN";

test_psgi $app, sub {
	my $cb  = shift;
	my $res = $cb->( GET $url );
	is $res->code, 200;
	like( $res->content, qr{<title>Perl Maven - for people who want to get the most out of programming in Perl</title>},
		'main page' );
};

test_psgi $app, sub {
	my $cb = shift;

	my $res = $cb->( GET "$url/robots.txt" );
	is $res->code,    200;
	is $res->content, <<"END";
Sitemap: $url/sitemap.xml
Disallow: /media/*
END

	my $favicon = $cb->( GET "$url/favicon.ico" );
	is $favicon->code,    200;
	is $favicon->content, Path::Tiny::path('public/favicon.ico')->slurp;

	foreach my $path (qw(atom rss tv/atom sitemap.xml)) {
		my $res = $cb->( GET "$url/$path" );
		is $res->code, 200;
	}
	my $css = $cb->( GET "$url/css/style.css" );
	is $css->code,    200;
	is $css->content, Path::Tiny::path('public/css/style.css')->slurp;

	my $feed_icon = $cb->( GET "$url/img/feed-icon16x16.png" );
	is $feed_icon->code,    200;
	is $feed_icon->content, Path::Tiny::path('t/files/images/feed-icon16x16.png')->slurp;

	my $perl_maven = $cb->( GET "$url/img/perl_maven_150x212.png" );
	is $perl_maven->code,    200;
	is $perl_maven->content, Path::Tiny::path('t/files/images/perl_maven_150x212.png')->slurp;
};

