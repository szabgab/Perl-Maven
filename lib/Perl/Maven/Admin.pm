package Perl::Maven::Admin;
use Dancer ':syntax';

#use Perl::Maven::DB;
use Perl::Maven::WebTools qw(logged_in);

our $VERSION = '0.11';

get '/admin' => sub {
	if ( not logged_in() ) {
		session url => request->path;
		return redirect '/login';
	}
	return 'Admin';
};

true;

