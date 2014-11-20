package Perl::Maven::Admin;
use Dancer ':syntax';

#use Perl::Maven::DB;
use Perl::Maven::WebTools qw(logged_in is_admin);

our $VERSION = '0.11';

get '/admin' => sub {
	if ( not logged_in() ) {
		session url => request->path;
		return redirect '/login';
	}

	if ( not is_admin() ) {
		return 'You dont have admin rights';
	}

	return 'Admin';
};

true;

