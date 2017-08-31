package Perl::Maven::CreateMeta;
use Moo;
use Path::Tiny ();
use 5.010;

our $VERSION = '0.11';

has mymaven      => ( is => 'ro' );
has verbose      => ( is => 'ro' );
has books        => ( is => 'ro' );
has meta_archive => ( is => 'ro', default => sub { [] } );
has translations => ( is => 'ro', default => sub { {} } );
has stats        => ( is => 'ro', default => sub { {} } );
has latest       => ( is => 'ro', default => sub { {} } );
has pages        => ( is => 'rw' );

use Data::Dumper qw(Dumper);
use File::Find::Rule;
use File::Path qw(mkpath);
use Cpanel::JSON::XS qw(decode_json encode_json);
use YAML::XS qw(LoadFile);
use POSIX ();

use Perl::Maven::Page;

my %ts;    # mapping timestamp => filename to ensure uniqueness

# I think this was added only to make the order of pages in the archive stable.
# In that case it should be probaby uniqueness per hostname, or better yet,
# have a secondary ordering for the archive using the filename.

sub process_domain {
	my ( $self, $domain ) = @_;

	$self->_log("** Processing domain $domain");

	my $config = $self->mymaven->config($domain);
	$self->_log("   Saving to $config->{meta}");

	my $sites = LoadFile("$config->{root}/sites.yml");

	foreach my $lang ( keys %$sites ) {
		my $lang_config = $config;
		if ( $lang ne 'en' ) {
			next if not $self->mymaven->{hosts}{"$lang.$domain"};
			$lang_config = $self->mymaven->config("$lang.$domain");
		}
		$self->process_site( $lang_config, $domain, $lang );

	}
	my @meta_archive
		= reverse sort { $a->{timestamp} cmp $b->{timestamp} } @{ $self->meta_archive };
	$self->save( 'archive', "$config->{meta}/meta.$domain/meta", \@meta_archive );
	$self->save( 'translations', "$config->{meta}", $self->translations );

	my %stats;
	$self->stats->{pagecount}{$_} ||= 0 for keys %$sites;
	foreach my $lang (
		reverse sort { $self->stats->{pagecount}{$a} <=> $self->stats->{pagecount}{$b} }
		keys %$sites
		)
	{
		$sites->{$lang}{pagecount} = $self->stats->{pagecount}{$lang};
		$sites->{$lang}{lang}      = $lang;
		$sites->{$lang}{latest}    = $self->latest->{$lang};
		push @{ $stats{sites} }, $sites->{$lang};
	}
	$self->save( 'stats', "$config->{meta}", \%stats );

	$self->consultants( $domain, $config );
}

