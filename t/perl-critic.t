use strict;
use warnings;

use Test::More;
use Perl::Critic;
use Test::Perl::Critic;

# NOTE: New files will be tested automatically.

# FIXME: Things should be removed (not added) to this list.
# Temporarily skip any files that existed before adding the tests.
# Eventually these should all be removed (once the files are cleaned up).
my %skip = map { ( $_ => 1 ) } qw(
	lib/Perl/Maven.pm

	bin/admin.pl
	bin/app.pl
	bin/convert.pl
	bin/cpan_monitor.pl
	bin/create_meta.pl
	bin/delete_user.pl
	bin/dump.pl
	bin/pod2maven.pl
	bin/remove_sessions.pl
	bin/sendmail.pl
	bin/setup.pl
	bin/tool.pl

	t/001-tools.t
	t/002-config.t
	t/002-pages.t
	t/003_perl_maven.t
	t/004_admin.t
	t/005_paypal.t
	t/lib/Test.pm
	t/perl-critic.t
	t/tidyall.t
);

my @files = grep { !$skip{$_} }
	( Perl::Critic::Utils::all_perl_files(qw( bin lib t )) );

foreach my $file (@files) {
	critic_ok( $file, $file );
}

done_testing();
