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
my $count_feed  = 0;
my $MAX_INDEX   = 3;
my $MAX_FEED    = 10;
my (@index, @feed, @archive);
foreach my $p (@pages) {
	my $filename = substr(basename($p->{file}),  0, -3);
	#say "$p->{timestamp} $p->{file}";
	if ($p->{archive}) {
		push @archive, {
			title => $p->{title},
			timestamp => $p->{timestamp},
			filename  => $filename,
		}
	}
	if ($p->{index} and $p->{abstract} and $count_index++ < $MAX_INDEX ) {
		push @index, {
			title => $p->{title},
			timestamp => $p->{timestamp},
			abstract  => $p->{abstract},
			filename  => $filename,
		};
	}
	if ($p->{feed} and $p->{abstract} and $count_feed++ < $MAX_FEED ) {
		push @feed, {
			title => $p->{title},
			timestamp => $p->{timestamp},
			abstract  => $p->{abstract},
			filename  => $filename,
		};
	}

}
save ('index',   \@index);
save ('archive', \@archive);
save ('feed',    \@feed);
exit;

sub save {
	my ($file, $data) = @_;
	open my $fh, '>', "$dir/meta/$file.json" or die;
	print $fh to_json $data, { utf8 => 1, pretty => 1 };
	close $fh;
	return;
}


