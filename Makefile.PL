use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Perl::Maven',
    AUTHOR              => q{YOUR NAME <youremail@example.com>},
    VERSION_FROM        => 'lib/Perl/Maven.pm',
    ABSTRACT            => 'YOUR APPLICATION ABSTRACT',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'   => 0,
        'YAML'         => 0,
        'Dancer'     => 1.3095,
        'DBI'          => 0,
        'DBD::SQLite'  => 0,
        'DBIx::RunSQL' => 0,
        'Business::PayPal' => 0,
        'Template'         => 0,
        'Email::Valid' => 0,
        'Test::WWW::Mechanize' => 0,
        'MIME::Lite' => 0,
        'Moo'        => 1,
        'YAML'       => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Perl-Maven-*' },
);
