use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Cwd qw(getcwd);
use Carp::Always;

use t::lib::Test qw(psgi_start);
psgi_start();

use Dancer qw(:tests);

#set log => 'warning';
#set startup_info => 0;
Dancer::set( appdir => getcwd() );

is Dancer::config->{'appdir'}, getcwd(), 'appdir';
is Dancer::config->{'mymaven'}, 'mymaven.yml', 'mymaven';

use Perl::Maven;

my $app = Dancer::Handler->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
	my $cb = shift;
	like(
		$cb->( GET 'http://perlmaven.com/' )->content,
		qr{<title>Perl Maven - for people who want to get the most out of programming in Perl</title>},
		'main page'
	);
};

done_testing;
