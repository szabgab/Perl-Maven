package Perl::Maven::WebTools;
use Dancer2 appname => 'Perl::Maven';

my $TIMEOUT = 60 * 60 * 24 * 365;

our $VERSION = '0.11';

my %authors;

my %RESOURCES = (
	password_short =>
		'Password is too short. It needs to be at least %s characters long not including spaces at the ends.',
	missing_password     => 'Missing password',
	no_mail              => 'Missing e-mail.',
	invalid_mail         => 'Invalid e-mail.',
	duplicate_mail       => 'This address is already registered.',
	could_not_send_email => 'Internal error. Could not send e-mail to <b>%s</b>.',
);

use Exporter qw(import);
our @EXPORT_OK
	= qw(logged_in is_admin get_ip mymaven valid_ip _generate_code _error _registration_form _template read_tt _show_abstract _show authors);

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

sub _error {
	return _resources( 'error', @_ );
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

	$args{show_right} = 0;
	return _template( $template, \%args );
}

sub _template {
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

sub _show_abstract {
	my ($params) = @_;
	my $tt = read_tt( $params->{path} );
	$tt->{promo} = $params->{promo} // 1;

	#		if not logged_in(), tell the user to subscribe or log in
	#
	#		if logged in but not subscribed, tell the user to subscribe
	delete $tt->{mycontent};
	return template 'propage', $tt, { layout => 'system' };
}

sub _show {
	my ( $params, $data ) = @_;
	$data ||= {};

	my $path
		= ( delete $params->{path} || ( mymaven->{site} . '/pages' ) ) . "/$params->{article}.tt";
	if ( not -e $path ) {
		status 'not_found';
		return template 'error', { 'no_such_article' => 1 };
	}

	my $tt = read_tt($path);
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

true;