sub process_series {
	my ( $self, $config ) = @_;

	my $series_file = $config->{'series_file'};
	$self->_log("series file: $series_file");
	return if not -e $series_file;
	my $series = LoadFile($series_file);
	my %series_map;
	if ( $self->books ) {
		mkdir 'books';
		require EBook::MOBI;
		require PDF::Create;
	}

	my $date = POSIX::strftime '%Y-%m-%d %H:%M:%S', gmtime();
	foreach my $main ( keys %$series ) {

		#next if $main ne 'dancer';
		$self->_log("Procesing series $main");
		die "This main page '$main' is already in use" if $series_map{$main};
		$series_map{$main}      = $main;
		$series->{$main}{title} = $self->pages->{$main}{title};
		$series->{$main}{url}   = "/$main";
		my $html = qq{<h1>$series->{$main}{title}</h1>\n};
		$html .= qq{<p>Generated on $date</p>\n};

		my $mobi;
		my $pdf;
		my %PDF;
		if ( $self->books ) {
			my $author = 'Gabor Szabo';

			say "books/$main.pdf";
			$pdf = PDF::Create->new(
				'filename'     => "books/$main.pdf",
				'Author'       => $author,
				'Title'        => $series->{$main}{title},
				'CreationDate' => [localtime],
			);
			$PDF{title_font} = $pdf->font( 'BaseFont' => 'Helvetica' );
			$PDF{root} = $pdf->new_page( 'MediaBox' => $pdf->get_page_size('A4') );
			$PDF{page} = $PDF{root}->new_page;

			$mobi = EBook::MOBI->new();
			$mobi->set_author($author);
			$mobi->set_encoding(':encoding(UTF-8)');
			$mobi->set_filename("books/$main.mobi");
			$mobi->add_toc_once();
			$mobi->set_title( $series->{$main}{title} );
			$mobi->add_pagebreak();

			$mobi->add_mhtml_content($html);
			$mobi->add_pagebreak();
		}

		foreach my $chapter ( @{ $series->{$main}{chapters} } ) {
			$html .= qq{<h2>$chapter->{title}</h2>\n};
			if ( $self->books ) {
				$mobi->add_mhtml_content(qq{<h1>$chapter->{title}</h1>\n});
				$PDF{page} = $PDF{page}->new_page;
				$PDF{page}->stringc( $PDF{title_font}, 40, 306, 850, $chapter->{title} );
			}
			foreach my $i ( 0 .. @{ $chapter->{sub} } - 1 ) {
				die "This page '$chapter->{sub}[$i]' is already in use" if $series_map{ $chapter->{sub}[$i] };
				$series_map{ $chapter->{sub}[$i] } = $main;
				my $page = $self->pages->{ $chapter->{sub}[$i] };
				if ( not $page ) {
					die "Page Not found: '$chapter->{sub}[$i]'";
				}
				$chapter->{sub}[$i] = {
					url   => "/$chapter->{sub}[$i]",
					title => $page->{title},
				};

				#die join ' ', keys %$page;
				$html .= qq{<hr>\n};
				$html .= qq{<h3>$page->{title}</h3>\n};
				$html .= qq{$page->{abstract}\n};
				$html .= qq{$page->{mycontent}\n};

				if ( $self->books ) {
					$mobi->add_mhtml_content(qq{<h1>$page->{title}</h1>});
					$mobi->add_mhtml_content( _clean_html( $config, $page->{abstract} ) );
					$mobi->add_mhtml_content( _clean_html( $config, $page->{mycontent} ) );
					$mobi->add_pagebreak();
				}

			}

			if ( $self->books ) {
				$mobi->add_pagebreak();
			}
		}
		if ( $self->books ) {
			Path::Tiny::path("books/$main.html")->spew_utf8($html);
			Path::Tiny::path("books/$main.mhtml")->spew_utf8( $mobi->print_mhtml('return') );
			$mobi->make();
			$mobi->save();

			$pdf->close;
		}

	}
	return ( $series, \%series_map );
}

sub process_site {
	my ( $self, $config, $domain, $lang ) = @_;

	my $site   = ( $lang eq 'en' ? '' : "$lang." ) . $domain;
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
			autotags => $dir,
			path     => $path,
			uri      => "$dir/",
			};
	}

	my $pages = $self->get_pages( $config, @sources );

	my ( $keywords, $archive, $sitemap, $categories )
		= $self->process_files( $domain, $pages, $config->{extra_index}, $lang );
	$self->save( 'categories', $dest, $categories );
	$self->save( 'archive',    $dest, $archive );
	$self->save( 'keywords',   $dest, $keywords );
	my %kw;
	foreach my $entry (@$archive) {
		foreach my $tag ( @{ $entry->{tags} } ) {
			my $key = lc $tag;
			$key =~ s/ +/_/g;
			$key =~ s/-/_/g;
			push @{ $kw{$key} }, $entry;
		}
	}
	foreach my $tag ( sort keys %kw ) {
		$self->save( "rss_$tag", $dest, $kw{$tag} );
	}
	$self->save( 'sitemap', $dest, $sitemap );
	push @{ $self->meta_archive }, map { $_->{url} = "http://$site"; $_ } @$archive;

	#$self->pages( { map { substr( $_->{file}, 0, -4 ) => $_ } @$pages } );
	$self->pages( { map { substr( $_->{url_path}, 0, -4 ) => $_ } @$pages } );

	if ( $lang eq 'en' ) {
		if ( $config->{series_file} ) {
			my ( $series, $series_map ) = $self->process_series($config);
			if ($series) {
				$self->save( 'series',        $dest, $series );
				$self->save( 'lookup_series', $dest, $series_map );
			}
		}
	}

	return;
}

sub _log {
	my ( $self, $txt ) = @_;
	if ( $self->verbose ) {
		say $txt;
	}
	return;
}

