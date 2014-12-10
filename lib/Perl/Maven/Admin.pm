package Perl::Maven::Admin;
use Dancer ':syntax';

use Perl::Maven::WebTools qw(mymaven logged_in is_admin get_ip valid_ip _generate_code);
use Perl::Maven::Sendmail qw(send_mail);

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

		my $html = template 'email_to_whitelist_ip_address', { url => uri_for('/verify2'), ip => $ip, code => $code },
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
			return template 'error', { could_not_send_email => 1, email => $user->{email} };
		}

		return template 'error', { invalid_ip => 1, ip => $ip };
	}

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

