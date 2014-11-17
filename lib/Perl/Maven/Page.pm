package Perl::Maven::Page;
use Moo;

use 5.014;
use DateTime;
use Data::Dumper qw(Dumper);

our $VERSION = '0.11';

has file  => ( is => 'ro', required => 1 );
has tools => ( is => 'ro', required => 0 );

sub read {
	my ($self) = @_;

	my %data = (
		content    => '',
		abstract   => '',
		showright  => 1,
		newsletter => 1,
		published  => 1,
	);
	my $cont = '';
	my $in_code;

# headers need to be in this order.
# The onese with a ? mark at the end are optional
# Others need to have a real value though for author we can set 0 if we don't want to provide (maybe we should
#    require it but also have a mark if we want to show it or not?)
	my @header
		= qw(title timestamp description? indexes? tags? mp3? status original? books? showright? newsletter? published? author
		translator? archive comments social);

#my %fields = map { $_ => 1 } map { my $z = $_; $z =~ s/[?*]*$//; $z } @header;
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
			if ( my ( $f, $v ) = $line =~ /=([\w-]+)\s+(.*?)\s*$/ ) {
				$v //= '';

				# TODO make it configurable, which fields to split?
				if ( $f =~ /^(indexes|tags|mp3)$/ ) {
					$data{$f} = [
						map { my $z = $_; $z =~ s/^\s+|\s+$//g; $z }
							split /,/,
						$v
					];
				}
				else {
					$data{$f} = $v;
				}
			}
			else {
				die "Invalid entry in header in line '$line' file $file\n";
			}
		}

		for my $field ( keys %fields ) {
			if ( not $fields{$field}{optional} and not defined $data{$field} )
			{
				die
					"Header ended and '$field' was not supplied for file $file\n";
			}
		}
		foreach my $f ( keys %data ) {
			if ( not defined $fields{$f} ) {
				die "Invalid entry in header '$f' file $file\n";
			}
		}
		die "=timestamp missing in file $file\n" if not $data{timestamp};
		die "Invalid =timestamp '$data{timestamp}' in file $file\n"
			if $data{timestamp}
			!~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)$/;
		eval {
			DateTime->new(
				year   => $1,
				month  => $2,
				day    => $3,
				hour   => $4,
				minute => $5,
				second => $6
			);
		};    # just check if it is valid
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
			if ( $line =~ /^=abstract start/ .. $line =~ /^=abstract end/ ) {
				next if $line =~ /^=abstract/;
				$data{abstract} .= $line;
				if ( $line =~ /^\s*$/ ) {
					$data{abstract} .= "<p>\n";
				}
			}
			if ( $line =~ m{^<code(?: lang="([^"]+)")?>} ) {
				my $language = $1 || '';
				$in_code = 1;
				if ( $language eq 'perl' ) {
					$cont
						.= qq{<pre class="prettyprint linenums language-perl">\n};
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
	my %links = $cont =~ m{<a href="([^"]+)">([^<]+)<}g;

	# TODO: this should not be read into memory for every page!
	if ( not $ENV{METAMETA} ) {
		my $site = $self->tools->read_meta_array('sitemap');
		my %sitemap = map { '/' . $_->{filename} => $_->{title} } @$site;
		foreach my $url ( keys %links ) {
			if ( $sitemap{$url} ) {
				$links{$url} = $sitemap{$url};
			}
		}
	}

	$data{related} = [
		map { { url => $_, text => $links{$_} } }
		grep { $_ =~ m{^/} }
		sort keys %links
	];

	my $MAX_ABSTRACT = 1400;
	if ( length $data{abstract} > $MAX_ABSTRACT ) {
		die sprintf(
			'Abstract of %s is too long. It has %s characters. (allowed %s)',
			$self->file, length $data{abstract},
			$MAX_ABSTRACT
		);
	}

	return \%data;
}

1;

# vim:noexpandtab

