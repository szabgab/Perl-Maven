use strict;
use warnings;

use Test::More;

plan tests => 4;

use Perl::Maven::Tools;

ok !Perl::Maven::Tools::_any( 'pro', [qw(apropo other word proper compro)] );
ok Perl::Maven::Tools::_any( 'pro',  [qw(apropo other pro word)] );

ok Perl::Maven::Tools::_none( 'pro',  [qw(apropo other word proper compro)] );
ok !Perl::Maven::Tools::_none( 'pro', [qw(apropo other pro word)] );

