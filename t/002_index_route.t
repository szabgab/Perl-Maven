use Test::More tests => 2;
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
}

END {
	if ($backup) {
		move $backup, 'pm.db';
	}
}


# the order is important
use Perl::Maven;
use Dancer::Test;


route_exists [GET => '/'], 'a route handler is defined for /';
response_status_is ['GET' => '/'], 200, 'response status is 200 for /';
