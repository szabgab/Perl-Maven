#!/usr/bin/perl
use strict;
use warnings;
use 5.010;

# pod2maven should generate the .tt files for the perl keywords and modules.
# It uses the PODs supplied with perl, PODs in Perl core and CPAN modules and some in-house text/html
# to preceed each entry and to link to the respective Perl 5 Maven articles.

# ) Find  the perlfunc.pod and split it up
# ) Add entries for the operators and other keywords such as 'if' and 'while' that are not keywords.
# ) Process some modules (e.g. File::Basename -> basename, dirname)
# ) Create an index and a connect it to the search capability on the web site
# ) Add some synonimes (from other languages?) to the keywords

main();
exit;

package Podder;
use strict;
use warnings;
use 5.010;

use Data::Dumper qw(Dumper);

=pod

use base 'Pod::Simple';
sub _handle_element_start {
    my ($parser, $element_name, $attr_hash_r) = @_;
    if ($element_name =~ /item/) {
        #say $element_name;
        print Dumper $attr_hash_r;
    }
}

sub _handle_element_end {
    my ($parser, $element_name, $attr_hash_r) = @_;
       # NOTE: $attr_hash_r is only present when $element_name is "over" or "begin"
       # The remaining code excerpts will mostly ignore this $attr_hash_r, as it is
       # mostly useless. It is documented where "over-*" and "begin" events are
       # documented.
}

sub _handle_text {
    my($parser, $text) = @_;
}
=cut

use base 'Pod::Parser';
my $start;
sub command {
    my ($parser, $command, $paragraph, $line_num) = @_;
    #say $command;
    if ($command eq 'head2' and $paragraph =~ /Alphabetical Listing of Perl Functions/) {
      $start = 1;
    }
    if ($start and $command eq 'item') {
        if ($paragraph =~ /\s/) {
            next;
        }
        #exit;
    }
}

package main;


sub main {
    my $perlfunc = find_in_inc('perlfunc.pod');
    my $p = Podder->new;
    my $out;
    #$p->output_string(\$out);
    #$p->parse_file($perlfunc);
    $p->parse_from_file($perlfunc, 'out.txt');
}


sub find_in_inc {
    my ($module) = @_;
    if ($module =~ /\.pod$/) {
        $module = "pods/$module";
    } else {
        die 'implement module conversaion';
    }
    
    foreach my $dir (@INC) {
       return "$dir/$module" if -e "$dir/$module";
    }
    return;
}


