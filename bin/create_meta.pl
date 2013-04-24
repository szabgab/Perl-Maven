#!/usr/bin/env perl
use strict;
use warnings;
use v5.10;

use File::Basename qw(basename dirname);
use File::Find::Rule;
use File::Path     qw(mkpath);
use Getopt::Long   qw(GetOptions);
use Data::Dumper   qw(Dumper);
use JSON           qw(to_json);
use YAML           qw(LoadFile);

use lib 'lib';
use Perl::Maven::Page;
use Perl::Maven::Config;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
my $MAX_INDEX   = 3;
my $MAX_FEED    = 10;
my $MAX_META_FEED = 20;

# Run with any value on the command line to get debugging info

my $cfg = LoadFile('config.yml');
my $mymaven = Perl::Maven::Config->new($cfg->{mymaven});

GetOptions(
	'domain=s' => \my $domain_name,
	'verbose'  => \my $verbose,
	'all'      => \my $all,
);

if ($all) {
	process_domain($_) for keys %{ $mymaven->{config} };
} else {
	usage('Missing domain') if not $domain_name;
	usage("Invalid site '$domain_name'") if not $mymaven->{config}{$domain_name};
	process_domain($domain_name);
}


exit;
###############################################################################

sub process_domain {
	my ($domain) = @_;
	print "** Processing domain $domain\n";

	my $config =$mymaven->config($domain);

	my %translations;
	my @latest;

	my $sites = LoadFile("$config->{root}/sites.yml");

	foreach my $lang (keys  %$sites) {
		my $orig = process($config, $domain, $lang, \@latest);
		foreach my $trans (keys %$orig) {
			$translations{ $orig->{$trans} }{$lang} = $trans;
		}

		my @meta_feed;
		my $feed_cnt = 0;
		for my $entry (reverse sort { $a->{timestamp} cmp $b->{timestamp} } @latest) {
			$feed_cnt++;
			push @meta_feed, $entry;
			last if $feed_cnt >= $MAX_META_FEED;
		}
		save('feed', "$config->{meta}/meta.$domain/meta", \@meta_feed);
	}
	save('translations', "$config->{meta}", \%translations);
}

sub process {
	my ($config, $domain, $lang, $latest) = @_;

	my $site = ($lang eq 'en' ? '' : "$lang.") . $domain;
	my $source = $config->{root} . '/sites/' . $lang . '/pages';
	my $dest   = $config->{meta} . "/$site/meta";
	return if $dest =~ /^c:/;

	usage("Missing source for $lang") if not -e $source;

	mkpath $dest;
	usage("Missing meta for $lang") if not -e $dest;

	my @sources = (
			{
				path => $source,
				uri  => '',
			},
	);
	my $perldoc = $config->{sites}{$site}{dirs}{perldoc};
	if ($perldoc) {
		push @sources,
			{
				path => $perldoc,
				uri  => 'perldoc/',
			};
	}

	my $pages = get_pages(@sources);


	my ($keywords, $index, $archive, $feed, $sitemap, $originals) = process_files($pages);
	save('index',    $dest, $index);
	save('archive',  $dest, $archive);
	save('feed',     $dest, $feed);
	save('keywords', $dest, $keywords);
	save('sitemap',  $dest, $sitemap);
	push @$latest, map { $_->{site} = $site; $_ } @$feed;

	return $originals;
}

sub process_files {
	my ($pages) = @_;

	my $count_index = 0;
	my $count_feed  = 0;

	# TODO:
	# I think =indexes are supposed to be Perl keywords while =tags contain concepts that users
	# might want to search for. Or the other way around.

	my %keywords; # =indexes and =tags are united here
	my (@index, @feed, @archive, @sitemap);
	my %originals;

	foreach my $p (@$pages) {
		my $filename = substr($p->{url_path},  0, -3);
		if ($verbose) {
			say "Processing $filename";
		}
		if ($p->{original}) {
			$originals{ substr($p->{url_path}, 0, -3) } =  $p->{original};
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

		# TODO what to do when there is no abstract might need some configuration
		# let's put the title in the abstract for now.
		#$p->{abstract} ||= $p->{title};
		#$p->{abstract} ||= ' ';
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

	return (\%keywords, \@index, \@archive, \@feed, \@sitemap, \%originals);
}

sub save {
	my ($file, $dest, $data) = @_;

	mkpath $dest;
	die "'$dest' does not exist" if not -d $dest;
	my $path = "$dest/$file.json";
	open my $fh, '>encoding(UTF-8)', $path or die "Could not open '$path' $!";
	print $fh to_json $data, { utf8 => 1, pretty => 1, canonical => 1 };
	close $fh;
	return;
}

sub get_pages {
	my @sources = @_;

	my @pages;
	foreach my $s (@sources) {
		die Dumper $s if not $s->{path};
		say $s->{path};
		foreach my $file (File::Find::Rule->file()->name('*.tt')->relative()->in($s->{path})) {
			say "Reading $file" if $verbose;
			my $path = "$s->{path}/$file";
			my $data = Perl::Maven::Page->new(file => $path)->read;
			foreach my $field (qw(timestamp title status)) {
				die "No $field in $path" if not $data->{$field};
			}
			die "Invalid status $data->{status} in $file"
				if $data->{status} !~ /^(show|hide|draft|ready)/;

			push @pages, {
					file  => $file,
					url_path => $s->{uri} . $file,
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

sub usage {
	my ($msg) = @_;

	print "*** $msg\n\n";
	print "Usage $0\n";
	print "         --domain DOMAIN\n";
	print "         --all             all the domains\n";
	print "         --verbose\n";
	print "The domains:\n";
	foreach my $domain (keys %{ $mymaven->{config} }) {
		print "  $domain\n";
	}
	exit;
}


# vim:noexpandtab

