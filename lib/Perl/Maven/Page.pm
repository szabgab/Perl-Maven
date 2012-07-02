package Perl::Maven::Page;
use Moose;


has file => (is => 'ro', isa => 'Str', required => 1);

sub read {
	my ($self) = @_;

	my %data = (content => '', abstract => '');
	my $cont = '';
	my $in_code;
	if (open my $fh, '<', $self->file) {
		while (my $line = <$fh>) {
			if ($line =~ /^=abstract start/ .. $line =~ /^=abstract end/) {
				next if $line =~ /^=abstract/;
				$data{abstract} .= $line;
			}
			if ($line =~ /^=(\w+)\s+(.*?)\s*$/) {
				$data{$1} = $2;
				next;
			}
			if ($line =~ m{^<code lang="([^"]+)">}) {
				$in_code = $1;
				$cont .= qq{<pre>\n};
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

	return \%data;
}

1;