sub process_files {
	my ( $self, $domain, $pages, $extra_index, $lang ) = @_;

	# TODO:
	# =indexes are supposed to be mostly Perl keywords and other concepts
	#    people might search for
	# =tags contain concepts that we will want to categorize on

	my %keywords;    # =indexes and =tags are united here
	my ( @archive, @sitemap, %categories );

	if ($extra_index) {

		#die Dumper $extra_index;
		foreach my $path (@$extra_index) {
			my $data = decode_json Path::Tiny::path($path)->slurp_utf8;

			#die Dumper $data;
			foreach my $key ( keys %$data ) {
				push @{ $keywords{$key} }, @{ $data->{$key} };
			}
		}
	}

	#my %SKELETON = map { $_ => 1 } qw(about.txt archive.txt index.txt keywords.txt perl-tutorial.txt products.txt);

	foreach my $p (@$pages) {
		next if $p->{redirect};
		my $filename = substr( $p->{url_path}, 0, -4 );

		#$self->_log("Processing $filename");
		if ( $p->{original} ) {
			$self->translations->{ $p->{original} }{$lang} = $filename;
		}

		if ( $ts{$domain}{ $p->{timestamp} } and $filename !~ /perldoc/ ) {
			die
				"Duplicate =timestamp '$p->{timestamp}' in $ts{$domain}{ $p->{timestamp} } and in $lang/pages/$filename\n";
		}
		$ts{$domain}{ $p->{timestamp} } = "$lang/pages/$filename";

		foreach my $f (qw(indexes tags)) {
			next if not $p->{$f};
			next if $p->{redirect};
			my @words = @{ $p->{$f} };
			foreach my $w (@words) {

				#$keywords{$w} ||= {};
				warn "Duplicate '$w' in '$filename'\n" # . Dumper $keywords{$w}
					if $keywords{$w}
					and grep { $_->{url} eq "/$filename" } @{ $keywords{$w} };
				push @{ $keywords{$w} },
					{
					url   => "/$filename",
					title => $p->{title},
					};
			}
		}

		#say "$p->{timestamp} $p->{file}";
		if ( $p->{conf}{archive} ) {
			my ($date) = split /T/, $p->{timestamp};
			if ( $p->{books} ) {

				#die Dumper $p->{books} if $p->{books};
				foreach my $cat ( @{ $p->{books} } ) {
					next if $p->{redirect};
					push @{ $categories{$cat} },
						{
						title     => $p->{title},
						timestamp => $p->{timestamp},
						date      => $date,
						filename  => $filename,
						};
				}
			}

			$self->stats->{pagecount}{$lang}++;
			my $e = {
				title     => $p->{title},
				timestamp => $p->{timestamp},
				date      => $date,
				filename  => $filename,
				abstract  => $p->{abstract},
				author    => $p->{author},
				tags      => ( $p->{tags} || [] ),
			};
			if ( $p->{redirect} ) {
				$e->{redirect} = $p->{redirect};
			}
			if ( $p->{translator} ) {
				$e->{translator} = $p->{translator};
			}
			if ( $p->{autotags} ) {
				push @{ $e->{tags} }, $p->{autotags};
			}
			for my $f (qw(mp3 img alt)) {
				if ( $p->{$f} ) {
					$e->{$f} = $p->{$f};
				}
			}
			push @archive, $e;
		}

		# TODO what to do when there is no abstract might need some configuration
		# let's put the title in the abstract for now.
		#$p->{abstract} ||= $p->{title};
		#$p->{abstract} ||= ' ';

		if ( not $p->{redirect} ) {
			push @sitemap,
				{
				title     => $p->{title},
				filename  => ( $filename eq 'index' ? '' : $filename ),
				timestamp => $p->{timestamp},
				};
		}
	}
	if (@archive) {
		$self->latest->{$lang} = $archive[0];
	}

	foreach my $k ( keys %keywords ) {
		$keywords{$k} = [ sort { $a->{title} cmp $b->{title} } @{ $keywords{$k} } ];
	}
	return ( \%keywords, \@archive, \@sitemap, \%categories );
}

sub save {
	my ( $self, $file, $dest, $data ) = @_;

	mkpath $dest;
	die "'$dest' does not exist" if not -d $dest;
	my $path = "$dest/$file.json";

	#$self->_log("Save $path");
	eval {
		Path::Tiny::path($path)->spew_utf8( encode_json($data) );
		1;
	} or do {
		my $err //= 'Unknown Error';
		die "$err when creating '$path'\n" . Dumper $data;
	};
	return;
}

