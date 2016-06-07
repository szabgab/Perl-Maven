package Perl::Maven::Page;
use Moo;

use 5.014;
use DateTime;
use Data::Dumper qw(Dumper);
use Storable qw(dclone);
use Path::Tiny qw(path);

#use YAML::XS qw(LoadFile DumpFile);
use Template;

our $VERSION = '0.11';

has media => ( is => 'ro', required => 1 );
has root  => ( is => 'ro', required => 1 );
has file  => ( is => 'ro', required => 1 );
has tools => ( is => 'ro', required => 0 );
has data  => ( is => 'rw' );
has raw => ( is => 'rw', default => sub { [] } );
has pre => ( is => 'ro', default => sub { {} } );

my @page_options
	= qw(title timestamp author status description? indexes@? tags@? mp3@? original? books@? translator? redirect? perl6url? perl6title?);
my @common_options
	= qw(archive? comments_disqus_enable? show_social? show_newsletter_form? show_right? show_related? show_date? show_ads?);
my @header = ( @page_options, @common_options );
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
	my ($self) = @_;

	my %data = ( abstract => '', );
	my $cont = '';

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
	foreach my $k ( keys %data ) {
		$fields{$k} = {};
	}

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

	while ( @{ $self->raw } ) {
		my $line = shift @{ $self->raw };
		if ( $line =~ m{^\s*<(screencast|slidecast)\s+file="(.*?)"\s+(?:youtube="(.*?)"\s+)?/>\s*$} ) {
			my ( $type, $file, $youtube ) = ( $1, $2, $3 );
			if ($youtube) {
				$line
					= qq{<iframe width="1023" height="576" src="http://www.youtube.com/embed/$youtube" frameborder="0" allowfullscreen></iframe>};
			}
			else {
				$line = '';
			}

			my $path = substr $file, length('/media');
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
<video id="video_1" class="video-js vjs-default-skin"
  controls preload="auto"
  data-setup='{"controls":true}'>
  @sources
</video>
SCREENCAST
			}

			if (@downloads) {
				$line .= <<"DOWNLOADS";
<div id="download">
Download:
@downloads
</div>
DOWNLOADS
			}

			$line .= "</div>\n";
		}

		$line =~ s{<hl>}{<span class="inline_code">}g;
		$line =~ s{</hl>}{</span>}g;
		if ( $line =~ /^=abstract (start|end)/ ) {
			$data{"abstract_$1"}++;
			next;
		}

		if ( $data{abstract_start} and not $data{abstract_end} ) {
			$data{abstract} .= $line;
			my $include = $self->_process_include($line);
			if ($include) {
				$data{abstract} .= $include;
				#next;
			}

			my $code = $self->_process_code($line);
			if (defined $code) {
				if ($code) {
					$cont .= $self->{code};
				}
				#next;
			}


			if ( $line =~ /^\s*$/ ) {
				$data{abstract} .= "<p>\n";
			}
		}

		my $include = $self->_process_include($line);
		if ($include) {
			$cont .= $include;
			next;
		}

		my $code = $self->_process_code($line);
		if (defined $code) {
			if ($code) {
				$cont .= $self->{code};
			}
			next;
		}

		if ( $line =~ /^\s*$/ ) {
			$cont .= "<p>\n";
		}
		$cont .= $line;
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
	my $MAX_ABSTRACT = 4400;
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

sub _process_code {
	my ($self, $line) = @_;

	if ( $line =~ m{^<code(?: lang="([^"]+)")?>} ) {
		my $language = $1 || '';
		$self->{in_code} = 1;
		$self->{code} = '';
		if ( $language eq 'perl' ) {
			$self->{code} .= qq{<pre class="prettyprint linenums language-perl">\n};
		}
		else {
			# Without linenumst IE10 does not respect newlines and smashes everything together
			# prettyprint removed to avoid coloring when it is not perl code, but I am not sure this won't break
			# in IE10 and in general some pages.
			$self->{code} .= qq{<pre class="linenums">\n};
		}
		return 0;
	}
	if ( $line =~ m{^</code>} ) {
		$self->{in_code} = undef;
		$self->{code} .= qq{</pre>\n};
		return 1;
	}
	if ($self->{in_code}) {
		$line =~ s{<}{&lt;}g;
		$self->{code} .= $line;
		return 0;
	}
	return;
}


sub _process_include {
	my ($self, $line) = @_;

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

	my $include = '';
	if ( $line =~ m{^\s*<(include|try)\s+file="([^"]+)">\s*$} ) {
		my $what         = $1;
		my $include_file = $2;
		my $path         = $self->root . "/$include_file";
		if ( -e $path ) {
			$include .= "<b>$include_file</b><br>";

			# TODO language based on extension?
			my ($extension) = $path =~ /\.([^.]+)$/;
			my $language_code = $ext{$extension} ? "language-$ext{$extension}" : '';
			if ($extension eq 'txt') {
				$include .= qq{<pre>\n};
			} else {
				$include .= qq{<pre class="prettyprint linenums $language_code">\n};
			}
			my $code = path($path)->slurp_utf8;
			$code =~ s/&/&amp;/g;
			$code =~ s/</&lt;/g;
			$code =~ s/>/&gt;/g;
			$include .= $code;
			$include .= qq{</pre>\n};

			if ( $what eq 'try' ) {
				$include .= qq{<a href="/try/$include_file" target="_new">Try!</a>};
			}
		}
		else {
			die "Could not find '$path'";
		}
	}
	return $include;
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

