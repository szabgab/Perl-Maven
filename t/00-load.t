use strict;
use warnings;

use Test::Most;
use Test::Script;

my @scripts = qw(
	app.psgi
);

plan tests => 1 + @scripts;

use Perl::Maven::Config;
use Perl::Maven::Page;
use Perl::Maven::Tools;
use Perl::Maven::WebTools;

pass;

foreach my $script (@scripts) {
	script_compiles($script);
}