sub get_pages {
	my ( $self, $config, @sources ) = @_;

	my @pages;
	foreach my $s (@sources) {
		die Dumper $s if not $s->{path};

		#$self->_log("get_pages: $s->{path}");
		foreach my $file ( File::Find::Rule->file()->name('*.txt')->relative()->in( $s->{path} ) ) {

			#$self->_log("Reading $file");
			my $path = "$s->{path}/$file";

			#$self->_log("Path $path");
			my $data = eval {
				Perl::Maven::Page->new( media => '', root => $config->{root}, file => $path )
					->read->process->merge_conf( $config->{conf} )->data;
			};
			if ($@) {
				die "Could not read '$path' $@";
			}
			foreach my $field (qw(timestamp title status)) {
				die "No $field in $path" if not $data->{$field};
			}
			die "Invalid status $data->{status} in $path"
				if $data->{status} !~ /^(show|hide|draft|done)/;

			my %p = (
				path     => $path,
				file     => $file,
				url_path => $s->{uri} . $file,
				%$data,
			);
			Dumper $p{pages};
			if ( $s->{autotags} ) {
				$p{autotags} = $s->{autotags};
			}

			# for now skip the video files
			# but we put it in the list of pages in order to verify the timestamp etc.
			if ( $file =~ m{beginner-perl/} ) {
				$p{skip} = 1;
			}

			push @pages, \%p;
		}
	}

	#die Dumper $pages[0];
	#die  Dumper [ keys %{$pages[0]} ];
	my @selected;
	foreach my $p (@pages) {
		next if $p->{skip};
		if ( $p->{status} eq 'show' ) {
			push @selected, $p;
		}
		else {
			warn "=status is $p->{status} for $p->{path}\n";
		}
	}

	return [ sort { $b->{timestamp} cmp $a->{timestamp} } @selected ];
}

sub consultants {
	my ( $self, $domain, $config ) = @_;

	return if not $config->{conf}{show_consultants};

	#die Dumper $config;
	my $list_path = $config->{dirs}{articles} . '/consultants.txt';
	$self->_log("Consultants $list_path");

	my @people;
	open my $fh, '<encoding(UTF-8)', $list_path
		or do {

		#warn "Could not open $list_path";
		return;
		};
	<$fh>;    #header
	while ( my $line = <$fh> ) {
		my %p;
		chomp $line;
		next if $line =~ m/^\s*$/;
		next if $line =~ m/^#/;
		my ( $file, $from ) = split m/;/, $line;
		my $path = $config->{root} . "/consultants/$file";
		open my $in, '<encoding(UTF-8)', $path or die "Could not open $path";

		while ( my $row = <$in> ) {
			chomp $row;
			next if $row =~ m/^\s*$/;
			my ( $key, $value ) = split /\s*:\s*/, $row, 2;
			$p{$key} = $value;
			last if $key eq 'html';
		}
		local $/ = undef;
		$p{html} = <$in>;

		#die Dumper \%p;

		push @people, \%p;
	}
	$self->save( 'consultants', $config->{meta}, \@people );
}

sub codify {
	my ($str) = @_;
	$str =~ s{^$}{}s;
	$str =~ s{^(\s*)(.*)$}{ '&nbsp;' x length($1) . $2 . '<br>'}gem;
	return "<code>\n$str\n</code>";
}

sub _clean_html {
	my ( $config, $html ) = @_;
	my $img_path = $config->{dirs}{img};

	#$html =~ s{img\s+src="/img/([^"]+)"}{img src="$img_path/$1"}g;

	# Remove images till I manage to install Image::Imlib2 and then  EBook::MOBI::Image
	$html =~ s{<img\s+src="/img/([^"]+)"\s* (\s*(alt|title)=\"[^"]*"\s*)* /?>}{}gx;
	$html =~ s{<video.*?video>}{}sg;    # remove videos
	$html =~ s{<div id="download">\s*Download:\s*</div>}{}g;

	# <span class="inline_code">cpanm --verbose Dancer</span>
	$html =~ s{<span class="inline_code">(.*?)</span>}{<b>$1</b>}sg;

	$html =~ s{<pre class="linenums">(.*?)</pre>}{codify($1)}sge;
	$html =~ s{<pre class="prettyprint linenums language-perl">(.*?)</pre>}{codify($1)}sge;
	$html =~ s{<div id="screencast">\s*</div>}{}g;
	return $html;
}

1;

