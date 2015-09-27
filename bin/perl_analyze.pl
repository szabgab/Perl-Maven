use strict;
use warnings;
use 5.010;
use lib 'lib';

# Analyze CPAN modules and later other Perl projects and later who knows what.

# Fetch the recent list from MetaCPAN
# Check which one of the releases has not been processed yet (deduct the project name which is the distribution in CPAN/MetaCPAN)
#    Download the files
#    Process each file (currently: list which other modules are being used)
#    remove the data from the db associated with ($project, $file)
#    Store this information in the database

use Perl::Maven::Analyze;
Perl::Maven::Analyze->new_with_options->run;

