use strict;
use warnings FATAL => 'all';
use feature 'say';
use Data::Dumper;
use File::Spec::Functions qw(catfile);
use Path::Tiny qw(path);

# Convert olf Perl-Maven format to Markdown with Liquid-like special syntax

my $path = shift or die "Usage: $0 PATH_TO_PAGES\n";

opendir my $dh, $path or die "Could not open path\n";
my @files = grep {$_ ne '.' and $_ ne '..'} readdir $dh;

#print Dumper \@files;
for my $file (@files) {
    next if $file eq 'archive.txt';
    next if $file !~ /\.txt$/;

    say $file;
    my $in_file = catfile($path, $file);
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

        #LINE: =status show
        #LINE: =author 0
        #LINE: =archive 1
        #LINE: =comments_disqus_enable 0
        #LINE: =show_related 1

        if ($line =~ /^\s*$/) {
            $in_header = 0;
            push @output, "---\n";
            last;
        }
    }

    for my $line (@lines) {
        push @output, $line;
    }

    #=abstract start
    #=abstract end
    #
    #<screencast file="/media" youtube="dc28TN0PCoc" />


    path($out_file)->spew_utf8(@output);

    #last;
}
