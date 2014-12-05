package t::lib::Test;
use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw(read_file psgi_start);

use File::Basename qw(basename);
use File::Temp qw(tempdir);

use Perl::Maven::DB;

sub setup {
	my $dir = tempdir( CLEANUP => 1 );

	unlink glob 'sessions/*';

	my $dbfile = "$dir/pm.db";
	$ENV{PERL_MAVEN_DB} = $dbfile;

	system "$^X bin/setup.pl $dbfile" and die;
	my $db = Perl::Maven::DB->new($dbfile);

	$db->add_product( 'perl_maven_cookbook',       'Perl Maven Cookbook',        0 );
	$db->add_product( 'beginner_perl_maven_ebook', 'Beginner Perl Maven e-book', 0.01 );
}

sub psgi_start {

	my ($cnt) = split /_/, basename $0;

	$ENV{MYMAVEN_YML} = 't/files/test.yml';

	setup();
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

