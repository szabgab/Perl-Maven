package Perl::Maven::Admin;
use Dancer2 appname => 'Perl::Maven';

use Perl::Maven::WebTools qw(mymaven logged_in is_admin get_ip valid_ip _generate_code pm_error pm_template);
use Perl::Maven::Sendmail qw(send_mail);

our $VERSION = '0.11';

get '/admin' => sub {
	my $res = admin_check();
	return $res if $res;

	my $db = setting('db');
	return pm_template 'admin', { stats => $db->stats };
};

get '/admin/redirects' => sub {
	my $res = admin_check();
	return $res if $res;

	return pm_template 'admin_redirects';
};

get '/admin/sessions' => sub {
	my $res = admin_check();
	return $res if $res;

	my $client     = MongoDB::MongoClient->new( host => 'localhost', port => 27017 );
	my $database   = $client->get_database('PerlMaven');
	my $collection = $database->get_collection('logging');
	my $end        = time;
	my $start      = $end - 60 * 60 * 24;
	my %selector   = ( time => { '$gt', $start, '$lt', $end }, );
	my $count      = $collection->find( \%selector )->count;
	my $cursor     = $collection->find( \%selector )->sort( { time => 1 } )->limit(10);
	my @hits;

	while ( my $c = $cursor->next ) {
		push @hits, $c;
	}

	return pm_template 'admin_sessions', { count => $count, hits => \@hits };
};

get '/admin/user_info.json' => sub {
	my $res = admin_check();
	return $res if $res;

	if ( not param('email') ) {
		return to_json { error => 'no_email_provided' };
	}

	my $db     = setting('db');
	my $people = $db->get_people( param('email') );
	if ( @$people > 20 ) {
		return to_json { error => 'too_many_hits' };
	}

	# TODO the to_json won't work if there are Objects in any of the fields
	foreach my $p (@$people) {
		$p->{verify_time} //= '';
		delete $p->{_id};
		delete $p->{password};
		$p->{admin}        = $p->{admin}        ? 1 : 0;
		$p->{whitelist_on} = $p->{whitelist_on} ? 1 : 0;
		delete $p->{register_time};
		delete $p->{verify_time};
	}

	#debug($people);
	return to_json { people => $people };
};

sub admin_check {
	if ( not logged_in() ) {
		return pm_error('not_logged_in');
	}

	if ( not is_admin() ) {
		return pm_error('no_admin_rights');
	}

	my $db = setting('db');

	if ( not valid_ip() ) {
		my $ip      = get_ip();
		my $code    = _generate_code();
		my $uid     = session('uid');
		my $user    = $db->get_user_by_id($uid);
		my $mymaven = mymaven;

		$db->save_verification(
			code      => $code,
			action    => 'add_to_whitelist',
			timestamp => time,
			uid       => $uid,
			details   => to_json {
				ip => $ip,
			},
		);

		my $html = template 'email_to_whitelist_ip_address', { url => uri_for(''), ip => $ip, code => $code },
			{ layout => 'email', };
		my $err = send_mail(
			{
				From    => $mymaven->{from},
				To      => $user->{email},
				Subject => "White-listing IP address for $mymaven->{title}",
			},
			{
				html => $html,
			}
		);

		if ($err) {
			return pm_error( 'could_not_send_email', params => [ $user->{email} ], );
		}

		return pm_error( 'invalid_ip', params => [$ip] );
	}

	return;
}

true;

