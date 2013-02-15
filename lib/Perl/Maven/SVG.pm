package Perl::Maven::SVG;
use strict;
use warnings;

use SVG;

sub circle {
    my $svg = SVG->new(
        width  => 200,
        height => 200,
    );

    my $grp = $svg->group(
        id => 'group_y',
        style => {
            stroke => 'red',
            fill   => 'grey',
        },
    );

    $grp->circle(
        cx => 100,
        cy => 100,
        r  => 50,
        id => 'circle01',
    );
    return $svg->xmlify;
}


1;
