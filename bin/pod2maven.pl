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

sub main {
    #'/home/gabor/tmp/perl-5.16.2/pod/perlvar.pod'

    # first thing to "manually" cut up the PODs to chunks I'd like to display
    # This probably needs special code for each pod file in the core perl documentation
    # then we'll be able to generate stand alone template files from each one
    my $perlfunc = '/home/gabor/tmp/perl-5.16.2/pod/perlfunc.pod';
    open my $fh, '<', $perlfunc or die;

#=item -X FILEHANDLE
#=item abs VALUE
#=item accept NEWSOCKET,GENERICSOCKET

    my %pod;
    my $in_head = 1;
    my $item;
    my $item_had_content = 0;
    my $internal = 0;
    while (my $line = <$fh>) {
        if ($in_head) {
            if ($line =~ /^=head2 Alphabetical Listing of Perl Functions/) {
                $in_head = 0;
            }
            $pod{head} .= $line;
            next;
        }

        # skip some lines after the Alphabetical Listing ... but before the first =item
        if (not $item and $line !~ /=item/) {
            next;
        }

        #if ($line =~ /^=over/ or $line =~ /^=for/) {
        if ($line =~ /^=over/) {
            $internal++;
        }
        if ($line =~ /^=back/) {
            $internal--;
            #die "internal is negative in $." if $internal < 0;
        }

        if (not $internal) {
            if ($line =~ /^=item\s+(\S+)/) {
                if ((not $item) or ($item and $item_had_content)) {
                    $item = $1;
                    $item =~ s{/}{}g;   # items such as m/// and tr///
                    $item =~ s{-}{}g;   # -X
                    $item =~ s{_}{}g;   # items like __FILE__
                    $item_had_content = 0;
                }
            }
            if ($item) {
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

    # some error checkig:
    die if $in_head;

    my $path = 'tmp';
    foreach my $key (keys %pod) {
        my $file = "$path/$key.tt";
        open my $out, '>', $file or die "Could not open '$file' $!";
        print $out $pod{$key};
        close $out;
        #say $key;
    }
    #print $pod{head};


    #my $perlfunc = find_in_inc('perlfunc.pod');
    #my $p = Podder->new;
    #my $out;
    #$p->output_string(\$out);
    #$p->parse_file($perlfunc);
    #$p->parse_from_file($perlfunc, 'out.txt');
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

sub _handle_element_start {
  my($parser, $element_name, $attr_hash_r) = @_;
}

sub _handle_element_end {
  my($parser, $element_name, $attr_hash_r) = @_;
  # NOTE: $attr_hash_r is only present when $element_name is "over" or "begin"
  # The remaining code excerpts will mostly ignore this $attr_hash_r, as it is
  # mostly useless. It is documented where "over-*" and "begin" events are
  # documented.
}

sub _handle_text {
  my($parser, $text) = @_;
}

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

use base 'Pod::Simple';
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


