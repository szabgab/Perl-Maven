package Perl::Maven::MetaSyntactic;
use Dancer2 appname => 'Perl::Maven';

our $VERSION = '0.11';

use Perl::Maven::WebTools qw(pm_show_page);

get '/' => sub {
	require Acme::MetaSyntactic;
	my $ams = Acme::MetaSyntactic->new;

	my $theme = param('theme');
	my @names;
	if ( $theme and $ams->has_theme($theme) ) {
		@names = sort $ams->name( $theme, 0 );
	}

	pm_show_page(
		{ article => 'foobar', template => 'foobar' },
		{
			themes     => [ $ams->themes ],
			name_count => scalar @names,
			names      => \@names,
		}
	);
};

true;

