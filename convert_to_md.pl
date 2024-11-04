use strict;
use warnings FATAL => 'all';
use feature 'say';
use Data::Dumper;
use File::Spec::Functions qw(catfile);
use Path::Tiny qw(path);

# Convert olf Perl-Maven format to Markdown with Liquid-like special syntax
# to be moved to the Code-Maven SSG

# TODO:

die "Usage: $0 PATH_TO_PAGEs\n" if not @ARGV;

#opendir my $dh, $path or die "Could not open path\n";
#my @files = grep {$_ ne '.' and $_ ne '..'} readdir $dh;
my @files = @ARGV;

#print Dumper \@files;
for my $file (@files) {
    next if $file =~ m{/archive.txt$};
    next if $file !~ /\.txt$/;

    say "FILE: $file";
    my $in_file = $file;
    my $out_file = $in_file;
    $out_file =~ s/\.txt/.md/;
    #say $in_file;
    #say $out_file;

    # read file
    my @lines = path($in_file)->lines_utf8;
    my @output;
    my $in_header = 1;
    push @output, "---\n";
    while ($in_header) {
        my $line = shift @lines;
        #print "LINE: $line";
        if ($line =~ /^=title\s+(.*)/) {
            push @output, "title: $1\n";
            next;
        }
        if ($line =~ /^=timestamp\s+(.*)/) {
            push @output, "timestamp: $1\n";
            next;
        }
        if ($line =~ /^=indexes\s+(.*)/) {
            my @tags = split /\s*,\s*/, $1;
            push @output, "tags:\n";
            for my $tag (@tags) {
                push @output, "  - $tag\n";
            }
            next;
        }

        if ($line =~ /^=status\s+(.*)/) {
            my $status = $1;
            if ($status eq "show") {
                push @output, "published: true\n";
            } elsif ($status eq "draft") {
                push @output, "published: false\n";
            } else {
                die "Invalid status '$status' in $in_file";
            }
            next;
        }

        if ($line =~ /^=author\s+(.*)/) {
            my $author = $1;
            if ($author eq "0") {

            } else {
                push @output, "author: $author\n";
            }
        }


        # TODO: =archive 1
        if ($line =~ /^=archive\s+(.*)/) {
            my $archive = $1;
            if ($archive eq "0") {
            } elsif ($archive eq "1") {
            } else {
                die "Invalid archive '$archive' in $in_file";
            }
        }

        if ($line =~ /^=show_related\s+(.*)/) {
            my $show_related = $1;
            if ($show_related eq "0") {
                push @output, "show_related: false\n";
            } elsif ($show_related eq "1") {

            } else {
                die "Invalid show_related '$show_related' in $in_file";
            }
        }

        #LINE: =comments_disqus_enable 0

        if ($line =~ /^\s*$/) {
            $in_header = 0;
            push @output, "---\n\n";
            last;
        }
    }

    my $in_ul = 0;
    for my $line (@lines) {
        next if $line =~ /^=abstract/;
        $line =~ s{^<h2>(.*)</h2>}{## $1};
        if ($line =~ m{^<ul>$}) {
            $in_ul = 1;
            next;
        }
        if ($in_ul) {
             $line =~ s{^ *<li>}{* };
             $line =~ s{</li> *$}{};
        }
        if ($line =~ m{^</ul>$}) {
            $in_ul = 0;
            next;
        }

        $line =~ s{<a href="([^"]+)">([^<]+)</a>}{[$2]($1)}g;

        $line =~ s{<screencast file="([^"]+)" youtube="([^"]+)" />}({% youtube id="$2" %});

        say $1 if $line =~ m{<include file="([^"]+)">};
        $line =~ s{<include file="([^"]+)">}({% include file="$1" %});
        say $1 if $line =~ m{<try file="([^"]+)">};
        $line =~ s{<try file="([^"]+)">}({% include file="$1" %}\n\n[view]($1));

        say $1 if $line =~ m{<img src="([^"]+)">};
        $line =~ s{<img src="([^"]+)">}{![]($1)};

        $line =~ s{</?code>}{```};
        $line =~ s{<code lang="([^"]+)">}{```$1};
        $line =~ s{</?hl>}{`}g;

        push @output, $line;
    }


    path($out_file)->spew_utf8(@output);

    #last;
}
