use strict;
use warnings;
use File::Spec;
use File::Basename;
use lib File::Spec->catfile(
            File::Basename::dirname(File::Spec->rel2abs($0)),
            '..',
            'lib');

use Perl::Maven::Calendar;

#  Verify calendar format
# Should the dates be in order?

Perl::Maven::Calendar::create_calendar(q{sites/en/events.json});

