#!/usr/bin/env perl
use strict;
use warnings;
use v5.10;

use File::Basename qw(basename dirname);
use Getopt::Long qw(GetOptions);
use YAML::XS qw(LoadFile);

use lib 'lib';
use Perl::Maven::Config;
use Perl::Maven::CreateMeta;

binmode( STDOUT, ':encoding(UTF-8)' );
binmode( STDERR, ':encoding(UTF-8)' );

# Run with any value on the command line to get debugging info

GetOptions(
	'verbose'  => \my $verbose,
	'books'    => \my $books,
	'help'     => \my $help,
	'config=s' => \my $config,

	#	'all'      => \my $all,
);
usage() if $help;
$ENV{METAMETA} = 1;

$config ||= 'config.yml';

my $cfg     = LoadFile($config);
my $mymaven = Perl::Maven::Config->new( $cfg->{mymaven_yml} );

foreach my $domain_name ( sort keys %{ $mymaven->{config}{domains} } ) {
	my $meta = Perl::Maven::CreateMeta->new(
		verbose => $verbose,
		mymaven => $mymaven,
		books   => $books,
	);
	$meta->process_domain($domain_name);
}

#if ($all) {
#	for my $domain_name ( keys %{ $mymaven->{config} } ) {
#		my $meta = Perl::Maven::CreateMeta->new(
#			verbose => $verbose,
#			mymaven => $mymaven,
#		);
#		$meta->process_domain($domain_name);
#	}
#}
#else {
#	usage('Missing domain') if not $domain_name;
#	usage("Invalid site '$domain_name'")
#		if not $mymaven->{config}{$domain_name};
#	my $meta = Perl::Maven::CreateMeta->new(
#		verbose => $verbose,
#		mymaven => $mymaven,
#	);
#	$meta->process_domain($domain_name);
#}

exit;
###############################################################################
sub usage {
	my ($msg) = shift || '';

	print "*** $msg\n\n";
	print "Usage $0\n";
	print "         --verbose\n";
	print "         --books\n";
	print "         --help\n";
	exit;
}

