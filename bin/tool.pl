#!/usr/bin/perl
use strict;
use warnings;

# The tool to manage CPAN distributions (see README for the plans)

use Getopt::Long qw(GetOptions);
use Perl::Maven::Tool;

my %opt;
GetOptions(\%opt,
	'help',
	'root=s',
) or usage();
usage() if $opt{help};

$opt{root} = '/home/gabor/work/articles/cpan';


my $tool = Perl::Maven::Tool->new( %opt );
$tool->list;


sub usage {
	die <<"END_USAGE";
Usage: $0
    --help         this help
    --root PATH    to directory where the distributions are saved.
END_USAGE
}
