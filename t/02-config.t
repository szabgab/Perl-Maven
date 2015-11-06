use strict;
use warnings;

use Test::Most;
use Cwd qw(abs_path);

use t::lib::Test;

plan tests => 2;

my $root = abs_path('.');

use Perl::Maven::Config;

subtest mymaven => sub {
	plan tests => 11;

	my $mymaven = Perl::Maven::Config->new('t/files/config/mymaven.yml');
	my $main    = $mymaven->config('perlmaven.com');
	my $br      = $mymaven->config('br.perlmaven.com');
	my $cn      = $mymaven->config('cn.perlmaven.com');

	is $main->{site}, "$root/t/files/../sites/perlmaven.com/sites/en";
	is $main->{meta}, '/home/foobar/perlmaven-meta';
	is $main->{dirs}{mail}, "$root/t/files/../articles/mail";
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
		'mail'     => "$root/t/files/../articles/mail",
		'media'    => '/home/foobar/media.perlmaven.com',
		'pro'      => '/home/foobar/articles/pro'
		};

	is_deeply $br->{dirs}, { 'img' => '/home/foobar/perlmaven.com/sites/en/img' };
	is_deeply $main->{conf}, {
		'comments_disqus_enable' => '1',
		'comments_disqus_code'   => 'perl5maven',
		'google_analytics'       => 'UA-11111112-3',
		'show_indexes'           => '1',
		'show_newsletter_form'   => '1',
		'show_date'              => 1,

		},
		'main conf';
	is_deeply $br->{conf},
		{
		'comments_disqus_code'   => 'br-test-perlmaven',
		'comments_disqus_enable' => '1',
		'google_analytics'       => 'UA-11111112-3',
		'show_indexes'           => '1',
		'show_newsletter_form'   => '0',
		'show_date'              => 1,
		},
		'br conf';
	is_deeply $cn->{conf},
		{
		'comments_disqus_enable' => '0',
		'google_analytics'       => 'UA-11111112-3',
		'show_indexes'           => '1',
		'show_newsletter_form'   => '0',
		'show_date'              => 1,
		};
};

subtest testmaven => sub {
	plan tests => 1;

	my $mymaven = Perl::Maven::Config->new('t/files/config/test.yml');
	my $main    = $mymaven->config($t::lib::Test::DOMAIN);

	#diag explain $main;
	is_deeply $main,
		{
		'conf' => {
			'show_newsletter_form' => '1'
		},
		free_product => 'some_free_product',
		'dirs'       => {
			'download' => "$root/t/files/download",
			'pro'      => "$root/t/files/pro",
			'img'      => "$root/t/files/images",
		},
		'domain'    => $t::lib::Test::DOMAIN,
		'main_site' => 'en',
		'from'      => '<test@perlmaven.com>',
		'lang'      => 'en',
		'meta'      => 't/files/',
		'root'      => "$root/t/files/test",
		'meta'      => "$root/t/files/meta",
		'title'     => 'Test Maven',
		'series'    => 0,
		'site'      => "$root/t/files/test/sites/en",
		'admin'     => {
			'email' => 'Test Maven <admin-test@perlmaven.com>'
		},
		'www' => {
			'redirect' => "http://$t::lib::Test::DOMAIN/"
		}
		};

};

