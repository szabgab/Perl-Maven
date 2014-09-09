package Perl::Maven::Tool;
use 5.010;
use Moo;

use Data::Dumper qw(Dumper);

#use LWP::Simple qw(mirror);
use Parse::CPAN::Packages;
use Furl;
use JSON::PP qw(decode_json);

has root => (
	is       => 'ro',
	required => 1,
);

has cpan => ( is => 'ro', );

sub get_root {
	my ($self) = @_;

	die sprintf( q{root '%s' does not exist}, $self->root )
		if not -e $self->root;
	return $self->root;
}

sub show_distro_status {
	my ( $self, $distribution ) = @_;

	my $data = $self->get_distro_info($distribution);

	print "$data->{distribution} $data->{version}\n";

	# $_->{fields}{download_url}\n";
	#print Dumper $data;

	return;
}

sub get_distro_info {
	my ( $self, $distribution ) = @_;

	my $res = Furl->new()->post(
		'http://api.metacpan.org/v0/release/_search',
		[ 'Content-Type' => 'application/json' ],
		qq{
			{
				"query" : { "terms" : { "release.distribution" : [
					"$distribution"
				] } },
			"filter" : { "term" : { "release.status" : "latest" } },
			"fields" : [ "distribution", "version", "download_url" ],
			"size"   : 3
		}
		}
	);

	die $res->status_code unless $res->is_success;
	my $data = decode_json( $res->content )->{hits}->{hits};
	die 'No hit' if not @$data;
	die 'Too many hits' if @$data > 1;

	return $data->[0]{fields};
}

sub get_distro {
	my ( $self, $distribution ) = @_;

	my $d = $self->get_distro_info($distribution);
	say $d->{download_url};
	return;
}

1;

