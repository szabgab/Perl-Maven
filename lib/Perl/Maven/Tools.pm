package Perl::Maven::Tools;
use Moo;
use List::MoreUtils qw(any none);
use Cpanel::JSON::XS qw(decode_json);
use List::Util qw(min);

our $VERSION = '0.11';

has host => (
	is       => 'ro',
	required => 1,
);

has meta => (
	is       => 'ro',
	required => 1,
);

=head1 NAME

Perl::Maven::Tools - some internal helper functions for Perl::Maven

=head1 DESCRPTION

_any

_none

See also L<Perl::Maven>.

=cut

# given two array reference of scalars, returns true if they have any intersection
#sub _intersect {
#	my ($x, $y) = @_;
#	for my $z (@$x) {
#		return 1 if any { $_ eq $z } @$y;
#	}
#	return 0;
#}

sub _any {
	my ( $val, $ref ) = @_;
	return any { $_ eq $val } @$ref;
}

sub _none {
	my ( $val, $ref ) = @_;
	return none { $_ eq $val } @$ref;
}

sub read_meta {
	my ( $self, $file ) = @_;

	my $host      = Perl::Maven::Config::host( $self->host );
	my $json_file = $self->meta . "/$host/meta/$file.json";
	return {} if not -e $json_file;
	return read_json($json_file);
}

sub read_meta_hash {
	my ( $self, $what ) = @_;

	my $meta = $self->read_meta($what) || {};

	return $meta;
}

sub read_meta_array {
	my ( $self, $what, %p ) = @_;

	my $meta = $self->read_meta($what) || [];
	return $meta if not %p;

	my @pages = @$meta;
	if ( $p{filter} ) {
		if ( $p{filter} eq 'free' ) {
			@pages = grep { Perl::Maven::Tools::_none( 'pro', $_->{tags} ) } @pages;
		}
		else {
			@pages = grep { Perl::Maven::Tools::_any( $p{filter}, $_->{tags} ) } @pages;
		}
	}
	if ( defined $p{limit} ) {
		my $limit = min( $p{limit}, scalar @pages );
		if ( $limit > 0 ) {
			@pages = @pages[ 0 .. $limit - 1 ];
		}
		else {
			@pages = ();
		}
	}

	@pages = reverse sort { $a->{timestamp} cmp $b->{timestamp} } @pages;

	return \@pages;
}

sub read_meta_meta {
	my ( $self, $file ) = @_;

	return read_json( $self->meta . "/$file.json" );
}

sub read_json {
	my ($file) = @_;

	if ( open my $fh, '<encoding(UTF-8)', $file ) {
		local $/ = undef;
		my $json = <$fh>;
		return decode_json $json;
	}
	return;
}

1;

