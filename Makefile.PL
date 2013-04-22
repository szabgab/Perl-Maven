use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Perl::Maven',
    AUTHOR              => q{Gabor Szabo <szabgab@cpan.org>},
    VERSION_FROM        => 'lib/Perl/Maven.pm',
    ABSTRACT            => 'Web application running the Perl Maven sites',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Business::PayPal'     => 0,
        'Dancer'               => 1.3095,
        'DBD::SQLite'          => 0,
        'DBI'                  => 0,
        'DBIx::RunSQL'         => 0,
        'Email::Valid'         => 0,
        'Hash::Merge::Simple'  => 0,
        'MIME::Lite'           => 0,
        'Storable'             => 0,
        'Template'             => 0,
        'Test::WWW::Mechanize' => 0,
        'Test::More'           => 0,
        'YAML'                 => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Perl-Maven-*' },
);
