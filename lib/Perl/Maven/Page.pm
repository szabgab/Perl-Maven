package Perl::Maven::Page;
use Moo;

use 5.014;
use Carp; # needed by DateTime::Tiny 1.04
use DateTime::Tiny;
use Data::Dumper qw(Dumper);


has file => (is => 'ro', required => 1);

sub read {
	my ($self) = @_;

	my %data = (content => '', abstract => '', showright => 1, newsletter => 1, published => 1);
	my $cont = '';
	my $in_code;

	# headers need to be in this order.
	# The onese with a ? mark at the end are optional
	# Others need to have a real value though for author we can set 0 if we don't want to provide (maybe we should
	#    require it but also have a mark if we want to show it or not?)
	my @header = qw(title timestamp description? indexes? tags? mp3? status original? books? showright? newsletter? published? author
        translator? archive comments social);


	my $file = $self->file;

	if (open my $fh, '<encoding(UTF-8)', $file) {
		for (my $i = 0; $i <= $#header; $i++) {
			my $field = $header[$i];

			my $line = <$fh>;
			chomp $line;
			if ($line =~ /^\s*$/) {
				die "Header ended and '$field' was not supplied for file $file\n";
			}

			#if (my ($f, $v) = $line =~ /=([\w-]+)(?:\s+(.*?)\s*)?$/) {
			if (my ($f, $v) = $line =~ /=([\w-]+)\s+(.*?)\s*$/) {
                $v //= '';

				# TODO make it configurable, which fields to split?
				if ($f =~ /^(indexes|tags|mp3)$/) {
					$data{$f} = [ map {s/^\s+|\s+$//g; $_} split /,/, $v ];
				} else {
					$data{$f} = $v;
				}

				while ($f ne $field and "$f?" ne $field) {
					if (substr($field, -1) eq '?') {
						$i++;
						if ($i > $#header) {
							die "We ran out of fields while processing line '$line' in file $file\n";
						}
						$field = $header[$i];
						next;
					}
					die "Invalid entry in header expected '$field', received '$f' in line '$line' file $file\n";
				}
			} else {
				die "Invalid entry in header for '$field' in line '$line' file $file\n";
			}
		}
		die "=timestamp missing in file $file\n" if not $data{timestamp};
		die "Invalid =timestamp '$data{timestamp}' in file $file\n" if $data{timestamp} !~ /^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d$/;
		eval {DateTime::Tiny->from_string($data{timestamp})}; # just check if it is valid
		if ($@) {
			die "$@  in file $file\n";
		}

		my $line = <$fh>;
		if ($line =~ /\S/) {
			die "Header not ended even after we ran out of required fields. line '$line' file $file\n";
		}

		while (my $line = <$fh>) {
			$line =~ s{<hl>}{<span class="inline_code">}g;
			$line =~ s{</hl>}{</span>}g;
			#$line =~ s{<hl>}{<b>}g;
			#$line =~ s{</hl>}{</b>}g;
			if ($line =~ /^=abstract start/ .. $line =~ /^=abstract end/) {
				next if $line =~ /^=abstract/;
				$data{abstract} .= $line;
				if ($line =~ /^\s*$/) {
					$data{abstract} .= "<p>\n";
				}
			}
			if ($line =~ m{^<code(?: lang="([^"]+)")?>}) {
				my $language = $1 || '';
				$in_code = 1;
				if ($language eq 'perl') {
					$cont .= qq{<pre class="prettyprint linenums language-perl">\n};
				} else {
					# Without linenumst IE10 does not respect newlines and smashes everything together
					# prettyprint removed to avoid coloring when it is not perl code, but I am not sure this won't break
					# in IE10 and in general some pages.
					$cont .= qq{<pre class="linenums">\n};
				}
				next;
			}
			if ($line =~ m{^</code>}) {
				$in_code = undef;
				$cont .= qq{</pre>\n};
				next;
			}
			if ($in_code) {
				$line =~ s{<}{&lt;}g;
				$cont .= $line;
				next;
			}

			if ($line =~ /^\s*$/) {
				$cont .= "<p>\n";
			}
			$cont .= $line;
		}
	}
	$data{mycontent} = $cont;
	my %links = $cont =~ m{<a href="([^"]+)">([^<]+)<}g;

	# TODO: this should not be read into memory for every page!
	if (not $ENV{METAMETA}) {
		my $site = Perl::Maven::read_meta_array('sitemap');
		my %sitemap = map { '/' . $_->{filename}  => $_->{title} } @$site;
		foreach my $url (keys %links) {
			if ($sitemap{ $url }) {
				$links{$url} = $sitemap{ $url };
			}
		}
	}

	$data{related} = [ map { { url => $_, text => $links{$_} } }
			grep { $_ =~ m{^/} } 
			sort keys %links ];

	my $MAX_ABSTRACT = 1000;
	if (length $data{abstract} > $MAX_ABSTRACT) {
		die sprintf("Abstract of %s is too long. It has %s characters. (allowed %s)", $self->file, length $data{abstract}, $MAX_ABSTRACT);
	}

	return \%data;
}

1;

# vim:noexpandtab

