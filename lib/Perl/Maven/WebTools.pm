package Perl::Maven::WebTools;
use Dancer2 appname => 'Perl::Maven';

my $TIMEOUT = 60 * 60 * 24 * 365;

our $VERSION = '0.11';

my %authors;

my %RESOURCES = (
	password_short =>
		'Password is too short. It needs to be at least %s characters long not including spaces at the ends.',
	missing_password                => 'Missing password',
	invalid_mail                    => 'Invalid e-mail.',
	already_registered_and_verified => 'This address is already registered. Please <a href="/pm/login">log in</a>.',
	already_registered_not_verified =>
		'This address is already registered, but the e-mail has not been verified yet. Please ask for a new verification code <a href="/pm/login">here</a>.',
	could_not_send_email        => 'Internal error. Could not send e-mail to <b>%s</b>.',
	internal_error              => 'Internal error',
	invalid_value_provided      => 'Invalid parameter',
	no_email_provided           => 'No e-mail was provided.',
	broken_email                => 'This does not look like a valid e-mail address.',
	email_exists                => 'This e-mail already exists in our database.',
	missing_verification_code   => 'Missing verification code.',
	invalid_verification_code   => 'Invalid or expired verification code.',
	internal_verification_error => 'Internal verification error',
	invalid_uid                 => 'User not found',
	missing_data                => 'Some data is missing.',
	invalid_pw                  => 'Invalid password.',
	invalid_unsubscribe_code    => 'Invalid code',
	could_not_find_registration => 'Could not find registration.',
	invalid_code                => 'Invalid or missing code.',
	no_password                 => 'No password was given.',
	passwords_dont_match        => q{Passwords don't match.},
	bad_password                => 'No or bad password was given.',
	old_password_code =>
		'The code you you have received to set your password has timed out. Please ask for a new code.',
	invalid_email   => 'Could not find this e-mail address in our database.',
	no_admin_rights => 'You dont have admin rights.',
	not_logged_in   => 'This area is only accessible to logged in users',
	invalid_ip      => 'You are trying to access a protected page from %s which is not in the white-list.
      We have sent an e-mail to your default e-mail address with a code that can be used to add this IP address to the white-list.',
	not_verified_yet => 'This e-mail address has not been verified yet.
    We have sent you a verification code.
    Please check your e-mail and follow the instructions there.',
	already_registered => 'Why would you want to register if you are already logged in',
	already_logged_in  => 'You are already logged in. Go to your <a href="/pm/account">account</a>',

	whitelist_enabled       => 'Whitelist enabled. See your <a href="/pm/account">account</a> and add IP addresses.',
	whitelist_disabled      => 'Whitelist disabled. See your <a href="/pm/account">account</a>.',
	whitelist_entry_deleted => 'Whitelist entry was deleted. See your <a href="/pm/account">account</a>.',
	whitelist_updated       => 'Whitelist entry for %s was added. See your <a href="/pm/account">account</a>.',
	reset_password_sent     => 'E-mail sent with code to reset password.',
	password_set            => 'The password was set successfully. <a href="/pm/account">account</a>',
	user_updated            => 'Updated. <a href="/pm/account">account</a>',
	unsubscribed            => 'Unsubscribed from the Perl Maven newsletter.',
	subscribed =>
		'Subscribed to the Perl Maven newsletter. You can manage your subscription at your <a href="/pm/account">account</a>.',
	verification_email_sent =>
		'We have sent you an e-mail with a verification code. Please check your e-mail account and click on the link inthe message to verify your new e-mail address.',
	email_updated_successfully => 'Email updated successfully.',

	# PayPal
	no_product_specified      => 'No product was specified.',
	invalid_product_specified => 'Invalid product was specified.',
	please_log_in =>
		'Before making a purchase, please <a href="/register">create an account</a> and  <a href="/pm/login">login</a>, so we can associate your purchase with your account.',
	canceled => 'We are sorry that you canceled your purchase.',

);

use Exporter qw(import);
our @EXPORT_OK
	= qw(logged_in is_admin get_ip mymaven valid_ip _generate_code _registration_form pm_template read_tt pm_show_abstract pm_show_page authors pm_error pm_message pm_user_info);

sub mymaven {
	my $mymaven = Perl::Maven::Config->new( path( config->{appdir}, config->{mymaven_yml} ) );
	return $mymaven->config( request->host );
}

sub _generate_code {
	my @chars = ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 );
	my $code = time;
	$code .= $chars[ rand( scalar @chars ) ] for 1 .. 20;
	return $code;
}

