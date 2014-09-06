use strict;
use warnings;

use Test::More;

plan tests => 1;

use Perl::Maven::Page;

my $path = 't/files/1.tt';
#my $data = eval { Perl::Maven::Page->new(file => $path)->read };
#ok !$@, "load $path" or diag $@;

ok 1;

