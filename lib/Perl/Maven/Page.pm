package Perl::Maven::Page;
use Moo;

use 5.014;
use DateTime;
use Data::Dumper qw(Dumper);
use Storable qw(dclone);

our $VERSION = '0.11';

has file  => ( is => 'ro', required => 1 );
has tools => ( is => 'ro', required => 0 );
has data  => ( is => 'rw' );

sub read {
	my ($self) = @_;

	my %data = (
		content   => '',
		abstract  => '',
		published => 1,
	);
	my $cont = '';
	my $in_code;

	# ? signals an optional field
	# @ signals a multi-value, a comma-separated list of values
	# Others need to have a real value though for author we can set 0 if we don't want to provide (maybe we should
	#    require it but also have a mark if we want to show it or not?)
	my @header
		= qw(title timestamp author status description? indexes@? tags@? mp3@? original? books? published? translator?);
	push @header, qw(archive? comments_disqus_enable? show_social? show_newsletter_form? show_right? show_related?);

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
			if ( $line =~ m{^\s*<screencast\s+file="(.*)"\s+/>\s*$} ) {
				my $file = $1;
				$line = <<"SCREENCAST";
<link href="//vjs.zencdn.net/4.6/video-js.css" rel="stylesheet">
<script src="//vjs.zencdn.net/4.6/video.js"></script>

<video id="video_1" class="video-js vjs-default-skin"
  controls preload="auto"
  data-setup='{"controls":true}'>
 <source src="$file.mp4" type='video/mp4' />
 <source src="$file.webm" type='video/webm' />
</video>

<div id="download">
Download:
<a href="$file.mp4">mp4</a>
<a href="$file.webm">webm</a>
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
		if ( $url !~ m{^/} ) {
			delete $links{$url};
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
	foreach my $f (qw(archive comments_disqus_enable show_related show_newsletter_form show_social show_right)) {
		if ( defined $data->{$f} ) {
			$conf->{$f} = delete $data->{$f};
		}
	}

	$data->{conf} = $conf;
	return $self;
}

1;

