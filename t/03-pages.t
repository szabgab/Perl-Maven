use strict;
use warnings;

use Test::More;
use Test::Deep;

plan tests => 5;

use Perl::Maven::Page;

$ENV{METAMETA} = 1;

subtest one => sub {
	plan tests => 2;

	my $path = 't/files/1.tt';
	my $data = eval { Perl::Maven::Page->new( file => $path )->read };
	ok !$@, "load $path" or diag $@;

	cmp_deeply $data,
		{
		'abstract'   => '',
		'archive'    => '1',
		'author'     => 'szabgab',
		'books'      => 'beginner_book',
		'comments'   => '1',
		'content'    => '',
		'indexes'    => ['files'],
		'mycontent'  => re('<p>\s*Some text here\.\s*<p>'),
		'newsletter' => 1,
		'published'  => 1,
		'related'    => [],
		'showright'  => 1,
		'social'     => '1',
		'status'     => 'draft',
		'timestamp'  => '2014-01-15T07:30:01',
		'title'      => 'Test 1'
		};
};

subtest indexes => sub {
	plan tests => 2;

	my $path = 't/files/3.tt';
	my $data = eval { Perl::Maven::Page->new( file => $path )->read };
	ok !$@, "load $path" or diag $@;

	cmp_deeply $data,
		{
		'abstract'   => '',
		'archive'    => '1',
		'author'     => 'szabgab',
		'comments'   => '1',
		'content'    => '',
		'indexes'    => [ 'files', 'and', 'other::values' ],
		'mycontent'  => re('<p>\s*Some text here\.\s*<p>'),
		'newsletter' => 1,
		'published'  => 1,
		'related'    => [],
		'showright'  => 1,
		'social'     => '0',
		'status'     => 'draft',
		'timestamp'  => '2014-01-15T07:30:01',
		'title'      => 'Test 3'
		};
};

my %cases = (
	missing_title =>
		qq{Header ended and 'title' was not supplied for file t/files/missing_title.tt\n},
	invalid_field =>
		qq{Invalid entry in header 'darklord' file t/files/invalid_field.tt\n},
	invalid_field_before_optional =>
		qq{Invalid entry in header 'darklord' file t/files/invalid_field_before_optional.tt\n},

	no_timestamp =>
		qq{Header ended and 'timestamp' was not supplied for file t/files/no_timestamp.tt\n},
	invalid_timestamp =>
		qq{Invalid =timestamp '2014-01-151T07:30:01' in file t/files/invalid_timestamp.tt\n},
	empty_timestamp =>
		qq{=timestamp missing in file t/files/empty_timestamp.tt\n},
);

subtest errors => sub {
	plan tests => scalar keys %cases;

	foreach my $name ( sort keys %cases ) {
		my $path = "t/files/$name.tt";
		my $data = eval { Perl::Maven::Page->new( file => $path )->read };
		is $@, $cases{$name}, $name;
	}
};

subtest bad_timestamp => sub {
	plan tests => 1;

	my $path = 't/files/bad_timestamp.tt';
	my $data = eval { Perl::Maven::Page->new( file => $path )->read };
	like $@,
		qr{The 'day' parameter \("32"\) to DateTime::new did not pass the 'an integer which is a possible valid day of month' callback};
};

subtest abstract_not_ending => sub {
	plan tests => 1;

	my $path = 't/files/abstract_not_ending.tt';
	my $data = eval { Perl::Maven::Page->new( file => $path )->read };
	like $@, qr{=abstract started but not ended};

	}

