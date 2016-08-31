package Perl::Maven::Account;
use Dancer2 appname => 'Perl::Maven';

use Dancer2::Plugin::Passphrase;    #qw(passphrase);
use Email::Valid ();
use Digest::SHA  ();
use Data::Dumper qw(Dumper);

use Perl::Maven::WebTools
	qw(mymaven logged_in get_ip _generate_code pm_error pm_message _registration_form pm_template pm_user_info);
use Perl::Maven::Sendmail qw(send_mail);

our $VERSION = '0.11';

post '/pm/whitelist' => sub {
	if ( not logged_in() ) {

		#session url => request->path;
		return redirect '/pm/login';
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

	#if ( not $user->{verify_time} ) {
	# TODO: send e-mail with verification code
	#	return pm_error('not_verified_yet');
	#}

	my $code = _generate_code();
	$db->save_verification(
		code      => $code,
		action    => 'reset_password',
		timestamp => time,
		uid       => $user->{id},
		details   => to_json {},
	);

	my $html = template 'email_to_reset_password', { code => $code, }, { layout => 'email', };

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

post '/pm/change-password' => sub {
	if ( not logged_in() ) {
		session url => request->path;
		return redirect '/pm/login';
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

post '/pm/update-user' => sub {
	if ( not logged_in() ) {
		session url => request->path;
		return redirect '/pm/login';
	}

	my $name = param('name') || '';

	my $db  = setting('db');
	my $uid = session('uid');
	$db->update_user( $uid, name => $name );

	pm_message('user_updated');
};

get '/pm/subscribe' => sub {
	return redirect '/pm/login' if not logged_in();

	my $uid = session('uid');
	my $db  = setting('db');
	$db->subscribe_to( uid => $uid, code => mymaven->{free_product} );
	pm_message('subscribed');
};

get '/pm/un-subscribe' => sub {
	return redirect '/pm/login' if not logged_in();

	my $uid = session('uid');

	my $db = setting('db');
	$db->unsubscribe_from( uid => $uid, code => mymaven->{free_product} );
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
		$db->unsubscribe_from( uid => $user->{id}, code => mymaven->{free_product} );
		my $html    = template 'email_after_unsubscribe', {}, { layout => 'email' };
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

		return pm_message('unsubscribed');
	}

	return template 'confirm_unsubscribe',
		{
		code  => $code,
		email => $email,
		};
};

# TODO probably we would want to move the show_right control from here to a template file (if we really need it here)
get '/pm/register' => sub {
	return pm_error('already_registered') if logged_in();
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
		return redirect '/pm/login';
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
			code => $code,
		},
	);
	if ($err) {
		return pm_error( 'could_not_send_email', params => [$email], );
	}

	pm_message('verification_email_sent');
};

get '/pm/login' => sub {
	return pm_error('already_logged_in') if logged_in();
	template 'login';
};

post '/pm/login' => sub {
	my $email    = param('email');
	my $password = param('password');

	return pm_error('missing_data')
		if not $password or not $email;

	my $db   = setting('db');
	my $user = $db->get_user_by_email($email);
	if ( not $user->{password} ) {
		return pm_template 'login', { no_password => 1 };
	}

	return pm_error('invalid_pw')
		if not passphrase($password)->matches( $user->{password} );

	session uid       => $user->{id};
	session logged_in => 1;
	session last_seen => time;

	#my $url = session('referer') // '/account';
	#session referer => undef;
	my $url = session('url') // '/pm/account';
	session url => undef;

	redirect $url;
};

post '/pm/whitelist-delete' => sub {
	return redirect '/pm/login' if not logged_in();

	my $uid = session('uid');
	my $id  = param('id');
	my $db  = setting('db');
	$db->delete_from_whitelist( $uid, $id );
	pm_message('whitelist_entry_deleted');
};

get '/pm/user-info' => sub {
	to_json pm_user_info();
};

get '/pm/logout' => sub {
	session logged_in => 0;
	redirect '/';
};

get '/pm/account' => sub {
	return redirect '/pm/login' if not logged_in();

	my $db   = setting('db');
	my $uid  = session('uid');
	my $user = $db->get_user_by_id($uid);

	my @owned_products;
	foreach my $code ( @{ $user->{subscriptions} } ) {

		# TODO remove the hard-coded special case of the perl_maven_pro
		if ( $code eq 'perl_maven_pro' ) {
			push @owned_products,
				{
				name     => 'Perl Maven Pro',
				filename => '/archive?tag=pro',
				linkname => 'List of pro articles',
				};
		}
		else {
			my @files = get_download_files($code);
			foreach my $f (@files) {

				#debug "$code -  $f->{file}";
				push @owned_products,
					{
					name     => ( setting('products')->{$code}{name} . " $f->{title}" ),
					filename => "/download/$code/$f->{file}",
					linkname => $f->{file},
					};
			}
		}
	}

	my %params = (
		subscriptions   => \@owned_products,
		subscribed      => $db->is_subscribed( $uid, mymaven->{free_product} ),
		name            => $user->{name},
		email           => $user->{email},
		login_whitelist => ( $user->{login_whitelist} ? 1 : 0 ),
	);
	if ( $user->{login_whitelist} ) {
		$params{whitelist} = $db->get_whitelist($uid);
	}
	if ( $db->get_product_by_code('perl_maven_pro') and not $db->is_subscribed( $uid, 'perl_maven_pro' ) ) {
		$params{perl_maven_pro_buy_button}
			= Perl::Maven::PayPal::paypal_buy( 'perl_maven_pro', 'trial', 1, 'perl_maven_pro_1_9' );
	}
	template 'account', \%params;
};

get '/pm/verify2/:code' => \&verify2;
post '/pm/verify2'      => \&verify2;

sub verify2 {
	my $code = param('code');

	return pm_error('missing_verification_code') if not $code;

	# TODO Shall we expect here the same user to be logged in already? Can we expect that?

	my $db           = setting('db');
	my $verification = $db->get_verification($code);
	return pm_error('invalid_verification_code')
		if not $verification;

	# TODO check if verification code is expired!

	my $details = eval { from_json $verification->{details} };
	my $uid     = $verification->{uid};
	my $user    = $db->get_user_by_id($uid);

	if ( $verification->{action} eq 'reset_password' ) {
		my $set = param('set');
		if ($set) {
			my $password = param('password');

			# unite with the require_password configuration field
			if ( not $password or length($password) < 5 ) {
				return template 'set_password',
					{
					code        => param('code'),
					no_password => 1,
					};
			}
			$db->set_password( $uid, passphrase($password)->generate->rfc2307 );
			session uid       => $uid;
			session logged_in => 1;
			session last_seen => time;

			# TODO set e-mail to be verified (if it is not yet)
			$db->delete_verification_code($code);
			return pm_message('password_set');
		}
		else {
			return template 'set_password', { code => param('code'), };
		}
	}

	if ( $verification->{action} eq 'verify_email' ) {
		$db->delete_verification_code($code);
		return verify_registration( $uid, $user->{email} );
	}

	if ( $verification->{action} eq 'change_email' ) {
		$db->replace_email( $user->{email}, $details->{new_email} );

		$db->delete_verification_code($code);

		return pm_message('email_updated_successfully');
	}

	if ( $verification->{action} eq 'add_to_whitelist' ) {
		if ( not logged_in() ) {
			return 'You need to be logged in to validate the IP address';
		}
		my $ip        = $details->{ip};
		my $whitelist = $db->get_whitelist($uid);
		my $mask      = '255.255.255.255';
		my $found     = grep { $whitelist->{$_}{ip} eq $ip and $whitelist->{$_}{mask} eq $mask } keys %$whitelist;
		if ( not $found ) {
			$db->add_to_whitelist(
				{
					uid  => $uid,
					ip   => $ip,
					mask => $mask,
					note => 'Added at ' . gmtime(),
				}
			);
		}
		$db->delete_verification_code($code);
		return pm_message( 'whitelist_updated', ip => $ip );
	}

	return pm_error('internal_verification_error');
}

get '/pm/verify/:id/:code' => sub {
	my $uid  = param('id');
	my $code = param('code');

	my $db   = setting('db');
	my $user = $db->get_user_by_id($uid);

	if ( not $user ) {
		return pm_error('invalid_uid');
	}

	if (   not $user->{verify_code}
		or not $code
		or $user->{verify_code} ne $code )
	{
		return pm_error('invalid_code');
	}

	if ( $user->{verify_time} ) {
		return pm_template 'thank_you';
	}

	verify_registration( $uid, $user->{email} );
};

##########################################################################################

sub register {
	my $mymaven = mymaven;

	my %data = (
		password => param('password'),
		email    => param('email'),
		name     => param('name'),
	);

	$data{password} //= '';
	$data{password} =~ s/^\s+|\s+$//g;
	if ( $mymaven->{require_password} ) {
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

	# I've seen many registrations using these domains that bounced immediately
	# Let's not bother with them.
	# TODO move this to configuration file
	# Domains used to register on the PerlMaven/CodeMaven sites that bounced:
	my %BLACK_LIST = map { $_ => 1 } qw(
		asooemail.com
		asdfmail.net
		qwkcmail.net
		mailsdfsdf.net
		asdooeemail.com
		apoimail.com
		dfoofmail.com
		fghmail.net
		rtotlmail.com
		qwkcmail.com
		asdfasdfmail.com
		rtotlmail.net
		bestemail.bid
		besthostever.xyz
		free-4-everybody.bid
		free-mail.bid
		geekemailfreak.bid
		jaggernaut-email.bid
		mail4you.bid
		mail-4-you.bid
		netsolutions.top
		pigeon-mail.bid
		snailmail.bid
		yourfreemail.bid
		web2web.top
		vvajiz.com
		livemail.top
		freechatemails.bid
		snipe-mail.bid
		email4everybody.bid
	);
	my ( $username, $domain ) = split /@/, $data{email};

	if ( $BLACK_LIST{$domain} ) {
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

	if ( $data{password} ) {
		$db->set_password( $uid, passphrase( $data{password} )->generate->rfc2307 );
	}

	my $err = send_verification_mail(
		'email_first_verification_code',
		$data{email},
		"Please finish the $mymaven->{title} registration",
		{
			code => $code,
		},
	);
	if ($err) {
		return pm_error( 'could_not_send_email', params => [ $data{email} ], );
	}

	my $html_from = $mymaven->{from};
	$html_from =~ s/</&lt;/g;
	return pm_template 'response',
		{
		from           => $html_from,
		perl_maven_pro => $db->get_product_by_code('perl_maven_pro'),
		};
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

sub get_download_files {
	my ($subdir) = @_;

	my $manifest = path( mymaven->{dirs}{download}, $subdir, 'manifest.csv' );

	#debug $manifest;
	my @files;
	eval {
		foreach my $line ( Path::Tiny::path($manifest)->lines ) {
			chomp $line;
			my ( $file, $title ) = split /;/, $line;
			push @files,
				{
				file  => $file,
				title => $title,
				};
		}
		1;
	} or do {
		my $err = $@ // 'Unknown error';
		error "Could not open $manifest : $err";
	};
	return @files;
}

sub verify_registration {
	my ( $uid, $email ) = @_;
	my $db = setting('db');

	if ( not $db->verify_registration($uid) ) {
		return pm_template 'verify_form', { error => 1, };
	}
	my $mymaven = mymaven;

	# TODO handle if this is not successful!
	$db->subscribe_to( uid => $uid, code => mymaven->{free_product} );

	session uid       => $uid;
	session logged_in => 1;
	session last_seen => time;

	my $url = request->base;
	$url =~ s{/+$}{};

	my $err = send_mail(
		{
			From    => $mymaven->{from},
			To      => $email,
			Subject => 'Thank you for registering',
		},
		{
			html => template(
				'email_after_verification',
				{
					url => $url,
				},
				{ layout => 'email', }
			),
		}
	);

	send_mail(
		{
			From    => $mymaven->{from},
			To      => $mymaven->{admin}{email},
			Subject => "New $mymaven->{title} newsletter registration",
		},
		{
			html => "$email has registered",
		}
	);

	template 'thank_you';
}

true;

