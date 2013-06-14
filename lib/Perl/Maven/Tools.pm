package Perl::Maven::Tools;
use strict;
use warnings;

use List::MoreUtils qw(any none);

# given two array reference of scalars, returns true if they have any intersection
sub _intersect {
	my ($x, $y) = @_;
	for my $z (@$x) {
		return 1 if any { $_ eq $z } @$y;
	}
	return 0;
}

sub _any {
	my ($val, $ref) = @_;
	return any { $_ eq $val } @$ref;
}
sub _none {
	my ($val, $ref) = @_;
	return none { $_ eq $val } @$ref;
}



1;

