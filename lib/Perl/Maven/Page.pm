package Perl::Maven::Page;
use Moose;

use 5.014;


has file => (is => 'ro', isa => 'Str', required => 1);

sub read {
	my ($self) = @_;

	my %data = (content => '', abstract => '', showright => 1, newsletter => 1, published => 1);
	my $cont = '';
	my $in_code;

	# headers need to be in this order.
	# The onese with a ? mark at the end are optional
	# Others need to have a real value though for author we can set 0 if we don't want to provide (maybe we should
	#    require it but also have a mark if we want to show it or not?)
	my @header = qw(title timestamp description? indexes? tags? status books? showright? newsletter? published? author index
		archive feed comments social);


	my $file = $self->file;

	if (open my $fh, '<encoding(UTF-8)', $file) {
		for (my $i = 0; $i <= $#header; $i++) {
			my $field = $header[$i];

			my $line = <$fh>;
			chomp $line;
			if ($line =~ /^\s*$/) {
				die "Header ended and '$field' was not supplied for file $file\n";
			}

			if (my ($f, $v) = $line =~ /=([\w-]+)\s+(.*?)\s*$/) {

				# TODO make it configurable, which fields to split?
				if ($f eq 'indexes' or $f eq 'tags') {
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
					$cont .= qq{<pre class="prettyprint linenums languague-perl">\n};
				} else {
					$cont .= qq{<pre class="prettyprint">\n};
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
	if (length $data{abstract} > 800) {
		die sprintf("Abstract of %s is too long. It has %s character", $self->file, length $data{abstract});
	}

	return \%data;
}

1;

# vim:noexpandtab

