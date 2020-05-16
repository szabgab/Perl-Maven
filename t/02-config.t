use strict;
use warnings;

use Test::Most;
use Cwd qw(abs_path);
use Data::Dumper qw(Dumper);
use File::Basename qw(dirname);

use t::lib::Test;

plan tests => 3;

my $root = abs_path('.');
diag $root;

my $parent = dirname $root;

# Inside the Docker image we need en empty string here:
if ( not $ENV{TRAVIS} ) {
	$parent = '';
}

use Perl::Maven::Config;

subtest mymaven => sub {
	plan tests => 13;

	my $mymaven = Perl::Maven::Config->new('t/files/config/mymaven.yml');
	is_deeply $mymaven->{hosts},
		{
		'br.perlmaven.com'  => 'perlmaven.com',
		'cn.perlmaven.com'  => 'perlmaven.com',
		'he.perlmaven.com'  => 'perlmaven.com',
		'perlmaven.com'     => 'perlmaven.com',
		'code-maven.com'    => 'code-maven.com',
		'ru.code-maven.com' => 'code-maven.com',
		},
		'hosts';

	my $main = $mymaven->config('perlmaven.com');
	my $br   = $mymaven->config('br.perlmaven.com');
	my $cn   = $mymaven->config('cn.perlmaven.com');
	eval { $mymaven->config('qq.perlmaven.com') };
	like $@, qr{Hostname 'qq.perlmaven.com' not in configuration file\n}, 'missing hostname';

	is $main->{site}, "$root/t/files/../sites/perlmaven.com/sites/en", '{site}';
	is $main->{meta}, '/home/foobar/perlmaven-meta',                   '{meta}';
	is $main->{dirs}{mail}, "$root/t/files/../articles/mail", '{dirs}{mail}';
	is $main->{dirs}{pro},  '/home/foobar/articles/pro',      '{dirs}{pro}';
	is_deeply $main->{redirect},
		{
		'abc'      => 'def',
		'szg'      => 'https://szabgab.com/?r=12345',
		'products' => 'https://perlmaven.com/products',
		},
		'$main->{redirect}';

	is_deeply $br->{redirect}, {
		'products'    => 'https://perlmaven.com/products',
		'old-article' => 'new-article',
		'abc'         => 'other-page',

		'szg' => 'https://szabgab.com/?r=12345',
		},
		'$br->{redirect}';
	is_deeply $main->{dirs},
		{
		'articles' => '/home/foobar/articles',
		'download' => '/home/foobar/articles/download',
		'img'      => '/home/foobar/perlmaven.com/sites/en/img',
		'mail'     => "$root/t/files/../articles/mail",
		'media'    => '/home/foobar/media.perlmaven.com',
		'pro'      => '/home/foobar/articles/pro'
		},
		'$main->{dirs}';

	is_deeply $br->{dirs}, { 'img' => '/home/foobar/perlmaven.com/sites/en/img' }, '$br->{dirs}';
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
		},
		'$cn->{conf}';
};

