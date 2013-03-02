#!/usr/bin/env perl
use strict;
use warnings;
use v5.10;

#use Cwd qw(abs_path);
use File::Basename qw(basename dirname);
use Cwd qw(abs_path);
use Data::Dumper qw(Dumper);
use JSON qw(to_json);

use lib 'lib';
use Perl::Maven::Page;

#my $dir = '/home/gabor/work/articles';
my $dir = dirname(dirname dirname abs_path $0) . '/articles';
my $pages = get_pages();

my ($keywords, $index, $archive, $feed) = process_files($pages);
save ('index',   $index);
save ('archive', $archive);
save ('feed',    $feed);
save ('keywords', $keywords);
exit;
###############################################################################

sub process_files {
	my ($pages) = @_;

	my $count_index = 0;
	my $count_feed  = 0;
	my $MAX_INDEX   = 3;
	my $MAX_FEED    = 10;

	# TODO:
	# I think =indexes are supposed to be Perl keywords while =tags contain concepts that users
	# might want to search for. Or the other way around.

	my %keywords; # =indexes and =tags are united here
	my (@index, @feed, @archive);

	foreach my $p (@$pages) {
		my $filename = substr(basename($p->{file}),  0, -3);

		foreach my $f (qw(indexes tags)) {
			next if not $p->{$f};
			my @words = split /,\s*/, $p->{$f};
			foreach my $w (@words) {
				#$keywords{$w} ||= {};
				warn "Duplicate '$w' in '$filename'\n" if $keywords{$w}{$filename};
				$keywords{$w}{$filename} = $p->{title}
			}
		}

		#say "$p->{timestamp} $p->{file}";
		if ($p->{archive}) {
			my ($date) = split /T/, $p->{timestamp};
			push @archive, {
				title => $p->{title},
				timestamp => $p->{timestamp},
				date      => $date,
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
				author    => $p->{author},
			};
		}

	}

	return (\%keywords, \@index, \@archive, \@feed);
}

sub save {
	my ($file, $data) = @_;
	my $path = "$dir/meta/$file.json";
	open my $fh, '>', $path or die "Could not open '$path'\n";
	print $fh to_json $data, { utf8 => 1, pretty => 1 };
	close $fh;
	return;
}

sub get_pages {
	my @pages;
	foreach my $file (glob "$dir/*.tt") {
		#say "Reading $file";
		my $data = Perl::Maven::Page->new(file => $file)->read;
		foreach my $field (qw(timestamp title status)) {
			die "No $field in $file" if not $data->{$field};
		}
		die "Invalid status $data->{status} in $file"
			if $data->{status} !~ /^(show|hide|draft|ready)/;

		push @pages, {
				file  => $file,
				%$data,
		};
	}

	#die Dumper $pages[0];
	#die  Dumper [ keys %{$pages[0]} ];

	@pages = sort { $b->{timestamp} cmp $a->{timestamp} } grep { $_->{status} eq 'show' } @pages;

	return \@pages;
}

# vim:noexpandtab

