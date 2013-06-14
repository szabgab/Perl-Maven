package Perl::Maven::Meta;
use Moo;
use 5.010;

has mymaven => (is => 'ro');
has verbose => (is => 'ro');
has meta_archive  => (is => 'ro', default => sub { [] } );
has translations  => (is => 'ro', default => sub { {} } );
has stats         => (is => 'ro', default => sub { {} } );
has latest        => (is => 'ro', default => sub { {} } );

use Data::Dumper   qw(Dumper);
use File::Find::Rule;
use File::Path     qw(mkpath);
use JSON           qw(to_json);
use YAML           qw(LoadFile);

use Perl::Maven::Page;


my %ts; # mapping timestamp => filename to ensure uniqueness

sub process_domain {
	my ($self, $domain) = @_;

	print "** Processing domain $domain\n";

	my $config = $self->mymaven->config($domain);

	my $sites = LoadFile("$config->{root}/sites.yml");

	foreach my $lang (keys  %$sites) {
		my $lang_config = $lang eq 'en' ? $config : $self->mymaven->config("$lang.$domain");
		$self->process_site($lang_config, $domain, $lang);
	}

	my @meta_archive = reverse sort {$a->{timestamp} cmp $b->{timestamp} } @{ $self->meta_archive };
	save('archive', "$config->{meta}/meta.$domain/meta", \@meta_archive);
	save('translations', "$config->{meta}", $self->translations);

	my %stats;
	$self->stats->{pagecount}{$_} ||= 0 for keys  %$sites;
	foreach my $lang (reverse sort { $self->stats->{pagecount}{$a} <=> $self->stats->{pagecount}{$b} } keys  %$sites) {
		$sites->{$lang}{pagecount} = $self->stats->{pagecount}{$lang};
		$sites->{$lang}{lang} = $lang;
		$sites->{$lang}{latest} = $self->latest->{$lang};
		push @{ $stats{sites} }, $sites->{$lang};
	}
	save('stats',        "$config->{meta}", \%stats);
}

sub process_site {
	my ($self, $config, $domain, $lang) = @_;

	my $site = ($lang eq 'en' ? '' : "$lang.") . $domain;
	my $source = $config->{root} . '/sites/' . $lang . '/pages';
	my $dest   = $config->{meta} . "/$site/meta";
	return if $dest =~ /^c:/;

	main::usage("Missing source for $lang") if not -e $source;

	mkpath $dest;
	main::usage("Missing meta for $lang") if not -e $dest;

	my @sources = (
			{
				path => $source,
				uri  => '',
			},
	);
	foreach my $dir ( @{ $config->{index} } ) {
		my $path = $config->{dirs}{$dir};
		push @sources,
			{
				path => $path,
				uri  => "$dir/",
			};
	}

	my $pages = $self->get_pages(@sources);


	my ($keywords, $archive, $sitemap) = $self->process_files($pages, $lang);
	save('archive',  $dest, $archive);
	save('keywords', $dest, $keywords);
	save('sitemap',  $dest, $sitemap);
	push @{ $self->meta_archive }, map { $_->{url} = "http://$site"; $_ } @$archive;

	return;
}

sub process_files {
	my ($self, $pages, $lang) = @_;

	# TODO:
	# =indexes are supposed to be mostly Perl keywords and other concepts
	#    people might search for
	# =tags contain concepts that we will want to categorize on

	my %keywords; # =indexes and =tags are united here
	my (@archive, @sitemap);
	#my %SKELETON = map { $_ => 1 } qw(about.tt archive.tt index.tt keywords.tt perl-tutorial.tt products.tt);

	foreach my $p (@$pages) {
		my $filename = substr($p->{url_path},  0, -3);
		if ($self->verbose) {
			say "Processing $filename";
		}
		if ($p->{original}) {
			$self->translations->{ $p->{original} }{ $lang } = $filename;
		}

		if ($ts{ $p->{timestamp} } and $filename !~ /perldoc/) {
			die "Duplicate =timestamp '$p->{timestamp}' in $ts{ $p->{timestamp} } and in $lang/pages/$filename\n";
		}
		$ts{ $p->{timestamp} } = "$lang/pages/$filename";

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
			$self->stats->{pagecount}{$lang}++;
			my ($date) = split /T/, $p->{timestamp};
			my $e = {
				title     => $p->{title},
				timestamp => $p->{timestamp},
				date      => $date,
				filename  => $filename,
				abstract  => $p->{abstract},
				author    => $p->{author},
				tags      => ($p->{tags} || []),
			};
			push @archive, $e;
		}

		# TODO what to do when there is no abstract might need some configuration
		# let's put the title in the abstract for now.
		#$p->{abstract} ||= $p->{title};
		#$p->{abstract} ||= ' ';
		
		push @sitemap, {
			title => $p->{title},
			filename => ($filename eq 'index' ? '' : $filename),
			timestamp => $p->{timestamp},
		};
	}
	if (@archive) {
		$self->latest->{$lang} = $archive[0];
	}

	return (\%keywords, \@archive, \@sitemap);
}

sub save {
	my ($file, $dest, $data) = @_;

	mkpath $dest;
	die "'$dest' does not exist" if not -d $dest;
	my $path = "$dest/$file.json";
	open my $fh, '>encoding(UTF-8)', $path or die "Could not open '$path' $!";
	eval {
		print $fh to_json $data, { utf8 => 1, pretty => 1, canonical => 1 };
	};
	die "$@ when creating '$path'\n" . Dumper $data if $@;
	close $fh;
	return;
}

sub get_pages {
	my ($self, @sources) = @_;

	my @pages;
	foreach my $s (@sources) {
		die Dumper $s if not $s->{path};
		say $s->{path};
		foreach my $file (File::Find::Rule->file()->name('*.tt')->relative()->in($s->{path})) {
			say "Reading $file" if $self->verbose;
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


# vim:noexpandtab


1;

