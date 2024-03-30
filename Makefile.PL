use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME         => 'Perl::Maven',
	AUTHOR       => q{Gabor Szabo <szabgab@cpan.org>},
	VERSION_FROM => 'lib/Perl/Maven.pm',
	ABSTRACT     => 'Web application running the Perl Maven sites',
	( $ExtUtils::MakeMaker::VERSION >= 6.3002
		? ( 'LICENSE' => 'perl' )
		: () ),
	PL_FILES  => {},
	PREREQ_PM => {
		'Carp::Always'    => 0,
		'Dancer2'         => 0.156001,
		'List::MoreUtils' => 0,

		'Dancer2::Plugin::Passphrase' => '2.0.5',
		'Dancer2::Session::Cookie'    => 0,
		'Data::ICal'                  => 0,
		'Data::ICal::Entry::Event'    => 0,
		'DateTime'                    => 1.12,
		'DateTime::Format::ICal'      => 0,
		'DateTime::Duration'          => 0,
		'DateTime::Tiny'              => 0,          #test fails and we should probably stop using it
		'Email::Valid'                => 1.193,
		'File::Find::Rule'            => 0.33,
		'Hash::Merge::Simple'         => 0.051,
		'Moo'                         => 1.006000,
		'Path::Tiny'                  => 0,
		'Plack'                       => 1.0031,
		'Storable'                    => 2.51,       # dclone is used
		'Template'                    => 2.25,
		'Time::HiRes'                 => 0,
		'YAML'                        => 1.09,
		'YAML::XS'                    => 0.59,
		'JSON'                        => 2.90,
		'Cpanel::JSON::XS'            => 3.0115,
		'Web::Feed'                   => 0.07,
		'Digest::SHA'                 => 5.92,
		'Data::Structure::Util'       => 0,

		'Crypt::URandom'          => 0,              # recommended by Dancer2
		'Math::Random::ISAAC::XS' => 0,              # recommended by Dancer2
		'Scope::Upper'            => 0,              # recommended by Dancer2
		'URL::Encode::XS'         => 0,              # recommended by Dancer2

		# needed for bin/perl_analyze.pl
		'JSON::XS' => 0,                             # should be replaced!

		# For testing
		'Test::More'   => 1,
		'Test::Most'   => 0.34,
		'Test::Script' => 1.07,

		# For deployment
		'Starman'         => 0.4009,
		'Daemon::Control' => 0.001005,

		# not really needed but good to have on the server:
		'App::Ack'        => 0,
		'Module::Version' => 0,
	},
	dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
	clean => { FILES    => 'Perl-Maven-*' },
);
