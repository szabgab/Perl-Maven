use strict;
use warnings;

use Test::More;

plan tests => 2;

use Perl::Maven::Config;

subtest mymaven => sub {
	plan tests => 6,

		my $mymaven = Perl::Maven::Config->new('t/files/mymaven.yml');
	my $main = $mymaven->config('perlmaven.com');
	my $br   = $mymaven->config('br.perlmaven.com');

	is $main->{site}, 't/files/../sites/perlmaven.com/sites/en';
	is $main->{meta}, '/home/foobar/perlmaven-meta';
	is $main->{dirs}{mail}, 't/files/../articles/mail';
	is $main->{dirs}{pro},  '/home/foobar/articles/pro';
	is_deeply $main->{redirect},
		{
		'abc'      => 'def',
		'szg'      => 'http://szabgab.com/?r=12345',
		'products' => 'http://perlmaven.com/products',
		};

	is_deeply $br->{redirect}, {
		'products'    => 'http://perlmaven.com/products',
		'old-article' => 'new-article',
		'abc'         => 'other-page',

		'szg' => 'http://szabgab.com/?r=12345',
	};
};

subtest testmaven => sub {
	plan tests => 1;

	my $mymaven = Perl::Maven::Config->new('t/files/test.yml');
	my $main    = $mymaven->config('test-perl-maven.com');

	#diag explain $main;
	is_deeply $main,
		{
		'conf' => {
			'right_search'         => '0',
			'show_newsletter_form' => '1'
		},
		'dirs' => {
			'download' => 't/files/download',
			'pro'      => 't/files/pro',
		},
		'domain' => {
			'redirect' => '0',
			'site'     => 'en'
		},
		'from'  => '<test@perlmaven.com>',
		'lang'  => 'en',
		'meta'  => 't/files/',
		'root'  => 't/files/test',
		'meta'  => 't/files/meta',
		'title' => 'Test Maven',
		'site'  => 't/files/test/sites/en',
		'www'   => {
			'redirect' => 'http://test-perl-maven.com/'
		}
		};

};

