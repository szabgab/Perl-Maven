package t::lib::Test;
use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw(read_file psgi_start);

use Cwd qw(cwd);
use File::Basename qw(basename);
use File::Spec;
use File::Temp qw(tempdir);
use File::Copy qw(copy move);
use DBIx::RunSQL;

my $dbfile;
my $backup;

sub setup {
	my ($dir) = @_;

	$dir //= '.';

	$dbfile = "$dir/pm.db";

	my $t = time;
	if ( -e $dbfile ) {
		$backup = "$dbfile.$t";
		move $dbfile, $backup;
	}
	system "$^X bin/setup.pl $dbfile" and die;
	my $dsn = "dbi:SQLite:dbname=$dbfile";
	DBIx::RunSQL->create(
		verbose => 0,
		dsn     => $dsn,
		sql     => 't/test.sql',
	);
}

sub psgi_start {
	my $dir = tempdir( CLEANUP => 1 );

	# print STDERR "# $dir\n";
	my ($cnt) = split /_/, basename $0;

	$ENV{MYMAVEN_YML}     = 't/files/test.yml';
	$ENV{PERL_MAVEN_TEST} = 1;
	$ENV{PERL_MAVEN_MAIL} = File::Spec->catfile( $dir, 'mail.txt' );

	setup();
}

END {
	if ($backup) {
		move $backup, $dbfile;
	}
}

sub read_file {
	my $file = shift;
	open my $fh, '<', $file or die "Could not open '$file' $!";
	local $/ = undef;
	my $cont = <$fh>;
	close $fh;
	return $cont;
}

1;

