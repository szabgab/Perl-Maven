package Perl::Maven::WebTools;
use Dancer ':syntax';

my $TIMEOUT = 60 * 60 * 24 * 365;

our $VERSION = '0.11';

use Exporter qw(import);
our @EXPORT_OK = qw(logged_in is_admin);

sub logged_in {

	# converting old sessions with e-mail addresses to new sessions with uid
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
	return;

}

sub is_admin {
	return if not logged_in();

	my $db   = setting('db');
	my $user = $db->get_user_by_id( session('uid') );
	return if not $user or not $user->{admin};
	return 1;
}

true;

