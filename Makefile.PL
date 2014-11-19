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
        'Acme::MetaSyntactic'   => 1.012,  # or even Task::MetaSyntactic
        'Business::PayPal'      => 0.13,
		'Carp::Always'          => 0,
        'Code::Explain'         => 0.02,
        'Dancer'                => 1.3095,
		'Dancer::Plugin::Passphrase' => '2.0.1',
        'DateTime'              => 1.12,
        'DBD::SQLite'           => 1.42,
        'DBI'                   => 1.631,
        'DBIx::RunSQL'          => 0.12,
        'Email::Valid'          => 1.193,
        'File::Find::Rule'      => 0.33,
        'Hash::Merge::Simple'   => 0.051,
        'Moo'                   => 1.006000,
		'Plack'                 => 1.0031,
        'Storable'              => 2.51,   # dclone is used
        'Template'              => 2.25,
        'YAML'                  => 1.09,
        'JSON'                  => 2.90,
        'Web::Feed'             => 0.02,
		'Digest::SHA'           => 5.92,

        'MIME::Lite'            => 0,
        'Email::Sender::Simple' => 1.300012,
        'Email::MIME::Creator'  => 1.926,

# For testing
        'Test::WWW::Mechanize'  => 1.44,
        'Test::WWW::Mechanize::PSGI'  => 0.35,
        'Test::More'            => 1,

# For deployment
        'Starman'               => 0.4009,
        'Daemon::Control'       => 0.001005,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Perl-Maven-*' },
);
