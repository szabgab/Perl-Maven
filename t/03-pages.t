use strict;
use warnings;

use Test::Most;
use Test::Deep;

plan tests => 6;

use Perl::Maven::Config;
use Perl::Maven::Page;

$ENV{METAMETA} = 1;

subtest one => sub {
	plan tests => 2;

	my $path = 't/files/1.txt';
	my $data = eval {
		Perl::Maven::Page->new( media => 't/file/media', root => 't/files', file => $path )->read->process->data;
	};
	ok !$@, "load $path" or diag $@;

	cmp_deeply $data,
		{
		'abstract'               => '',
		'archive'                => '1',
		'author'                 => 'szabgab',
		'books'                  => ['beginner_book'],
		'comments_disqus_enable' => '1',
		'indexes'                => ['files'],
		'mycontent'              => re('<p>\s*Some text here in 1.txt\s*<p>'),
		'show_newsletter_form'   => 1,
		'related'                => [],
		'tags'                   => [ 'perl', 'python' ],
		'show_social'            => '1',
		'status'                 => 'draft',
		'timestamp'              => '2014-01-15T07:30:01',
		'title'                  => 'Test 1'
		};
};

subtest indexes => sub {
	plan tests => 2;

	my $path = 't/files/3.txt';
	my $data = eval {
		Perl::Maven::Page->new( media => 't/file/media', root => 't/files', file => $path )->read->process->data;
	};
	ok !$@, "load $path" or diag $@;

	cmp_deeply $data,
		{
		'abstract'               => '',
		'archive'                => '1',
		'author'                 => 'szabgab',
		'comments_disqus_enable' => '0',
		'indexes'                => [ 'files', 'and', 'other::values' ],
		'mycontent'              => re('<p>\s*Some text here in 3.txt\s*<p>'),
		'show_newsletter_form'   => 0,
		'tags'                   => ['perl'],
		'show_date'              => 1,
		'related'                => [],
		'show_right'             => 0,
		'show_social'            => '0',
		'status'                 => 'draft',
		'timestamp'              => '2014-01-15T07:30:01',
		'title'                  => 'Test 3'
		};
};

my %cases = (
	missing_title => qq{Header ended and 'title' was not supplied for file t/files/missing_title.txt\n},
	invalid_field => qq{Invalid entry in header 'darklord' file t/files/invalid_field.txt\n},
	invalid_field_before_optional =>
		qq{Invalid entry in header 'darklord' file t/files/invalid_field_before_optional.txt\n},

	no_timestamp      => qq{Header ended and 'timestamp' was not supplied for file t/files/no_timestamp.txt\n},
	invalid_timestamp => qq{Invalid =timestamp '2014-01-151T07:30:01' in file t/files/invalid_timestamp.txt\n},
	empty_timestamp   => qq{=timestamp missing in file t/files/empty_timestamp.txt\n},
);

subtest errors => sub {
	plan tests => scalar keys %cases;

	foreach my $name ( sort keys %cases ) {
		my $path = "t/files/$name.txt";
		my $data = eval {
			Perl::Maven::Page->new( media => 't/file/media', root => 't/files', file => $path )->read->process->data;
		};
		is $@, $cases{$name}, $name;
	}
};

subtest bad_timestamp => sub {
	plan tests => 1;

	my $path = 't/files/bad_timestamp.txt';
	my $data = eval {
		Perl::Maven::Page->new( media => 't/file/media', root => 't/files', file => $path )->read->process->data;
	};
	like $@,
		qr{The 'day' parameter \("32"\) to DateTime::new did not pass the 'an integer which is a possible valid day of month' callback};
	qr{Validation failed for type named DayOfMonth declared in package DateTime::Types};
};

subtest abstract_not_ending => sub {
	plan tests => 3;

	my $path = 't/files/abstract_not_ending.txt';
	my $data = eval {
		Perl::Maven::Page->new( media => 't/file/media', root => 't/files', file => $path )->read->process->data;
	};
	like $@, qr{=abstract started but not ended};

	# repeate the first one because there was a bug
	# it was including the content as the abstract due to the missing and of abstract in the previous file

	my $path_1 = 't/files/1.txt';
	my $data_1 = eval {
		Perl::Maven::Page->new( media => 't/file/media', root => 't/files', file => $path_1 )->read->process->data;
	};
	ok !$@, "load $path_1" or diag $@;

	cmp_deeply $data_1,
		{
		'abstract'               => '',
		'archive'                => '1',
		'author'                 => 'szabgab',
		'books'                  => ['beginner_book'],
		'comments_disqus_enable' => '1',
		'indexes'                => ['files'],
		'mycontent'              => re('<p>\s*Some text here in 1.txt\s*<p>'),
		'tags'                   => [ 'perl', 'python' ],
		'show_newsletter_form'   => 1,
		'related'                => [],
		'show_social'            => '1',
		'status'                 => 'draft',
		'timestamp'              => '2014-01-15T07:30:01',
		'title'                  => 'Test 1'
		};
};

subtest one_with_config => sub {
	plan tests => 2;

	my $path    = 't/files/1.txt';
	my $mymaven = Perl::Maven::Config->new('t/files/config/mymaven.yml');
	my $data    = eval {
		Perl::Maven::Page->new( media => 't/file/media', root => 't/files', file => $path )
			->read->process->merge_conf( $mymaven->config('perlmaven.com')->{conf} )->data;
	};
	ok !$@, "load $path" or diag $@;

	cmp_deeply $data,
		{
		'abstract' => '',
		'author'   => 'szabgab',
		'tags'     => [ 'perl', 'python' ],
		'books'    => ['beginner_book'],
		'conf'     => {
			'archive'                => '1',
			'comments_disqus_enable' => '1',
			'show_newsletter_form'   => 1,
			'show_social'            => '1',
			'comments_disqus_code'   => 'perl5maven',
			'google_analytics'       => 'UA-11111112-3',
			'show_indexes'           => '1',
			'show_date'              => 1,
		},
		'indexes'   => ['files'],
		'mycontent' => re('<p>\s*Some text here in 1.txt\s*<p>'),
		'related'   => [],
		'status'    => 'draft',
		'timestamp' => '2014-01-15T07:30:01',
		'title'     => 'Test 1'
		};
};

