use Test::More tests => 4;
use strict;
use warnings;

use File::Copy qw(move);
use Cwd qw(cwd);
use t::lib::Test;
BEGIN {
    t::lib::Test::setup();
}


# the order is important
use Perl::Maven;
use Dancer::Test;

{
	my $dr = dancer_response('GET' => '/');
	is $dr->{status}, 200, 'status /';
	like $dr->{content}, qr{Perl 5 Maven}, 'content of /';
}

{
	my $dr = dancer_response('GET' => '/login');
	is $dr->{status}, 200, 'status /';
	like $dr->{content}, qr{Perl 5 Maven}, 'content of /';
}



