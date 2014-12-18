package Perl::Maven::SVG;
use Dancer2 appname => 'Perl::Maven';

use Data::Dumper qw(Dumper);

our $VERSION = '0.11';

get '/svg.xml' => sub {
	require SVG;
	my %query = params();
	my $xml   = circle( \%query );
	return $xml;
};

sub circle {
	my ($data) = @_;

	#die Dumper $data;

	my $svg = SVG->new(
		width  => $data->{width},
		height => $data->{height},
	);

	my $grp = $svg->group(
		id    => 'group_y',
		style => {
			stroke => $data->{stroke},
			fill   => $data->{fill},
		},
	);

	$grp->circle(
		cx => $data->{cx},
		cy => $data->{cy},
		r  => $data->{r},
		id => 'circle01',
	);
	return $svg->xmlify;
}

true;

