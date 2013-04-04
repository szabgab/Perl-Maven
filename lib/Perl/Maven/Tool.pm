package Perl::Maven::Tool;
use Moo;

use LWP::Simple qw(mirror);

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

sub list {
	my ($self) = @_;

	my $root = $self->get_root;
}


1;

