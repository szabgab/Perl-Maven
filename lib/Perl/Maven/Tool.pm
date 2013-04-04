package Perl::Maven::Tool;
use 5.010;
use Moo;

use LWP::Simple qw(mirror);
use Parse::CPAN::Packages;

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

sub get_index_files {
	my ($self) = @_;

	die 'URL of cpan not given' if not $self->cpan;
	my $url = $self->cpan . '/modules/02packages.details.txt.gz';
	my $root = $self->get_root;
	my $dir = "$root/.cpan";
	mkdir $dir if not -e $dir;
	mirror($url, "$dir/02packages.details.txt.gz"); # TODO error checking?

	return;
}

sub show_module_status {
	my ($self, $module) = @_;

	my $root = $self->get_root;
	my $file = "$root/.cpan/02packages.details.txt.gz";
	die if not -e $file;
	my $p = Parse::CPAN::Packages->new($file);
	my $m = $p->package($module);
	say 'Version on CPAN: ' . $m->version;

	return;
}


1;

