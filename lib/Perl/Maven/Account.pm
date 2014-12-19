package Perl::Maven::Account;
use Dancer2 appname => 'Perl::Maven';

use Dancer2::Plugin::Passphrase qw(passphrase);

use Perl::Maven::WebTools
	qw(mymaven logged_in get_ip _generate_code pm_error pm_message _registration_form pm_template);
use Perl::Maven::Sendmail qw(send_mail);

our $VERSION = '0.11';

post '/pm/whitelist' => sub {
	if ( not logged_in() ) {

		#session url => request->path;
		return redirect '/login';
	}
	my $do  = param('do');
	my $uid = session('uid');
	if ($do) {
		my $db = setting('db');
		if ( $do eq 'enable' ) {
			if ( $db->set_whitelist( $uid, 1 ) ) {
				my $ip   = get_ip();
				my $mask = '255.255.255.255';

				my $whitelist = $db->get_whitelist($uid);
				my $found = grep { $whitelist->{$_}{ip} eq $ip and $whitelist->{$_}{mask} eq $mask } keys %$whitelist;
				if ( not $found ) {
					$db->add_to_whitelist(
						{
							uid  => $uid,
							ip   => $ip,
							mask => $mask,
							note => 'Added automatically when whitelist was enabled'
						}
					);
				}
				return pm_message('whitelist_enabled');
			}
			else {
				return pm_error('internal_error');
			}
		}
		elsif ( $do eq 'disable' ) {
			$db->set_whitelist( $uid, 0 );
			return pm_message('whitelist_disabled');
		}
		else {
			return pm_error('invalid_value_provided');
		}
	}
	return 'parameter missing';
};

post '/pm/send-reset-pw-code' => sub {
	my $email = param('email');
	if ( not $email ) {
		return pm_error('no_email_provided');
	}
	$email = lc $email;
	my $db   = setting('db');
	my $user = $db->get_user_by_email($email);
	if ( not $user ) {
		return pm_error('invalid_email');
	}
	if ( not $user->{verify_time} ) {

		# TODO: send e-mail with verification code
		return pm_error('not_verified_yet');
	}

	my $code = _generate_code();
	$db->set_password_code( $user->{email}, $code );

	my $html = template 'email_to_reset_password',
		{
		url  => uri_for('/pm/set-password'),
		id   => $user->{id},
		code => $code,
		},
		{ layout => 'email', };

	my $mymaven = mymaven;
	my $err     = send_mail(
		{
			From    => $mymaven->{from},
			To      => $email,
			Subject => "Code to reset your $mymaven->{title} password",
		},
		{
			html => $html,
		}
	);
	if ($err) {
		return pm_error( 'could_not_send_email', params => [$email], );
	}

	pm_message('reset_password_sent');
};

get '/pm/set-password/:id/:code' => sub {
	my $error = pw_form();
	return $error if $error;
	template 'set_password',
		{
		id   => param('id'),
		code => param('code'),
		};
};

post '/pm/change-password' => sub {
	if ( not logged_in() ) {
		session url => request->path;
		return redirect '/login';
	}

	my $password  = param('password')  || '';
	my $password2 = param('password2') || '';

	return pm_error('no_password')
		if not $password;

	return pm_error('passwords_dont_match')
		if $password ne $password2;

	return pm_error('bad_password')
		if length($password) < 6;

	my $uid = session('uid');
	my $db  = setting('db');
	$db->set_password( $uid, passphrase($password)->generate->rfc2307 );

	pm_message('password_set');
};

post '/pm/set-password' => sub {
	my $error = pw_form();
	return $error if $error;

	my $db = setting('db');

	my $password = param('password');
	my $id       = param('id');
	my $user     = $db->get_user_by_id($id);

	return pm_error('bad_password')
		if not $password
		or length($password) < 6;

	session uid       => $user->{id};
	session logged_in => 1;
	session last_seen => time;

	$db->set_password( $id, passphrase($password)->generate->rfc2307 );

	pm_message('password_set');
};

post '/pm/update-user' => sub {
	if ( not logged_in() ) {
		session url => request->path;
		return redirect '/login';
	}

	my $name = param('name') || '';

	my $db  = setting('db');
	my $uid = session('uid');
	$db->update_user( $uid, name => $name );

	pm_message('user_updated');
};

get '/pm/subscribe' => sub {
	return redirect '/login' if not logged_in();

	my $uid = session('uid');
	my $db  = setting('db');
	$db->subscribe_to( uid => $uid, code => 'perl_maven_cookbook' );
	pm_message('subscribed');
};

get '/pm/un-subscribe' => sub {
	return redirect '/login' if not logged_in();

	my $uid = session('uid');

	my $db = setting('db');
	$db->unsubscribe_from( uid => $uid, code => 'perl_maven_cookbook' );
	pm_message('unsubscribed');
};

