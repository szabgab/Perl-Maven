package t::lib::Test;
use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw(read_file);

use File::Temp qw(tempdir);

use Perl::Maven::DB;

# this needs to match what we have in
#    t/files/test/sites.yml
# and in
#    t/files/config/test.yml
our $DOMAIN = 'test-pm.com';
our $URL    = "https://$DOMAIN/";

sub setup {
	my $dir = tempdir( CLEANUP => 1 );
	$ENV{MYMAVEN_YML} = 't/files/config/test.yml';

	unlink glob 'sessions/*';

	my $dbfile = "$dir/test_abc.db";
	$ENV{PERL_MAVEN_DB} = $dbfile;

	system "$^X bin/setup.pl $dbfile" and die;
	my $db = Perl::Maven::DB->new($dbfile);

	$db->add_product( { code => 'some_free_product',         name => 'Perl Maven Cookbook',        price => 0 } );
	$db->add_product( { code => 'beginner_perl_maven_ebook', name => 'Beginner Perl Maven e-book', price => 0.01 } );

	system "$^X bin/create_meta.pl" and die;
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

