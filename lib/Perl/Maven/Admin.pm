package Perl::Maven::Admin;
use Dancer ':syntax';

use Perl::Maven::WebTools qw(logged_in is_admin);

our $VERSION = '0.11';

get '/admin' => sub {
	if ( not logged_in() ) {
		session url => request->path;
		return redirect '/login';
	}

	if ( not is_admin() ) {
		return template 'error', { no_admin_rights => 1 };
	}

	my $db = setting('db');
	return template 'admin', { stats => $db->stats };
};

true;

