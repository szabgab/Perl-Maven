package Perl::Maven::Page;
use Moo;

use 5.014;
use DateTime;
use Data::Dumper qw(Dumper);
use Storable qw(dclone);
use Path::Tiny;

our $VERSION = '0.11';

has root  => ( is => 'ro', required => 1 );
has file  => ( is => 'ro', required => 1 );
has tools => ( is => 'ro', required => 0 );
has data  => ( is => 'rw' );

sub read {
	my ($self) = @_;

	my %data = ( abstract => '', );
	my $cont = '';
	my $in_code;

	# ? signals an optional field
	# @ signals a multi-value, a comma-separated list of values
	# Others need to have a real value though for author we can set 0 if we don't want to provide (maybe we should
	#    require it but also have a mark if we want to show it or not?)
	my @header = qw(title timestamp author status description? indexes@? tags@? mp3@? original? books@? translator?);
	push @header,
		qw(archive? comments_disqus_enable? show_social? show_newsletter_form? show_right? show_related? show_date? redirect?);

	my %opts = (
		'?' => 'optional',
		'@' => 'multivalue',
	);
	my %fields;
	foreach my $f (@header) {
		my $c = $f;    # copy
		my %h;
		while ($c) {
			my $last = substr $c, -1;
			if ( $opts{$last} ) {
				chop $c;
				$h{ $opts{$last} } = 1;
			}
			else {
				last;
			}
		}
		$fields{$c} = \%h;
	}
	foreach my $k ( keys %data ) {
		$fields{$k} = {};
	}

	my $file = $self->file;

	if ( open my $fh, '<encoding(UTF-8)', $file ) {
		while ( my $line = <$fh> ) {
			chomp $line;
			last if $line =~ /^\s*$/;
			if ( my ( $field, $value ) = $line =~ /=([\w-]+)\s+(.*?)\s*$/ ) {
				$value //= '';

				if ( not defined $fields{$field} ) {
					die "Invalid entry in header '$field' file $file\n";
				}

				# TODO make it configurable, which fields to split?
				if ( $fields{$field}{multivalue} ) {
					$data{$field} = [
						map { my $z = $_; $z =~ s/^\s+|\s+$//g; $z }
							split /,/, $value
					];
				}
				else {
					$data{$field} = $value;
				}
			}
			else {
				die "Invalid entry in header in line '$line' file $file\n";
			}
		}

		for my $field ( keys %fields ) {
			if ( not $fields{$field}{optional} and not defined $data{$field} ) {
				die "Header ended and '$field' was not supplied for file $file\n";
			}
		}
		die "=timestamp missing in file $file\n" if not $data{timestamp};
		die "Invalid =timestamp '$data{timestamp}' in file $file\n"
			if $data{timestamp} !~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)$/;
		eval { DateTime->new( year => $1, month => $2, day => $3, hour => $4, minute => $5,
				second => $6 ); };    # just check if it is valid
		if ($@) {
			die "$@  in file $file\n";
		}

		while ( my $line = <$fh> ) {
			if ( $line =~ m{^\s*<(screencast|slidecast)\s+file="(.*)"\s+/>\s*$} ) {
				my ( $type, $file ) = ( $1, $2 );
				my @ext;
				if ( $type eq 'screencast' ) {
					@ext = ( 'mp4', 'webm' );
				}
				elsif ( $type eq 'slidecast' ) {
					@ext = ( 'ogv', 'avi' );
				}
				my %types = (
					mp4  => 'mp4',
					webm => 'webm',
					ogv  => 'ogg',
					avi  => 'avi',
				);
				my @sources   = map {qq{<source src="$file.$_" type='video/$types{$_}' />\n}} @ext;
				my @downloads = map {qq{<a href="$file.$_">$_</a>}} @ext;

				$line = <<"SCREENCAST";
<div id="screencast">
<video id="video_1" class="video-js vjs-default-skin"
  controls preload="auto"
  data-setup='{"controls":true}'>
  @sources
</video>
<div id="download">
Download:
@downloads
</div>
</div>
SCREENCAST
			}

			$line =~ s{<hl>}{<span class="inline_code">}g;
			$line =~ s{</hl>}{</span>}g;
			if ( $line =~ /^=abstract (start|end)/ ) {
				$data{"abstract_$1"}++;
				next;
			}

			if ( $data{abstract_start} and not $data{abstract_end} ) {
				$data{abstract} .= $line;
				if ( $line =~ /^\s*$/ ) {
					$data{abstract} .= "<p>\n";
				}
			}

			# <include file="examples/node_hello_world.js">
			if ( $line =~ m{^\s*<include\s+file="([^"]+)">\s*$} ) {
				my $include_file = $1;
				my $path         = $self->root . "/$include_file";
				if ( -e $path ) {
					$cont .= "<b>$include_file</b><br>";

					# TODO language based on extension?
					$cont .= qq{<pre class="prettyprint linenums language-perl">\n};
					$cont .= path($path)->slurp_utf8;
					$cont .= qq{</pre>\n};
				}    # else warn?
				next;
			}
			if ( $line =~ m{^<code(?: lang="([^"]+)")?>} ) {
				my $language = $1 || '';
				$in_code = 1;
				if ( $language eq 'perl' ) {
					$cont .= qq{<pre class="prettyprint linenums language-perl">\n};
				}
				else {
					# Without linenumst IE10 does not respect newlines and smashes everything together
					# prettyprint removed to avoid coloring when it is not perl code, but I am not sure this won't break
					# in IE10 and in general some pages.
					$cont .= qq{<pre class="linenums">\n};
				}
				next;
			}
			if ( $line =~ m{^</code>} ) {
				$in_code = undef;
				$cont .= qq{</pre>\n};
				next;
			}
			if ($in_code) {
				$line =~ s{<}{&lt;}g;
				$cont .= $line;
				next;
			}

			if ( $line =~ /^\s*$/ ) {
				$cont .= "<p>\n";
			}
			$cont .= $line;
		}
	}
	$data{mycontent} = $cont;

	if ( $data{abstract_start} ) {
		die "Too many times =abstract start: $data{abstract_start}"
			if $data{abstract_start} > 1;
		die '=abstract started but not ended' if not $data{abstract_end};
		die "Too many times =abstract edn: $data{abstract_end}"
			if $data{abstract_end} > 1;
	}

	# die if not $data{abstract} ???
	my $MAX_ABSTRACT = 1400;
	if ( length $data{abstract} > $MAX_ABSTRACT ) {
		die sprintf(
			'Abstract of %s is too long. It has %s characters. (allowed %s)',
			$self->file, length $data{abstract},
			$MAX_ABSTRACT
		);
	}

	my %links = $cont =~ m{<a href="([^"]+)">([^<]+)<}g;
	foreach my $url ( keys %links ) {
		if ( $url =~ /\.(avi|ogv|mp4|webm|mp3)$/ ) {
			delete $links{$url};
			next;
		}
		if ( $url !~ m{^/} ) {
			delete $links{$url};
			next;
		}
	}

	# Replace the anchor text by a the actual title of each linked page to for
	# the 'related' listing.
	# TODO: this should not be read into memory for every page!
	$data{related} = [];
	if ( not $ENV{METAMETA} and %links ) {
		my $site = $self->tools->read_meta_array('sitemap');
		my %sitemap = map { '/' . $_->{filename} => $_->{title} } @$site;
		foreach my $url ( sort keys %links ) {
			push @{ $data{related} },
				{
				url  => $url,
				text => ( $sitemap{$url} || $links{$url} ),
				};
		}
	}

	$self->data( \%data );
	return $self;
}

sub merge_conf {
	my ( $self, $ro_conf ) = @_;
	my $conf = dclone $ro_conf;

	my $data = $self->data;

	# TODO this should be probably the list of fields accepted by Perl::Maven::Pages
	# which in itself might need to be configurable. For now we add the fields
	# one by one as we convert the code and the pages.
	foreach
		my $f (qw(archive comments_disqus_enable show_related show_newsletter_form show_social show_right show_date))
	{
		if ( defined $data->{$f} ) {
			$conf->{$f} = delete $data->{$f};
		}
	}

	$data->{conf} = $conf;
	return $self;
}

1;

