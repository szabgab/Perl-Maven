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
        if ($line =~ /^=books\s+(.*)/) {
            my @books = split /\s*,\s*/, $1;
            push @output, "books:\n";
            for my $book (@books) {
                push @output, "  - $book\n";
            }
            next;
        }

        if ($line =~ /^=tags\s+(.*)/) {
            my @tags = split /\s*,\s*/, $1;
            push @output, "types:\n";
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
            next;
        }

        if ($line =~ /^=translator\s+(.*)/) {
            my $translator = $1;
            if ($translator eq "0") {

            } else {
                push @output, "translator: $translator\n";
            }
            next;
        }

        if ($line =~ /^=original\s+(.*)/) {
            my $original = $1;
            push @output, "original: $original\n";
            next;
        }

        if ($line =~ /^=description\s+(.*)/) {
            my $description = $1;
            push @output, "description: $description\n";
            next;
        }


        # TODO: =archive 1
        if ($line =~ /^=archive\s+(.*)/) {
            my $archive = $1;
            if ($archive eq "0") {
                push @output, "archive: false\n";
            } elsif ($archive eq "1") {
                push @output, "archive: true\n";
            } else {
                die "Invalid archive '$archive' in $in_file";
            }
            next;
        }

        if ($line =~ /^=show_related\s+(.*)/) {
            my $show_related = $1;
            if ($show_related eq "0") {
                push @output, "show_related: false\n";
            } elsif ($show_related eq "1") {
                push @output, "show_related: true\n";
            } else {
                die "Invalid show_related '$show_related' in $in_file";
            }
            next;
        }

        if ($line =~ /^=img\s+(.*)/) {
            push @output, "img: $1\n";
            next;
        }
        if ($line =~ /^=alt\s+(.*)/) {
            push @output, "alt: $1\n";
            next;
        }

        # =mp3 /media/cmos-19-job-van-achterberg.mp3, 28149915, 28:21
        if ($line =~ /^=mp3\s+(.*)/) {
            my @parts = split /, */, $1;
            die "Invalid line '$line'" if scalar @parts != 3;
            my ($file, $size, $time) = @parts;
            push @output, "mp3:\n";
            push @output, "  file: $file\n";
            push @output, "  size: $size\n";
            push @output, "  time: $time\n";
            next;
        }

        #LINE: =comments_disqus_enable 0
        next if $line =~ /^=show_newsletter_form /;
        next if $line =~ /^=show_date /;
        next if $line =~ /^=show_right /;
        next if $line =~ /^=perl6url /;
        next if $line =~ /^=perl6title /;
        next if $line =~ /^=show_social /;
        next if $line =~ /^=show_ads /;
        next if $line =~ /^=sample /;
        next if $line =~ /^=redirect /;
        next if $line =~ /^=embedded_ad /;
        next if $line =~ /^=feed /;
        next if $line =~ /^=comments /;
        next if $line =~ /^=newsletter /;
        next if $line =~ /^=published /;
        next if $line =~ /^=social /;
        next if $line =~ /^=comments_disqus_enable /;

        if ($line =~ /^=(\S*)/) {
            die "Unprocessed header field '$1' in '$file'";
        }

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
