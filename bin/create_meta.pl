#!/usr/bin/env perl
use strict;
use warnings;
use v5.10;

#use Cwd qw(abs_path);
use File::Basename qw(basename);
use Data::Dumper qw(Dumper);
use JSON qw(to_json);

use lib 'lib';
use Perl::Maven::Page;

my @pages;
my $dir = '/home/gabor/work/articles'; #dirname dirname dirname abs_path $0;
foreach my $file (glob "$dir/*.tt") {
	#say "Reading $file";
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

@pages = sort { $b->{timestamp} cmp $a->{timestamp} } grep { $_->{status} eq 'show' } @pages;

my $count_index = 0;
my $count_rss   = 0;
my $MAX_INDEX   = 3;
my $MAX_RSS     = 10;
my (@index, @rss);
foreach my $p (@pages) {
	#say "$p->{timestamp} $p->{file}";
	if ($p->{index} and $p->{abstract} and $count_index++ < $MAX_INDEX ) {
		push @index, {
				title => $p->{title},
				timestamp => $p->{timestamp},
				abstract  => $p->{abstract},
				filename  => substr(basename($p->{file}),  0, -3),
			};
	}
}
save ('index', \@index);


sub save {
	my ($file, $data) = @_;
	open my $fh, '>', "$dir/meta/$file.json" or die;
	print $fh to_json $data, { utf8 => 1, pretty => 1 };
	close $fh;
	return;
}

# create a file for tha archive list (date, title, filename)  (all the file that are 'show' and 'archive')
# create a file for the rss feed ( dare, title, abstract, filename )  (the K most recent pages that are 'show', 'rss', and have 'abstract' )

