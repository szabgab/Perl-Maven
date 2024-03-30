use strict;
use warnings;
use 5.010;
use lib 'lib';
use Cwd            qw(abs_path);
use File::Basename qw(dirname);
use Getopt::Long   qw(GetOptions);
use Perl::Maven::Monitor;

my %opt;
GetOptions( \%opt, 'limit=i', 'hours=i', 'conf=s', 'fetch:s', 'report:s', 'help', 'file=s', 'recent:i', 'verbose' )
	or usage();
usage() if delete $opt{help};
usage() unless ( defined $opt{fetch} or defined $opt{report} or defined $opt{recent} );

my $root = dirname dirname abs_path($0);

my $monitor = Perl::Maven::Monitor->new( root => $root, %opt );

if ( defined $opt{fetch} ) {
	$monitor->fetch( $opt{fetch} );
}
if ( defined $opt{report} ) {
	$monitor->report( $opt{report} );
}

if ( defined $opt{recent} ) {
	die 'Missing --file FILENAME' if not $opt{file};
	$monitor->recent( $opt{file}, $opt{recent} );
}

exit;

sub usage {
	print <<"USAGE";
Usage: $0
    --limit 100
    --hours 24       (1, 24, or 168)
    --conf path/to/config/file
    --fetch [cpan|pypi]   Get data from the pypi RSS feed or from the recent API of MetaCPAN.
    --report [cpan|pypi]  Generate alerts and send reports
    --recent [N]          Create HTML report of N most recent uploads
    --verbose             log on the screen
    --help
USAGE
	exit;
}

