use Test::More tests => 7;
use strict;
use warnings;

use File::Copy qw(move);
use Capture::Tiny qw(capture);
use Cwd qw(cwd);
use t::lib::Test;
BEGIN {
    t::lib::Test::setup();
}

my $admin = "$^X -Ilib bin/admin.pl";


{
    my ($stdout, $stderr, @result) = capture {
        system $admin;
    };
    like $stdout, qr{Usage: bin/admin.pl}, 'usage';
    is $stderr, '', 'stderr is empty';
}

{
    my ($stdout, $stderr, @result) = capture {
        system "$admin --products";
    };
    is_deeply re_dump($stdout), [
           [
             2,
             'beginner_perl_maven_ebook',
             'Beginner Perl 5 Maven e-book',
             '0.01'
           ],
           [
             3,
             'perl_maven_cookbook',
             'Perl Maven Cookbook',
             undef
           ]
         ], '--products';
    is $stderr, '', 'stderr is empty';
}

{
    my ($stdout, $stderr, @result) = capture {
        system "$admin --address \@";
    };
    #diag $stdout;
    is $stderr, '', 'stderr is empty';
}

{
    my ($stdout, $stderr, @result) = capture {
        system "$admin --stats";
    };
    like $stdout, qr{Distinct # of clients};
    is $stderr, '', 'stderr is empty';
}


sub re_dump {
    my ($str) = @_;
    $str =~ s/\$VAR1 =//;
    #$str =~ s/^#//gm;
    my $data = eval $str;
    return $data;
}

