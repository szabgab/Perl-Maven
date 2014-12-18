package Perl::Maven::Consultants;
use Dancer2 appname => 'Perl::Maven';

our $VERSION = '0.11';

use Perl::Maven::WebTools qw(pm_show_page);

get '/perl-training-consulting' => sub {
	pm_show_page(
		{
			article  => 'perl-training-consulting',
			template => 'consultants',
		},
		{
			people => setting('tools')->read_meta_meta('consultants'),
		}
	);
};

true;

