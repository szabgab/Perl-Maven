#!/usr/bin/env perl
use strict;
use warnings;
use v5.10;

#use Cwd qw(abs_path);
#use File::Basename qw(dirname);
use Data::Dumper qw(Dumper);
use lib 'lib';
use Perl::Maven::Page;

my @pages;
my $dir = '/home/gabor/work/articles'; #dirname dirname dirname abs_path $0;
foreach my $file (glob "$dir/*.tt") {
	say $file;
	my $data = Perl::Maven::Page->new(file => $file)->read;
	foreach my $field (qw(timestamp title status)) {
		die "No $field in $file" if not $data->{$field};
	}
	die "Invalid status $data->{status} in $file"
		if $data->{status} !~ /^(show|hide|draft)/;
	push @pages, {
			file  => $file,
			%$data,
	};
}

#die Dumper $pages[0];
#die  Dumper [ keys %{$pages[0]} ];

@pages = sort { $b->{timestamp} cmp $a->{timestamp} } @pages;

#grep { defined $_->{abstract} and length $_->{abstract} }
foreach my $p (@pages) {
	say "$p->{timestamp} $p->{file}";
}

# probably each pages should have a timestamp
# filter for 'show',  filter for 'abstract'

# create a file for the index page (date, title, abstract, filename) (the N most recent pages that are 'show', 'index' and  have 'abstract' )
# create a file for tha archive list (date, title, filename)  (all the file that are 'show' and 'archive')
# create a file for the rss feed ( dare, title, abstract, filename )  (the K most recent pages that are 'show', 'rss', and have 'abstract' )

