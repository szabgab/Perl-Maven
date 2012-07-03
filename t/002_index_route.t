use Test::More tests => 4;
use strict;
use warnings;

use File::Copy qw(move);
use Cwd qw(cwd);
my $backup;
BEGIN {
	my $t = time;
	if (-e 'pm.db') {
		$backup = "pm.db.$t";
		move 'pm.db', $backup;
	}
	system "$^X bin/convert.pl" and die;
	system "$^X bin/convert2.pl" and die;
}

END {
	if ($backup) {
		move $backup, 'pm.db';
	}
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



