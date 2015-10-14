use 5.010;
use strict;
use warnings;

# Script to be used to check the source of the 4 sec or so we need to give a response

# perl -d:NYTProf  t/load.pl
# nytprofhtml --open

BEGIN {
	$ENV{HTTP_HOST} = 'http://perlmaven.com/';
}

use Plack::Test;
use HTTP::Request::Common qw(GET);
use Path::Tiny qw(path);

my $app  = do 'app.psgi';
my $test = Plack::Test->create($app);
my $res  = $test->request( GET 'http://perlmaven.com/' );    # HTTP::Response

#my $res = $test->request(GET '/'); # HTTP::Response

say 'ERROR: code is     ' . $res->code . ' instead of 200'   if $res->code != 200;
say 'ERROR: messages is ' . $res->message . ' instead of OK' if $res->message ne 'OK';
say 'ERROR: incorrect content'                               if $res->content !~ m{<h2>Perl tutorials and courses</h2>};

#say $res->content;

#use Data::Dumper qw(Dumper);
##diag explain [ $res->headers->header_field_names ];
#is $res->header('Content-Length'), length $main;
#is $res->header('Content-Type'), 'text/html; charset=utf-8';
#diag $res->header('Last-Modified');

