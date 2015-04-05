use strict;
use warnings;
use 5.010;
use lib 'lib';
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use Perl::Maven::Monitor;
my $root = dirname dirname abs_path($0);
Perl::Maven::Monitor->new( root => $root )->run;

