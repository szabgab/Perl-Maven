#!/usr/bin/perl
use strict;
use warnings;

# The tool to manage CPAN distributions (see README for the plans)

use Getopt::Long qw(GetOptions);
use Perl::Maven::Tool;

my %opt = (
	root => '/home/gabor/work/articles/cpan',
	cpan => 'http://cpan.pair.com/',
);
usage() if not @ARGV;
GetOptions( \%opt, 'help', 'root=s', 'cpan=s', 'update=s', 'dist=s', )
	or usage();
usage() if $opt{help};

my $tool = Perl::Maven::Tool->new(%opt);
if ( $opt{update} ) {
	$tool->get_distro( $opt{update} );
	exit;
}
if ( $opt{dist} ) {
	$tool->show_distro_status( $opt{dist} );
	exit;
}

sub usage {
	die <<"END_USAGE";
Usage: $0
    --help                   this help
    --root PATH              to directory where the distributions are saved. $opt{root}
    --cpan URL               to your selected CPAN   $opt{cpan}
    --dist Distro-Name       show distribution status

    --update       update the index file from cpan
END_USAGE
}