sub logged_in {

	#my $email = session('email');
	#if ($email) {
	#	my $db   = setting('db');
	#	my $user  = $db->get_user_by_email($email);
	#	session uid => $user->{id};
	#	session email => undef;
	#}

	if (    session('logged_in')
		and session('uid')
		and session('last_seen') > time - $TIMEOUT )
	{
		session last_seen => time;
		return 1;
	}
	return 0;

}

sub is_admin {
	return if not logged_in();

	my $db   = setting('db');
	my $user = $db->get_user_by_id( session('uid') );
	return if not $user or not $user->{admin};
	return 1;
}

sub get_ip {

	# direct access
	my $ip = request->remote_address;
	if ( $ip eq '::ffff:127.0.0.1' ) {

		# forwarded by Nginx
		my $forwarded = request->forwarded_for_address;
		if ($forwarded) {
			$ip = $forwarded;
		}
	}
	return $ip;
}

sub valid_ip {
	my $uid = session('uid') or die 'No uid found';
	my $user = setting('db')->get_user_by_id($uid);

	# if white-listing is not turned on, then every IP is valid
	return 1 if not $user->{login_whitelist};

	my $ip        = get_ip();
	my $whitelist = setting('db')->get_whitelist($uid);

	# TODO make use of the mask with Net::Subnet
	return scalar grep { $ip eq $_->{ip} } values %$whitelist;
}

sub pm_error {
	return _resources( 'error', 'error', @_ );
}

sub pm_message {
	return _resources( 'message', 'code', @_ );
}

sub _registration_form {
	return _resources( 'registration_form', @_ );
}

sub _resources {
	my ( $template, %args ) = @_;

	my $error = $args{error};
	if ( $error and $RESOURCES{$error} ) {
		if ( ref $args{params} ) {
			$error = sprintf $RESOURCES{$error}, @{ $args{params} };
		}
		else {
			$error = $RESOURCES{$error};
		}
		$args{error} = $error;
	}

	my $code = $args{code};
	if ( $code and $RESOURCES{$code} ) {
		if ( ref $args{params} ) {
			$code = sprintf $RESOURCES{code}, @{ $args{params} };
		}
		else {
			$code = $RESOURCES{$code};
		}
		$args{message} = $code;
	}

	$args{show_right} = 0;
	return pm_template( $template, \%args );
}

sub pm_template {
	my ( $template, $params ) = @_;
	delete $params->{password};
	if ( request->path =~ /\.json$/ ) {
		return to_json $params;
	}
	return template $template, $params;
}

sub read_tt {
	my $file = shift;
	my $tt   = eval {
		Perl::Maven::Page->new( file => $file, tools => setting('tools') )->read->merge_conf( mymaven->{conf} )->data;
	};
	if ($@) {

		# hmm, this should have been caught when the meta files were generated...
		error $@;
		return {};
	}
	else {
		return $tt;
	}
}

sub pm_show_abstract {
	my ($params) = @_;
	my $tt = read_tt( $params->{path} );

	return redirect $tt->{redirect} if $tt->{redirect};
	$tt->{promo} = $params->{promo} // 1;

	#		if not logged_in(), tell the user to subscribe or log in
	#
	#		if logged in but not subscribed, tell the user to subscribe
	delete $tt->{mycontent};
	return template 'propage', $tt;
}

