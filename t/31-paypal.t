use strict;
use warnings;

use t::lib::Test;

use Cwd qw(abs_path getcwd);
use File::Basename qw(basename);
use Data::Dumper qw(Dumper);

use Test::More;
use Test::Deep;
use Test::WWW::Mechanize::PSGI;

t::lib::Test::setup();

my $articles = '../articles';

my $url = 'http://test-perl-maven.com';

plan( tests => 4 );

use Dancer2;    # set

set( appdir => getcwd() );
use Perl::Maven;

my $app = Dancer2->psgi_app;

my $w = Test::WWW::Mechanize::PSGI->new( app => $app );

$w->get_ok("$url/buy?product=beginner_perl_maven_ebook");
$w->content_like(qr{Before making a purchase, please});
$w->content_unlike(qr{Beginner Perl Maven e-book});
$w->content_unlike(qr{Price 32 USD});

