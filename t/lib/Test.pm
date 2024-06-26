package t::lib::Test;
use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw(read_file);

use File::Temp qw(tempdir);

# this needs to match what we have in
#    t/files/test/sites.yml
# and in
#    t/files/config/test.yml
our $DOMAIN = 'test-pm.com';
our $URL    = "https://$DOMAIN/";

sub setup {
	my $dir = tempdir( CLEANUP => 1 );
	$ENV{MYMAVEN_YML} = 't/files/config/test.yml';
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

