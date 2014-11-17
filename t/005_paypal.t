use strict;
use warnings;

use t::lib::Test qw(psgi_start read_file);

use Cwd qw(abs_path getcwd);

#use File::Basename qw(basename);
use Data::Dumper qw(Dumper);

my $run = psgi_start();

my $articles = '../articles';

use Test::More;
use Test::Deep;
use Test::WWW::Mechanize::PSGI;
plan( skip_all => 'Unsupported OS' ) if not $run;

my $url = "http://perlmaven.com.local";
my $URL = "$url/";

plan( tests => 4 );

use Dancer qw(:tests);

Dancer::set( appdir => getcwd() );
use Perl::Maven;

my $app = Dancer::Handler->psgi_app;

my $w = Test::WWW::Mechanize::PSGI->new( app => $app );

$w->get_ok("$url/buy?product=beginner_perl_maven_ebook");
$w->content_like(qr{Before making a purchase, please});
$w->content_unlike(qr{Beginner Perl Maven e-book});
$w->content_unlike(qr{Price 32 USD});

