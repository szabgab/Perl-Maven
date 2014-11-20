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

get '/admin/user_info' => sub {
	if ( not logged_in() ) {
		return to_json { error => 'not_logged_in' };
	}

	if ( not is_admin() ) {
		return to_json { error => 'no_admin_rights' };
	}
	if ( not param('email') ) {
		return to_json { error => 'no_email_provided' };
	}

	my $db     = setting('db');
	my $people = $db->get_people( param('email') );
	if ( @$people > 20 ) {
		return to_json { error => 'too_many_hits' };
	}

	foreach my $p (@$people) {
		$p->[2] //= '';
		my @subs = $db->get_subscriptions( $p->[1] );
		$p->[3] = \@subs;
	}
	return to_json { people => $people };

};

true;

