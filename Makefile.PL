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
		'Acme::MetaSyntactic' => 1.012,      # or even Task::MetaSyntactic
		'Business::PayPal'    => 0.13,
		'Carp::Always'        => 0,
		'Code::Explain'       => 0.02,
		'Dancer2'             => 0.156001,

#'Dancer2::Plugin::Passphrase' => '2.0.4', TODO2 http://lists.preshweb.co.uk/pipermail/dancer-users/2014-December/004213.html
		'DateTime'            => 1.12,
		'DBD::SQLite'         => 1.42,
		'DBI'                 => 1.631,
		'DBIx::RunSQL'        => 0.12,
		'Email::Valid'        => 1.193,
		'File::Find::Rule'    => 0.33,
		'Hash::Merge::Simple' => 0.051,
		'MongoDB'             => 0,
		'Moo'                 => 1.006000,
		'Path::Tiny'          => 0,
		'Plack'               => 1.0031,
		'Storable'            => 2.51,       # dclone is used
		'SVG'                 => 0,          # for Perl::Maven::SVG
		'Template'            => 2.25,
		'Time::HiRes'         => 0,
		'YAML'                => 1.09,
		'JSON'                => 2.90,
		'Web::Feed'           => 0.02,
		'Digest::SHA'         => 5.92,

		'Crypt::URandom'          => 0,      # recommended by Dancer2
		'Math::Random::ISAAC::XS' => 0,      # recommended by Dancer2
		'Scope::Upper'            => 0,      # recommended by Dancer2
		'URL::Encode::XS'         => 0,      # recommended by Dancer2

		'Email::Sender::Simple' => 1.300012,
		'Email::MIME::Creator'  => 1.926,
		'Email::Stuffer'        => 0,

		# For testing
		'Test::WWW::Mechanize'       => 1.44,
		'Test::WWW::Mechanize::PSGI' => 0.35,
		'Test::More'                 => 1,
		'Test::Script'               => 1.07,

		# For deployment
		'Starman'         => 0.4009,
		'Daemon::Control' => 0.001005,

		'MetaCPAN::API' => 0,    # for bin/cpan_monitor.pl
	},
	dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
	clean => { FILES    => 'Perl-Maven-*' },
);
