package Perl::Maven::WebTools;
use Dancer ':syntax';

my $TIMEOUT = 60 * 60 * 24 * 365;

our $VERSION = '0.11';

use Exporter qw(import);
our @EXPORT_OK = qw(logged_in is_admin);

sub logged_in {
	if (    session('logged_in')
		and session('email')
		and session('last_seen') > time - $TIMEOUT )
	{
		session last_seen => time;
		return 1;
	}
	return;
}

sub is_admin {
	return if not logged_in();

	#die session('email');
	my $db   = setting('db');
	my $user = $db->get_user_by_email( session('email') );
	return if not $user or not $user->{admin};
	return 1;
}

true;

