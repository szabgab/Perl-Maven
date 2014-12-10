package Perl::Maven::WebTools;
use Dancer ':syntax';

my $TIMEOUT = 60 * 60 * 24 * 365;

our $VERSION = '0.11';

use Exporter qw(import);
our @EXPORT_OK = qw(logged_in is_admin get_ip mymaven);

sub mymaven {
	my $mymaven = Perl::Maven::Config->new( path( config->{appdir}, config->{mymaven_yml} ) );
	return $mymaven->config( request->host );
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

true;

