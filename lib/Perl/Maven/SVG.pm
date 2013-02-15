package Perl::Maven::SVG;
use strict;
use warnings;

use SVG;

use Data::Dumper qw(Dumper);

sub circle {
    my ($data) = @_;
    #die Dumper $data;

    my $svg = SVG->new(
        width  => $data->{width},
        height => $data->{height},
    );

    my $grp = $svg->group(
        id => 'group_y',
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


1;
