package Perl::Maven::Tool;
use Moo;

has root => (
	is       => 'ro',
	required => 1,
);

sub list {
	my ($self) = @_;

	die sprintf("root '%s' does not exist", $self->root) if not -e $self->root;
}


1;


