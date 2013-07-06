package Perl::Maven::Admin;
use Dancer ':syntax';
use Perl::Maven::DB;

get '/admin' => sub {
	return 'Admin';
};

true;

# vim:noexpandtab
# vim:ts=4

