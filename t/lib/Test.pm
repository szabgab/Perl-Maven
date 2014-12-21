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
our $URL    = "http://$DOMAIN/";

my $db_created;

sub setup {
	my $dir = tempdir( CLEANUP => 1 );
	$ENV{MYMAVEN_YML} = 't/files/config/test.yml';

	unlink glob 'sessions/*';

	my $db = Perl::Maven::DB->new( 'PerlMaven_Test_' . time );
	$db_created = 1;

	$db->add_product( { code => 'perl_maven_cookbook',       name => 'Perl Maven Cookbook',        price => 0 } );
	$db->add_product( { code => 'beginner_perl_maven_ebook', name => 'Beginner Perl Maven e-book', price => 0.01 } );
}

END {
	if ($db_created) {
		Perl::Maven::DB->instance->{db}->drop;
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

