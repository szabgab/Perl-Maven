use Test::More tests => 19;
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
        system "$admin --products --dump";
    };
    is_deeply re_dump($stdout), [
           [
             2,
             'beginner_perl_maven_ebook',
             'Beginner Perl Maven e-book',
             '0.01'
           ],
           [
             3,
             'perl_maven_cookbook',
             'Perl Maven Cookbook',
             39
           ]
         ], '--products --dump';
    is $stderr, '', 'stderr is empty';
}
{
    my ($stdout, $stderr, @result) = capture {
        system "$admin --products";
    };
    is $stdout, 
q{ 2 beginner_perl_maven_ebook           Beginner Perl Maven e-book        0.01
 3 perl_maven_cookbook                 Perl Maven Cookbook                39
} , '--products';
    is $stderr, '', 'stderr is empty';
}


{
    my ($stdout, $stderr, @result) = capture {
        system "$admin --email \@";
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

{
    my ($stdout, $stderr, @result) = capture {
        system "$admin --list perl_maven_cookbook";
    };
    is $stdout, '';
    is $stderr, '', 'stderr is empty';
}

{
    my ($stdout, $stderr, @result) = capture {
        system "$admin --list other_product";
    };
    is $stdout, '';
    is $stderr, '', 'stderr is empty';
}

{
    my ($stdout, $stderr, @result) = capture {
        system "$admin --addsub perl_maven_cookbook --email a\@b.com";
    };
    like $stdout, qr{Could not find user 'a\@b.com'};
    is $stderr, '', 'stderr is empty';
    unlike $stderr, qr/DBD::.*failed/, 'no DBD error';
}

{
    my ($stdout, $stderr, @result) = capture {
        system "$admin --addsub other_thing --email a\@b.com";
    };
    like $stdout, qr{Could not find product 'other_thing'};
    is $stderr, '', 'stderr is empty';
    unlike $stderr, qr/DBD::.*failed/, 'no DBD error';
}


sub re_dump {
    my ($str) = @_;
    $str =~ s/\$VAR1 =//;
    #$str =~ s/^#//gm;
    my $data = eval $str;
    return $data;
}

