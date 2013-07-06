use strict;
use warnings;

use t::lib::Test qw(start read_file);

use Cwd qw(abs_path);
use File::Basename qw(basename);
use Data::Dumper qw(Dumper);

my $run = start();

my $articles = '../articles';

eval "use Test::More";
eval "use Test::Deep";
require Test::WWW::Mechanize;
plan( skip_all => 'Unsupported OS' ) if not $run;

my $url = "http://perlmaven.com.local:$ENV{PERL_MAVEN_PORT}";
my $URL = "$url/";

plan( tests => 1 );

my $w = Test::WWW::Mechanize->new;

$w->get_ok("$url/buy?product=beginner_perl_maven_ebook");


