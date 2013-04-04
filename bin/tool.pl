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
GetOptions(\%opt,
	'help',
	'root=s',
	'cpan=s',
	'update',
	'module=s',
) or usage();
usage() if $opt{help};


my $tool = Perl::Maven::Tool->new( %opt );
if ($opt{update}) {
	$tool->get_index_files;
	exit;
}
if ($opt{module}) {
	$tool->show_module_status($opt{module});
	exit;
}


sub usage {
	die <<"END_USAGE";
Usage: $0
    --help                   this help
    --root PATH              to directory where the distributions are saved. $opt{root}
    --cpan URL               to your selected CPAN   $opt{cpan}
	--module Module::Name    show module status

    --update       update the index file from cpan
END_USAGE
}