any '/pm/unsubscribe' => sub {
	my $code  = param('code');
	my $email = param('email');

	my $mymaven       = mymaven;
	my $expected_code = Digest::SHA::sha1_hex("unsubscribe$mymaven->{unsubscribe_salt}$email");
	if ( $code ne $expected_code ) {
		return pm_error('invalid_unsubscribe_code');
	}

	my $db   = setting('db');
	my $user = $db->get_user_by_email($email);
	if ( not $user ) {
		return pm_error('could_not_find_registration');
	}

	# TODO maybe we will want some stonger checking for confirmation?
	if ( param('confirm') ) {
		$db->unsubscribe_from( uid => $user->{id}, code => 'perl_maven_cookbook' );
		my $html    = template 'email_after_unsubscribe', { url => uri_for('/'), }, { layout => 'email' };
		my $mymaven = mymaven;
		my $err     = send_mail(
			{
				From    => $mymaven->{from},
				To      => $email,
				Subject => 'You were unsubscribed from the Perl Maven newsletter',
			},
			{
				html => $html,
			}
		);

		pm_message('unsubscribed');
	}

	return template 'confirm_unsubscribe',
		{
		code  => $code,
		email => $email,
		};
};

# TODO probably we would want to move the show_right control from here to a template file (if we really need it here)
get '/pm/register' => sub {
	return template 'registration_form', { show_right => 0, };
};

post '/pm/register.json' => sub {
	register();
};

post '/pm/register' => sub {
	register();
};

post '/pm/change-email' => sub {
	my $mymaven = mymaven;
	if ( not logged_in() ) {
		return redirect '/login';
	}
	my $email = param('email') || '';
	if ( not $email ) {
		return pm_error('no_email_provided');
	}
	if ( not Email::Valid->address($email) ) {
		return pm_error('broken_email');
	}

	# check for uniqueness after lc
	$email = lc $email;
	my $db         = setting('db');
	my $other_user = $db->get_user_by_email($email);
	if ($other_user) {
		return pm_error('email_exists');
	}

	my $uid = session('uid');

	my $code = _generate_code();
	$db->save_verification(
		code      => $code,
		action    => 'change_email',
		timestamp => time,
		uid       => $uid,
		details   => to_json {
			new_email => $email,
		},
	);
	my $err = send_verification_mail(
		'email_verification_code',
		$email,
		"Please verify your new e-mail address for $mymaven->{title}",
		{
			url  => uri_for('/verify2'),
			code => $code,
		},
	);
	if ($err) {
		return pm_error( 'could_not_send_email', params => [$email], );
	}

	pm_message('verification_email_sent');
};

##########################################################################################

sub register {
	my $mymaven = mymaven;

	my %data = (
		password => param('password'),
		email    => param('email'),
		name     => param('name'),
	);
	if ( $mymaven->{require_password} ) {
		$data{password} //= '';
		$data{password} =~ s/^\s+|\s+$//g;
		if ( not $data{password} ) {
			return _registration_form( %data, error => 'missing_password' );
		}
		if ( length $data{password} < $mymaven->{require_password} ) {
			return _registration_form(
				%data,
				error  => 'password_short',
				params => [ $mymaven->{require_password} ]
			);
		}
	}

	if ( not $data{email} ) {
		return _registration_form( %data, error => 'no_email_provided' );
	}
	$data{email} = lc $data{email};
	$data{email} =~ s/^\s+|\s+$//;
	if ( not Email::Valid->address( $data{email} ) ) {
		return _registration_form( %data, error => 'invalid_mail' );
	}

	my $db   = setting('db');
	my $user = $db->get_user_by_email( $data{email} );

	#debug Dumper $user;
	if ($user) {
		if ( $user->{verify_time} ) {
			return _registration_form( %data, error => 'already_registered_and_verified' );
		}
		else {
			return _registration_form( %data, error => 'already_registered_not_verified' );
		}

	}

	my $code = _generate_code();
	my $uid = $db->add_registration( { email => $data{email} } );
	$db->save_verification(
		code      => $code,
		action    => 'verify_email',
		timestamp => time,
		uid       => $uid,
		details   => to_json {
			new_email => $data{email},
		},
	);

	my $err = send_verification_mail(
		'email_first_verification_code',
		$data{email},
		"Please finish the $mymaven->{title} registration",
		{
			url  => uri_for('/verify2'),
			code => $code,
		},
	);
	if ($err) {
		return pm_error( 'could_not_send_email', params => [ $data{email} ], );
	}

	my $html_from = $mymaven->{from};
	$html_from =~ s/</&lt;/g;
	return pm_template 'response', { from => $html_from };
}

sub pw_form {
	my $id   = param('id');
	my $code = param('code');

	# if there is such userid with such code and it has not expired yet
	# then show a form
	return pm_error('missing_data')
		if not $id or not $code;

	my $db   = setting('db');
	my $user = $db->get_user_by_id($id);
	return pm_error('invalid_uid')
		if not $user;
	return pm_error('invalid_code')
		if not $user->{password_reset_code}
		or $user->{password_reset_code} ne $code
		or not $user->{password_reset_timeout};
	return pm_error('old_password_code')
		if $user->{password_reset_timeout} < time;

	return;
}

sub send_verification_mail {
	my ( $template, $email, $subject, $params ) = @_;

	my $html = template $template, $params, { layout => 'email', };
	my $mymaven = mymaven;
	return send_mail(
		{
			From    => $mymaven->{from},
			To      => $email,
			Subject => $subject,
		},
		{
			html => $html,
		}
	);
}

true;

