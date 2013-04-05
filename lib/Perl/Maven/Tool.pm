package Perl::Maven::Tool;
use 5.010;
use Moo;

#use LWP::Simple qw(mirror);
use Parse::CPAN::Packages;
use Furl;
use JSON::PP qw(decode_json);

has root => (
	is       => 'ro',
	required => 1,
);

has cpan => (
	is       => 'ro',
);


sub get_root {
	my ($self) = @_;

	die sprintf("root '%s' does not exist", $self->root) if not -e $self->root;
	return $self->root;
}

sub show_distro_status {
	my ($self, $distribution) = @_;

	my $res = Furl->new()->post(
		'http://api.metacpan.org/v0/release/_search',
		['Content-Type' => 'application/json'],
		qq{
			{
				"query" : { "terms" : { "release.distribution" : [
					"$distribution"
				] } },
			"filter" : { "term" : { "release.status" : "latest" } },
			"fields" : [ "distribution", "version" ],
			"size"   : 3
		}
		});
	die $res->status_code unless $res->is_success;
	for (@{decode_json($res->content)->{hits}->{hits}}) {
		print "$_->{fields}->{distribution} $_->{fields}{version}\n";
	}



#	my $root = $self->get_root;
#	my $file = "$root/.cpan/02packages.details.txt.gz";
#	die if not -e $file;
#	my $p = Parse::CPAN::Packages->new($file);
#	my $m = $p->package($module);
#	say 'Version on CPAN: ' . $m->version;

	return;
}


1;

