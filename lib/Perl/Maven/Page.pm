package Perl::Maven::Page;
use Moo;

use 5.014;
use Carp qw(confess);
use DateTime;
use Data::Dumper qw(Dumper);
use Storable qw(dclone);
use Path::Tiny qw(path);

#use YAML::XS qw(LoadFile DumpFile);
use Template;

our $VERSION = '0.11';
my $MAX_ABSTRACT         = 4400;
my $EMBEDDED_AD_LOCATION = 1000;

has media  => ( is => 'ro', required => 1 );
has root   => ( is => 'ro', required => 1 );
has file   => ( is => 'ro', required => 1 );
has tools  => ( is => 'ro', required => 0 );
has data   => ( is => 'rw' );
has raw    => ( is => 'rw', default  => sub { [] } );
has pre    => ( is => 'ro', default  => sub { {} } );
has inline => ( is => 'ro', default  => sub { [] } );

my @page_options
	= qw(title timestamp author status description? indexes@? tags@? mp3@? original? books@? translator? redirect? perl6url? perl6title? img? alt? sample?);
my @common_options
	= qw(archive? comments_disqus_enable? show_social? show_newsletter_form? show_right? show_related? show_date? show_ads? embedded_ad?);
my @header        = ( @page_options, @common_options );
my @merge_options = map { my $t = $_; $t =~ s/[?@]//g; $t } @common_options;

sub read {
	my ($self) = @_;

	my $file = $self->file;
	if ( %{ $self->pre } ) {
		my $template = Template->new(
			{
				INTERPOLATE => 0,
				POST_CHOMP  => 1,
				EVAL_PERL   => 0,
				ABSOLUTE    => 1,
			}
		);

		my $html;
		$template->process( $file, $self->pre, \$html )
			or die $template->error();
		my @raw = split /\n/, $html;
		$self->raw( \@raw );
	}
	else {
		my @raw = path($file)->lines_utf8;
		$self->raw( \@raw );
	}
	return $self;
}

sub process {
	my ( $self, $mymaven ) = @_;

	$self->{data}{abstract}  = '';
	$self->{data}{mycontent} = '';

	# ? signals an optional field
	# @ signals a multi-value, a comma-separated list of values
	# Others need to have a real value though for author we can set 0 if we don't want to provide (maybe we should
	#    require it but also have a mark if we want to show it or not?)

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
	my %data;

	#foreach my $k ( keys %data ) {
	#	$fields{$k} = {};
	#}

	my $file = $self->file;

	while ( @{ $self->raw } ) {
		my $line = shift @{ $self->raw };
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

	my $embedded_ad = 0;

	# If the configuration tells us not to include embedded ads, then pretend they were already embedded.
	if ( not $mymaven->{conf}{embedded_ad} ) {
		$embedded_ad = 1;
	}

	# Don't embed inline ad in e-mail.
	# In a rather hackish way, mark such pages as if they already had an embedded ad to avoid adding another ad
	if ( $file =~ m{/mail/} ) {
		$embedded_ad = 1;
	}

	while ( @{ $self->raw } ) {
		my $line = shift @{ $self->raw };
		if ( $line =~ m{^\s*<(screencast|slidecast)\s+file="(.*?)"\s+(?:youtube="(.*?)"\s+)?/>\s*$} ) {
			my ( $type, $file, $youtube ) = ( $1, $2, $3 );
			if ($youtube) {
				$line
					= qq{<iframe class="youtube" src="https://www.youtube.com/embed/$youtube?rel=0" frameborder="0" allowfullscreen></iframe>};
			}
			else {
				$line = '';
			}

			my $path = length($file) > 6 ? substr $file, length('/media') : '';
			my %types = (
				mp4  => 'mp4',
				webm => 'webm',
				ogv  => 'ogg',
				avi  => 'avi',
			);
			my @ext
				= $self->media ? ( grep { $types{$_} } map { /\.(\w+)$/; $1 } glob $self->media . $path . '.*' ) : ();
			my @sources   = map {qq{<source src="$file.$_" type='video/$types{$_}' />\n}} @ext;
			my @downloads = map {qq{<a href="$file.$_">$_</a>}} @ext;
			$data{videos} = [ map {qq{$file.$_}} @ext ];

			$line .= q{<div id="screencast">};

			if ( @sources and not $youtube ) {
				$line .= <<"SCREENCAST";
<link href="//vjs.zencdn.net/4.12/video-js.css" rel="stylesheet">
<script src="//vjs.zencdn.net/4.12/video.js"></script>
<video id="video_1" class="video-js vjs-default-skin"
  controls preload="auto"
  data-setup='{"controls":true}'>
  @sources
</video>
SCREENCAST
			}

			if (@downloads) {
				$line .= <<"DOWNLOADS";
<div class="download">
Download:
@downloads
</div>
DOWNLOADS
			}

			$line .= "</div>\n";
		}

		if ( $line =~ m{\[transcript\]} ) {
			$self->{data}{transcriptx} = {};
			$self->{data}{mycontent} .= q{
				<h2>Transcript</h2>
				<div id="transcript">
			};
			next;
		}
		if ( $line =~ m{\[/transcript\]} ) {
			$self->{data}{mycontent} .= qq{        </div>\n};
			$self->{data}{mycontent} .= qq{    </div>\n};
			$self->{data}{mycontent} .= qq{</div>\n};
			delete $self->{data}{transcriptx};
			next;
		}
		if ( $self->{data}{transcriptx} ) {
			if ( $line =~ /\[(\S+)\s+(\S+)\s+(.*?)\s*\]/ ) {
				$self->{data}{transcriptx}{$1} = {
					class => $2,
					name  => $3,
				};
				next;
			}

			if ( $line =~ m{^\s*\[([\d:]+)\]\s+(.*?):(.*)} ) {
				if ( $self->{data}{transcript_entry} ) {
					$self->{data}{mycontent} .= q{
					   		</div>
						</div>
					};
				}
				$self->{data}{transcript_entry} = 1;

				my ( $timestamp, $speaker, $text ) = ( $1, $2, $3 );
				my $name  = 'Unknown';
				my $class = 'unknown';
				if ( $self->{data}{transcriptx}{$speaker} ) {
					$name  = $self->{data}{transcriptx}{$speaker}{name};
					$class = $self->{data}{transcriptx}{$speaker}{class};
				}
				$self->{data}{mycontent} .= qq{
					<div class="transcript-talk">
 					   <span class="transcript-timestamp">$timestamp</span>
 					   <span class="transcript-speaker-$class">$name</span>
 					   <div class="transcript-text">
                       $text
				};
				next;
			}
			if ( $line =~ /^\s*$/ ) {
				$self->{data}{mycontent} .= qq{<p>\n};
			}
			else {
				$self->{data}{mycontent} .= $line;
			}
			next;
		}

		#if ( $line =~ /<series name="([^"]*)">/ ) {
		#    my $series = $1;
		#    my $all_series = setting('tools')->read_meta('series');
		#    $line = Dumper $all_series->{$series};
		#}

		if ( $line =~ /<podcast>/ ) {
			if ( $data{mp3} ) {
				my ( $file, $size, $mins ) = @{ $data{mp3} };
				my $mb = int( $size / ( 1024 * 1024 ) );
				$line = qq{
					<div class="download">
					Download:
					<a href="$file">mp3</a> ($mb Mb) $mins mins
					</div>

					<audio controls>
					<source src="$file" type="audio/mpeg">
					</audio>
				};
			}
			else {
				$line = '';
			}
		}

		$line =~ s{<hl>}{<span class="inline_code">}g;
		$line =~ s{</hl>}{</span>}g;
		if ( $line =~ /^=abstract (start|end)/ ) {
			$self->{data}{"abstract_$1"}++;
			next;
		}

		if ( $self->{data}{abstract_start} and not $self->{data}{abstract_end} ) {
			next if $self->_process_include( $mymaven, $line, 1 );
			next if $self->_process_code( $line, 1 );
			if ( $line =~ /^\s*$/ ) {
				$self->{data}{abstract} .= "<p>\n";
				next;
			}
			$self->{data}{abstract} .= $line;
			next;
		}

		next if $self->_process_include( $mymaven, $line, 0 );
		next if $self->_process_code( $line, 0 );

		if ( $line =~ /^\s*$/ ) {
			$self->{data}{mycontent} .= "<p>\n";
			$embedded_ad = $self->embed_ad( $embedded_ad, $EMBEDDED_AD_LOCATION );
			next;
		}
		$self->{data}{mycontent} .= $line;
	}
	$embedded_ad     = $self->embed_ad( $embedded_ad, 0 );
	$data{mycontent} = $self->{data}{mycontent};
	$data{abstract}  = $self->{data}{abstract};

	if ( $self->{data}{abstract_start} ) {
		die "Too many times =abstract start: $self->{data}{abstract_start}"
			if $self->{data}{abstract_start} > 1;
		die '=abstract started but not ended' if not $self->{data}{abstract_end};
		die "Too many times =abstract end: $self->{data}{abstract_end}"
			if $self->{data}{abstract_end} > 1;
	}

	# die if not $data{abstract} ???
	if ( length $self->{data}{abstract} > $MAX_ABSTRACT ) {
		die sprintf(
			'Abstract of %s is too long. It has %s characters. (allowed %s)',
			$self->file, length $self->{data}{abstract},
			$MAX_ABSTRACT
		);
	}

	my %links = $self->{data}{mycontent} =~ m{<a href="([^"]+)">([^<]+)<}g;
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
		my $site    = $self->tools->read_meta_array('sitemap');
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

sub embed_ad {
	my ( $self, $embedded_ad, $ad_location ) = @_;
	my $inlines = $self->inline;
	if ( not $embedded_ad and $inlines and @{$inlines} and length( $self->{data}{mycontent} ) > $ad_location ) {
		my ($inline) = $inlines->[ int rand scalar @$inlines ];
		$self->{data}{mycontent}
			.= qq{<div style="text-align:center"><a href="$inline->{url}"><img src="$inline->{img}" /></a></div>\n};
		$embedded_ad = 1;
	}
	return $embedded_ad;
}

sub _process_code {
	my ( $self, $line, $abstract ) = @_;

	if ( $line =~ m{^<code(?: lang="([^"]+)")?>} ) {
		my $language = $1 || '';
		$self->{in_code} = 1;
		$self->{code}    = '';
		if ( $language eq 'perl' ) {
			$self->{code} .= qq{<pre class="prettyprint linenums language-perl">\n};
		}
		else {
			# Without linenumst IE10 does not respect newlines and smashes everything together
			# prettyprint removed to avoid coloring when it is not perl code, but I am not sure this won't break
			# in IE10 and in general some pages.
			$self->{code} .= qq{<pre class="linenums">\n};
		}
		return 1;
	}
	if ( $line =~ m{^</code>} ) {
		$self->{in_code} = undef;
		$self->{code} .= qq{</pre>\n};
		if ($abstract) {
			$self->{data}{abstract} .= $self->{code};
		}
		else {
			$self->{data}{mycontent} .= $self->{code};
		}
		return 1;
	}
	if ( $self->{in_code} ) {
		$line =~ s{<}{&lt;}g;
		$self->{code} .= $line;
		return 1;
	}
	return;
}

sub _process_include {
	my ( $self, $mymaven, $line, $abstract ) = @_;

	my $page_file = $self->file;

	# <include file="examples/node_hello_world.js">
	my %ext = (
		py   => 'python',
		rb   => 'ruby',
		php  => 'php',
		pl   => 'perl',
		pm   => 'perl',
		js   => 'javascript',
		html => 'html',
		xml  => 'xml',
	);

	my $include_content = '';
	if ( $line =~ m{^\s*<(include|try|linkto)\s+file="([^"]+)">\s*$} ) {
		my $what         = $1;
		my $include_file = $2;
		my $path         = $self->root . "/$include_file";

		# $mymaven->{github}
		my $link_to = "https://github.com/szabgab/code-maven.com/tree/main/$include_file";
		if ( -e $path ) {
			if ( $what eq 'linkto' ) {
				$include_content .= qq{<b><a href="$link_to">$include_file</a></b>};
			}
			else {
				$include_content .= "<b>$include_file</b><br>";

				# TODO language based on extension?
				my ($extension) = $path =~ /\.([^.]+)$/;
				my $language_code = $ext{$extension} ? "language-$ext{$extension}" : '';
				if ( $extension eq 'txt' ) {
					$include_content .= qq{<pre>\n};
				}
				else {
					$include_content .= qq{<pre class="prettyprint linenums $language_code">\n};
				}
				my $code = path($path)->slurp_utf8;
				die "Undefinded content in '$path' included in $page_file" if not defined $code;
				$code =~ s/&/&amp;/g;
				$code =~ s/</&lt;/g;
				$code =~ s/>/&gt;/g;
				$include_content .= $code;
				$include_content .= qq{</pre>\n};

				if ( $what eq 'try' ) {
					$include_content .= qq{<a href="/try/$include_file" target="_new">Try!</a>};
				}
			}
		}
		else {
			die "Could not find '$path'";
		}
	}
	if ($abstract) {
		$self->{data}{abstract} .= $include_content;
	}
	else {
		$self->{data}{mycontent} .= $include_content;
	}
	return $include_content ? 1 : 0;
}

sub merge_conf {
	my ( $self, $ro_conf ) = @_;
	my $conf = dclone $ro_conf;

	my $data = $self->data;

	# TODO this should be probably the list of fields accepted by Perl::Maven::Pages
	# which in itself might need to be configurable. For now we add the fields
	# one by one as we convert the code and the pages.
	foreach my $f (@merge_options) {
		if ( defined $data->{$f} ) {
			$conf->{$f} = delete $data->{$f};
		}
	}

	$data->{conf} = $conf;
	return $self;
}

1;

