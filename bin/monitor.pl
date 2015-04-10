use strict;
use warnings;
use 5.010;
use lib 'lib';
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use Getopt::Long qw(GetOptions);
use Perl::Maven::Monitor;

my %opt;
GetOptions( \%opt, 'limit=i', 'hours=i', 'conf:s', 'fetch:s', 'help', ) or usage();
usage() if delete $opt{help};

my $root = dirname dirname abs_path($0);

my $monitor = Perl::Maven::Monitor->new( root => $root, %opt );

if ( defined $opt{fetch} ) {
	$monitor->fetch( $opt{fetch} );
	exit;
}

$monitor->run;
exit;

sub usage {
	print <<"USAGE";
Usage: $0
    --limit 1000
    --hours 24       (1, 24, or 168)
    --conf path/to/config/file
    --fetch [cpan|pypi]   Get data from the pypi RSS feed or from the recent API of MetaCPAN.
    --help
USAGE
	exit;
}
