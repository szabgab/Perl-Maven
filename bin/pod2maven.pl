#!/usr/bin/perl
use strict;
use warnings;

# pod2maven should generate the .tt files for the perl keywords and modules.
# It uses the PODs supplied with perl, PODs in Perl core and CPAN modules and some in-house text/html
# to preceed each entry and to link to the respective Perl 5 Maven articles.

# ) Find  the perlfunc.pod and split it up
# ) Add entries for the operators and other keywords such as 'if' and 'while' that are not keywords.
# ) Process some modules (e.g. File::Basename -> basename, dirname)
# ) Create an index and a connect it to the search capability on the web site
# ) Add some synonimes (from other languages?) to the keywords
