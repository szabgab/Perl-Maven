#!/usr/bin/env perl
use strict;
use warnings;
use v5.10;

#use Cwd qw(abs_path);
use File::Basename qw(basename dirname);
use Cwd qw(abs_path);
use Data::Dumper qw(Dumper);
use JSON qw(to_json);
use YAML qw(LoadFile);

use lib 'lib';
use Perl::Maven::Page;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

# Run with any value on the command line to get debugging info
my ($verbose) = @ARGV;

#my $config = LoadFile('config.yml');

my $dir = shift or die "Usage $0 path/to/articles\n";
#$config->{mymaven}{articles};

my $pages = get_pages();

my ($keywords, $index, $archive, $feed, $sitemap) = process_files($pages);
save ('index',   $index);
save ('archive', $archive);
save ('feed',    $feed);
save ('keywords', $keywords);
save ('sitemap', $sitemap);
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
	my (@index, @feed, @archive, @sitemap);

	foreach my $p (@$pages) {
		my $filename = substr($p->{url_path},  0, -3);
		if ($verbose) {
			say "Processing $filename";
		}

		foreach my $f (qw(indexes tags)) {
			next if not $p->{$f};
			my @words = @{ $p->{$f} };
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

		push @sitemap, {
			title => $p->{title},
			filename => ($filename eq 'index' ? '' : $filename),
			timestamp => $p->{timestamp},
		};
	}

	return (\%keywords, \@index, \@archive, \@feed, \@sitemap);
}

sub save {
	my ($file, $data) = @_;
	die "'$dir/meta' does not exist" if not -d "$dir/meta";
	my $path = "$dir/meta/$file.json";
	open my $fh, '>encoding(UTF-8)', $path or die "Could not open '$path' $!";
	print $fh to_json $data, { utf8 => 1, pretty => 1 };
	close $fh;
	return;
}

sub get_pages {
	my @pages;
	foreach my $path ('', 'perldoc') {
		foreach my $file (glob "$dir/$path/*.tt") {
			#say "Reading $file";
			my $data = Perl::Maven::Page->new(file => $file)->read;
			foreach my $field (qw(timestamp title status)) {
				die "No $field in $file" if not $data->{$field};
			}
			die "Invalid status $data->{status} in $file"
				if $data->{status} !~ /^(show|hide|draft|ready)/;

			push @pages, {
					file  => $file,
					url_path => ($path ? "$path/" : '') . basename($file),
					%$data,
			};
		}
	}

	#die Dumper $pages[0];
	#die  Dumper [ keys %{$pages[0]} ];
	my @selected;
	foreach my $p (@pages) {
		if ($p->{status} eq 'show') {
			push @selected, $p;
		} else {
			warn "No show $p->{file}";
		}
	}

	return [ sort { $b->{timestamp} cmp $a->{timestamp} } @selected ];
}

# vim:noexpandtab

