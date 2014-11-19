use strict;
use warnings;
use Test::More tests => 9;

use File::Copy qw(move);
use Capture::Tiny qw(capture);
use Cwd qw(cwd);
use t::lib::Test;

BEGIN {
	t::lib::Test::setup();
}

use Perl::Maven::DB;
my $db = Perl::Maven::DB->new('pm.db');

my $admin = "$^X -Ilib bin/admin.pl";

subtest usage => sub {
	plan tests => 2;

	my ( $stdout, $stderr, @result ) = capture {
		system $admin;
	};
	like $stdout, qr{Usage: bin/admin.pl}, 'usage';
	is $stderr, '', 'stderr is empty';
};

subtest dump_products => sub {
	plan tests => 3;

	my $existing_products = {
		'perl_maven_cookbook' => {
			'name'  => 'Perl Maven Cookbook',
			'code'  => 'perl_maven_cookbook',
			'id'    => 1,
			'price' => 0
		},
		'beginner_perl_maven_ebook' => {
			'id'    => 2,
			'name'  => 'Beginner Perl Maven e-book',
			'code'  => 'beginner_perl_maven_ebook',
			'price' => '0.01'
		}
	};

	my $products = $db->get_products;
	is_deeply $products, $existing_products, 'get_products';

	my ( $stdout, $stderr, @result ) = capture {
		system "$admin --products --perl";
	};
	is_deeply re_dump($stdout), $existing_products, '--products --perl';
	is $stderr, '', 'stderr is empty';
};

subtest list_products => sub {
	plan tests => 2;

	my ( $stdout, $stderr, @result ) = capture {
		system "$admin --products";
	};
	is $stdout,
		q{ 2 beginner_perl_maven_ebook           Beginner Perl Maven e-book        0.01
 1 perl_maven_cookbook                 Perl Maven Cookbook                 0
}, '--products';
	is $stderr, '', 'stderr is empty';
};

subtest list_emails => sub {
	plan tests => 2;

	my $people = $db->get_people('@');
	is_deeply $people, [], 'no people';

	#	my @subs = $db->get_subscriptions('email@address');

	my ( $stdout, $stderr, @result ) = capture {
		system "$admin --email \@";
	};

	#diag $stdout;
	is $stderr, '', 'stderr is empty';
};

subtest stats => sub {
	plan tests => 2;

	my ( $stdout, $stderr, @result ) = capture {
		system "$admin --stats";
	};
	like $stdout, qr{Distinct # of clients};
	is $stderr, '', 'stderr is empty';
};

subtest list_subscribers => sub {
	plan tests => 2;

	my ( $stdout, $stderr, @result ) = capture {
		system "$admin --list perl_maven_cookbook";
	};
	is $stdout, '';
	is $stderr, '', 'stderr is empty';
};

subtest list_not_existsing_product => sub {
	plan tests => 2;

	my ( $stdout, $stderr, @result ) = capture {
		system "$admin --list other_product";
	};
	is $stdout, '';
	is $stderr, '', 'stderr is empty';
};

subtest add_subscriber => sub {
	plan tests => 3;

	my ( $stdout, $stderr, @result ) = capture {
		system "$admin --addsub perl_maven_cookbook --email a\@b.com";
	};
	like $stdout,   qr{Could not find user 'a\@b.com'};
	is $stderr,     '', 'stderr is empty';
	unlike $stderr, qr/DBD::.*failed/, 'no DBD error';
};

subtest add_client_to_not_exisiting_product => sub {
	plan tests => 3;

	my ( $stdout, $stderr, @result ) = capture {
		system "$admin --addsub other_thing --email a\@b.com";
	};
	like $stdout,   qr{Could not find product 'other_thing'};
	is $stderr,     '', 'stderr is empty';
	unlike $stderr, qr/DBD::.*failed/, 'no DBD error';
};

sub re_dump {
	my ($str) = @_;
	$str =~ s/\$VAR1 =//;

	#$str =~ s/^#//gm;
	## no critic
	my $data = eval $str;
	return $data;
}

