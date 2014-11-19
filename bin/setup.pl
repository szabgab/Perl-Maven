use strict;
use warnings;
use 5.010;

use lib 'lib';

use Perl::Maven::DB;

my $dbfile = shift // 'pm.db';
my $db = Perl::Maven::DB->setup($dbfile);

