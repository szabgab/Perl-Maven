package Perl::Maven::Admin;
use Dancer ':syntax';
use Perl::Maven::DB;

our $VERSION = '0.11';

get '/admin' => sub {
	return 'Admin';
};

true;

# vim:noexpandtab
# vim:ts=4

