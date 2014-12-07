use strict;
use warnings;

use Test::More;

plan tests => 2;

use Perl::Maven::Config;

subtest mymaven => sub {
	plan tests => 11;

	my $mymaven = Perl::Maven::Config->new('t/files/config/mymaven.yml');
	my $main    = $mymaven->config('perlmaven.com');
	my $br      = $mymaven->config('br.perlmaven.com');
	my $cn      = $mymaven->config('cn.perlmaven.com');

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
	is_deeply $main->{dirs},
		{
		'articles' => '/home/foobar/articles',
		'download' => '/home/foobar/articles/download',
		'img'      => '/home/foobar/perlmaven.com/sites/en/img',
		'mail'     => 't/files/../articles/mail',
		'media'    => '/home/foobar/media.perlmaven.com',
		'pro'      => '/home/foobar/articles/pro'
		};

	is_deeply $br->{dirs}, { 'img' => '/home/foobar/perlmaven.com/sites/en/img' };
	is_deeply $main->{conf}, {
		'clicky'                 => '12345678',
		'comments_disqus_enable' => '1',
		'comments_disqus_code'   => 'perl5maven',
		'google_analytics'       => 'UA-11111112-3',
		'show_indexes'           => '1',
		'show_newsletter_form'   => '1',
		'show_sponsors'          => '0',
		'show_date'              => 1,

		},
		'main conf';
	is_deeply $br->{conf},
		{
		'clicky'                 => '12345678',
		'comments_disqus_code'   => 'br-test-perlmaven',
		'comments_disqus_enable' => '1',
		'google_analytics'       => 'UA-11111112-3',
		'show_indexes'           => '1',
		'show_newsletter_form'   => '0',
		'show_sponsors'          => '0',
		'show_date'              => 1,
		},
		'br conf';
	is_deeply $cn->{conf},
		{
		'clicky'                 => '12345678',
		'comments_disqus_enable' => '0',
		'google_analytics'       => 'UA-11111112-3',
		'show_indexes'           => '1',
		'show_newsletter_form'   => '0',
		'show_sponsors'          => '0',
		'show_date'              => 1,
		};
};

subtest testmaven => sub {
	plan tests => 1;

	my $mymaven = Perl::Maven::Config->new('t/files/config/test.yml');
	my $main    = $mymaven->config('test-perl-maven.com');

	#diag explain $main;
	is_deeply $main,
		{
		'conf' => {
			'show_newsletter_form' => '1'
		},
		'dirs' => {
			'download' => 't/files/download',
			'pro'      => 't/files/pro',
		},
		'domain'    => 'test-perl-maven.com',
		'main_site' => 'en',
		'from'      => '<test@perlmaven.com>',
		'lang'      => 'en',
		'meta'      => 't/files/',
		'root'      => 't/files/test',
		'meta'      => 't/files/meta',
		'title'     => 'Test Maven',
		'site'      => 't/files/test/sites/en',
		'admin'     => {
			'email' => 'Test Maven <admin-test@perlmaven.com>'
		},
		'www' => {
			'redirect' => 'http://test-perl-maven.com/'
		}
		};

};

