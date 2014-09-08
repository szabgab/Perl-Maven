use strict;
use warnings;

use Test::More;
use Test::Deep;

plan tests => 2;

use Perl::Maven::Page;

$ENV{METAMETA} = 1;

subtest one => sub {
	plan tests => 2;

	my $path = 't/files/1.tt';
	my $data = eval { Perl::Maven::Page->new(file => $path)->read };
	ok !$@, "load $path" or diag $@;
	
	cmp_deeply $data, {
	   'abstract' => '',
	   'archive' => '1',
	   'author' => 'szabgab',
	   'books' => 'beginner_book',
	   'comments' => '1',
	   'content' => '',
	   'indexes' => [
	     'files'
	   ],
	   'mycontent' => re('<p>\s*Some text here\.\s*<p>'),
	   'newsletter' => 1,
	   'published' => 1,
	   'related' => [],
	   'showright' => 1,
	   'social' => '1',
	   'status' => 'draft',
	   'timestamp' => '2014-01-15T07:30:01',
	   'title' => 'Test 1'
	};
};

subtest invalid_timestamp => sub {
	plan tests => 1;

	my $path = 't/files/2.tt';
	my $data = eval { Perl::Maven::Page->new(file => $path)->read };
	is $@, qq{Invalid =timestamp '2014-01-151T07:30:01' in file t/files/2.tt\n};
};

