use strict;
use warnings;

use t::lib::Test qw(start);

use Cwd qw(abs_path);
use Data::Dumper qw(Dumper);
#use JSON qw(from_json);

my $run = start();

eval "use Test::More";
eval "use Test::Deep";
require Test::WWW::Mechanize;
plan( skip_all => 'Unsupported OS' ) if not $run;

my $url = "http://localhost:$ENV{PERL_MAVEN_PORT}";
my $URL = "$url/";

#diag($url);
#sleep 30;
plan( tests => 4 );

my $w = Test::WWW::Mechanize->new;
$w->get_ok($URL);
$w->content_like(qr/Perl Maven/);

$w->get_ok("$url/login");
$w->content_like(qr/Login/);

