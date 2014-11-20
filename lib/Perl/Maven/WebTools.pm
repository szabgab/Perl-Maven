package Perl::Maven::WebTools;
use Dancer ':syntax';

my $TIMEOUT = 60 * 60 * 24 * 365;

our $VERSION = '0.11';

use Exporter qw(import);
our @EXPORT_OK = qw(logged_in);

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

true;