subtest testmaven => sub {
	plan tests => 2;

	my $mymaven = Perl::Maven::Config->new('t/files/config/test.yml');
	is_deeply $mymaven->{hosts}, { 'test-pm.com' => 'test-pm.com', }, 'hosts';

	my $main = $mymaven->config($t::lib::Test::DOMAIN);

	#diag Dumper $main->{feeds};
	is_deeply $main, {
		'conf' => {
			'show_newsletter_form' => '1'
		},
		'dbfile'       => 'test_abc.db',
		'free_product' => 'some_free_product',
		'dirs'         => {
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
		'feed_size' => 2,
		'feeds'     => {
			'__main__' => {
				'description' => 'Test description for feed',
				'subtitle'    => 'A show about Perl and Perl users',
				'copyright'   => '2014 Gabor Szabo',
				'author'      => 'Gabor Szabo',
				'image'       => 'https://code-maven.com/img/code_maven_128.png',
				'keywords'    => [ 'code-maven', 'open source', 'software', 'development', 'news', ],
			}
		},
		'series' => 0,
		'site'   => "$root/t/files/test/sites/en",
		'admin'  => {
			'email' => 'Test Maven <admin-test@perlmaven.com>'
		},
		'www' => {
			'redirect' => "https://$t::lib::Test::DOMAIN/"
		}
	};

};

subtest skeleton => sub {
	plan tests => 2;

	my $mymaven = Perl::Maven::Config->new('config_mymaven.yml');
	is_deeply $mymaven->{hosts},
		{
		'perlmaven.com'    => 'perlmaven.com',
		'br.perlmaven.com' => 'perlmaven.com',
		'cn.perlmaven.com' => 'perlmaven.com',
		'ne.perlmaven.com' => 'perlmaven.com',
		'ro.perlmaven.com' => 'perlmaven.com',
		'fr.perlmaven.com' => 'perlmaven.com',
		'cs.perlmaven.com' => 'perlmaven.com',
		'id.perlmaven.com' => 'perlmaven.com',
		'te.perlmaven.com' => 'perlmaven.com',
		'es.perlmaven.com' => 'perlmaven.com',
		'ru.perlmaven.com' => 'perlmaven.com',
		'ko.perlmaven.com' => 'perlmaven.com',
		'eo.perlmaven.com' => 'perlmaven.com',
		'tw.perlmaven.com' => 'perlmaven.com',
		'tr.perlmaven.com' => 'perlmaven.com',
		'it.perlmaven.com' => 'perlmaven.com',
		'de.perlmaven.com' => 'perlmaven.com',
		'he.perlmaven.com' => 'perlmaven.com',
		},
		'hosts';

	my $main = $mymaven->config('perlmaven.com');

	my $dmp    = Dumper $main;
	my $dotdot = index( $dmp, '..' );

	# TODO: is $dotdot, -1, $dmp;

	# TODO: fix the pathes and enable the tests
	pass;

	#is_deeply $main,
	#	{
	#	'index' => ['pro'],
	#	'from'  => 'Perl Maven <gabor@perlmaven.com>',
	#	'site'  => "$parent/../perlmaven.com/sites/en",
	#	'www'   => {
	#		'redirect' => 'https://perlmaven.com/'
	#	},
	#	'domain' => 'perlmaven.com',
	#	'root'   => "$parent/../perlmaven.com",
	#	'prefix' => '[Perl Maven]',
	#	'lang'   => 'en',
	#	'free'   => ['/pro/beginner-perl/process-command-line-using-getopt-long-screencast'],
	#	'dirs'   => {
	#		'img'      => "$parent/../perlmaven.com/sites/en/img",
	#		'articles' => "$parent/../articles",
	#		'pro'      => "$parent/../articles/pro",
	#		'mail'     => "$parent/../articles/mail",
	#		'download' => "$parent/../articles/download",
	#		'media'    => "$parent/../media.perlmaven.com",
	#	},
	#	'conf' => {
	#		'show_social'            => '1',
	#		'show_archive_selector'  => '1',
	#		'archive'                => '1',
	#		'show_newsletter_form'   => '1',
	#		'show_indexes'           => '1',
	#		'show_right'             => '1',
	#		'show_date'              => '1',
	#		'comments_disqus_enable' => '1',
	#		'show_related'           => '1',
	#		'comments_disqus_code'   => 'perl5maven',
	#		'show_language_links'    => '1'
	#	},
	#	'paypal' => {
	#		'email' => 'gabor@szabgab.com'
	#	},
	#	'feed_size'         => '10',
	#	'main_site'         => 'en',
	#	'main_page_entries' => '3',
	#	'admin'             => {
	#		'email' => 'Gabor Szabo <gabor@szabgab.com>'
	#	},
	#	'listid'   => 'Perl Maven newsletter <newsletter.perlmaven.com>',
	#	'title'    => 'Perl Maven',
	#	'redirect' => {
	#		'videos/oop-with-moo' => '/oop-with-moo'
	#	},
	#	'meta' => "$parent/meta/perlmaven.com"
	#	};
};