sub pm_show_page {
	my ( $params, $data ) = @_;
	$data ||= {};

	my $path
		= ( delete $params->{path} || ( mymaven->{site} . '/pages' ) ) . "/$params->{article}.txt";
	if ( not -e $path ) {
		status 'not_found';
		return template 'error', { 'no_such_article' => 1 };
	}

	my $tt = read_tt($path);
	return redirect $tt->{redirect} if $tt->{redirect};
	if ( not $tt->{status}
		or ( $tt->{status} !~ /^(show|draft|done)$/ ) )
	{
		status 'not_found';
		return template 'error', { 'no_such_article' => 1 };
	}
	( $tt->{date} ) = split /T/, $tt->{timestamp};

	my $nick = $tt->{author};
	read_authors() if not %authors;
	if ( $nick and $authors{$nick} ) {
		$tt->{author_name} = $authors{$nick}{author_name};
		$tt->{author_img}  = $authors{$nick}{author_img};
		$tt->{author_google_plus_profile}
			= $authors{$nick}{author_google_plus_profile};
	}
	else {
		delete $tt->{author};
	}
	my $translator = $tt->{translator};
	if ( $translator and $authors{$translator} ) {
		$tt->{translator_name} = $authors{$translator}{author_name};
		$tt->{translator_img}  = $authors{$translator}{author_img};
		$tt->{translator_google_plus_profile}
			= $authors{$translator}{author_google_plus_profile};
	}
	else {
		if ($translator) {
			error("'$translator'");
		}
		delete $tt->{translator};
	}

	my $books = delete $tt->{books};
	if ($books) {
		$books =~ s/^\s+|\s+$//g;
		foreach my $name ( split /\s+/, $books ) {
			$tt->{$name} = 1;
		}
	}

	$tt->{$_} = $data->{$_} for keys %$data;

	return template $params->{template}, $tt;
}

sub authors {
	if ( not %authors ) {
		read_authors();
	}
	return \%authors;
}

sub read_authors {
	return if %authors;

	# Path::Tiny would throw an exception if it could not open the file
	# but we for Perl::Maven this file is optional
	eval {
		my $fh = Path::Tiny::path( mymaven->{root} . '/authors.txt' );

		# TODO add row iterator interface to Path::Tiny https://github.com/dagolden/Path-Tiny/issues/107
		foreach my $line ( $fh->lines_utf8 ) {
			chomp $line;
			my ( $nick, $name, $img, $google_plus_profile ) = split /;/, $line;
			$authors{$nick} = {
				author_name                => $name,
				author_img                 => ( $img || 'white_square.png' ),
				author_google_plus_profile => $google_plus_profile,
			};
		}
	};
	return;
}

sub pm_user_info {
	my %data = ( logged_in => logged_in(), );
	my $uid = session('uid');
	if ($uid) {
		my $db = setting('db');
		$data{perl_maven_pro} = $db->is_subscribed( $uid, 'perl_maven_pro' );
		my $user = $db->get_user_by_id($uid);
		$data{admin} = $user->{admin} ? 1 : 0;
	}

	# adding popups:

	#my @popups = (
	#	{
	#		logged_in => 1,
	#		what => 'popup_logged_in',
	#		when => 1000,
	#	 	frequency => 60*60*24,   # not more than
	# } );
	my $referrer = request->referer || '';
	my $url      = request->base    || '';
	my $path     = request->path    || '';

	$referrer =~ s{^(https?://[^/]*/).*}{$1};

	#debug("referrer = '$referrer'");
	#debug("url = '$url'");
	return \%data if $path =~ m{^/pm/};

	if ( $url ne $referrer ) {
		if ( logged_in() ) {

			# if not a pro subscriber yet
			if ( not $data{perl_maven_pro} ) {
				my $seen = session('popup_logged_in');

				if ( not $seen or $seen < time - 60 * 60 * 24 ) {

					#if ( not $seen or $seen < time - 10 ) {}
					session( 'popup_logged_in' => time );
					$data{delayed} = {
						what => 'popup_logged_in',
						when => 1000,
					};
				}
			}
		}
		else {
			my $seen = session('popup_logged_in');
			if ( not $seen or $seen < time - 60 * 60 * 24 ) {
				session( 'popup_logged_in' => time );
				$data{delayed} = {
					what => 'popup_visitor',
					when => 1000,
				};
			}
		}
	}

	return \%data;
}

true;

