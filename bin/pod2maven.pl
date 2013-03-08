#!/usr/bin/perl
use strict;
use warnings;
use 5.010;

use Data::Dumper qw(Dumper);

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

sub main {
    #'/home/gabor/tmp/perl-5.16.2/pod/perlvar.pod'
    # first thing to "manually" cut up the PODs to chunks I'd like to display
    # This probably needs special code for each pod file in the core perl documentation
    # then we'll be able to generate stand alone template files from each one
    perlfunc('/home/gabor/tmp/perl-5.16.2/pod', '/home/gabor/work/articles/perldoc');
}


sub perlfunc {
    my ($src, $outdir) = @_;

    my $perlfunc =  "$src/perlfunc.pod";
    open my $fh, '<', $perlfunc or die;

    my %keywords;
    my %pod;
    my $in_head = 1;
    my $item;
    my $item_had_content = 0;
    my $internal = 0;
    my $head = '';
    while (my $line = <$fh>) {
        if ($in_head) {
            if ($line =~ /^=head2 Alphabetical Listing of Perl Functions/) {
                $in_head = 0;
            }
            $head .= $line;
            next;
        }

        # skip some lines after the Alphabetical Listing ... but before the first =item
        if (not $item and $line !~ /=item/) {
            next;
        }

        if ($line =~ /^=over/) {
            $internal++;
        }
        if ($line =~ /^=back/) {
            $internal--;
            #die "internal is negative in $." if $internal < 0;
        }

        if (not $internal) {
            if ($line =~ /^=item\s+(\S+)/) {
                #say $line;
                if ((not $item) or ($item and $item_had_content)) {
                    $item = $1;
                    $item =~ s{/}{}g;   # items such as m/// and tr///
                    $item =~ s{-}{}g;   # -X
                    #$item =~ s{_}{}g;   # items like __FILE__
                    $item_had_content = 0;
                }
                next;
            }
            if ($item) {
                if ($line =~ /^X</) {
                    #say $line;
                    next;
                }

                if ($line !~ /^=/ and $line !~ /^X</ and $line =~ /\S/) {
                    $item_had_content = 1;
                }
            }
        }
        $pod{$item} .= $line;

        # there are some more keywords after this that are documented in other PODs
        if ($line =~ /^=head2 Non-function Keywords by Cross-reference/) {
            last;
        }
    }

    # special case as this is the back from the =over we skipped before all the keywords
    $pod{y} =~ s/=back//;
    # some error checkig:
    die if $in_head;

    foreach my $key (keys %pod) {
        my $file = "$outdir/$key.tt";
        my $p = Podder->new;
        #print $pod{$key};

        my $tt;
        $p->output_string(\$tt);
        $p->parse_string_document( $pod{$key} );

        die "Pod errors in $key\n$pod{$key}\n-----\n$tt" if $tt =~ /POD_ERRORS/;

        open my $out, '>', $file or die "Could not open '$file' $!";
        print $out tt_header($key, $key);
        print $out "The content of this page was taken from the standard Perl documentation\n\n";
        print $out $tt;
        close $out;
        #last if ++$xx::xx > 1; # for debugging
    }


    #my $out;
    #$p->parse_file($perlfunc);
    #$p->parse_from_file($perlfunc, 'out.txt');
}

sub tt_header {
    my ($title, $keywords) = @_;
    use DateTime;
    my $time = DateTime->from_epoch( epoch => time );

return <<"END_HEADER";
=title Perldoc: $title
=timestamp $time
=indexes $keywords
=status show
=author 0
=index 0
=archive 0
=feed 0
=comments 1
=social 1

END_HEADER
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


##################################################

package Podder;
use strict;
use warnings;
use 5.010;

use Data::Dumper qw(Dumper);
use base 'Pod::Simple::HTML';

#sub _handle_element_start {
#    my($parser, $element_name, $attr_hash_r) = @_;
#    say "Start $element_name " . Dumper $attr_hash_r;
#    #$parser->{_tt_} .= "$element_name\n";
#    #return $element_name;
#}
#
#sub _handle_element_end {
#    my($parser, $element_name, $attr_hash_r) = @_;
#    # NOTE: $attr_hash_r is only present when $element_name is "over" or "begin"
#    # The remaining code excerpts will mostly ignore this $attr_hash_r, as it is
#    # mostly useless. It is documented where "over-*" and "begin" events are
#    # documented.
#}
#
#sub _handle_text {
#    my($parser, $text) = @_;
#}

=pod

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

#my $start;
#sub command {
#    my ($parser, $command, $paragraph, $line_num) = @_;
#    #say $command;
#    if ($command eq 'head2' and $paragraph =~ /Alphabetical Listing of Perl Functions/) {
#      $start = 1;
#    }
#    if ($start and $command eq 'item') {
#        if ($paragraph =~ /\s/) {
#            return;
#        }
#        #exit;
#    }
#}


