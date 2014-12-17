use strict;
use warnings;

use Test::More;
use Test::Script;

my @scripts = qw(
	bin/admin.pl
	app.psgi
	bin/cpan_monitor.pl
	bin/create_meta.pl
	bin/remove_sessions.pl
	bin/sendmail.pl
	bin/setup.pl
	bin/update_sessions.pl
);

plan tests => 1 + @scripts;

use Perl::Maven::Admin;
use Perl::Maven::Config;
use Perl::Maven::DB;
use Perl::Maven::CreateMeta;
use Perl::Maven::Page;
use Perl::Maven::PayPal;
use Perl::Maven::SVG;
use Perl::Maven::Sendmail;
use Perl::Maven::Tools;
use Perl::Maven::WebTools;

pass;

foreach my $script (@scripts) {
	script_compiles($script);
}
