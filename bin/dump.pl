use strict;
use warnings;
use DBI;

# if e-mail or part of e-mail is provided then the info about that user
# is printed

my ($email) = @ARGV;

use lib 'lib';

use Perl::Maven::DB;
my $db = Perl::Maven::DB->new('pm.db');

$db->dump($email);

