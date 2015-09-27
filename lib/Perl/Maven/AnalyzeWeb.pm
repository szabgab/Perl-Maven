package Perl::Maven::AnalyzeWeb;
use Dancer2 appname => 'Perl::Maven';
use MongoDB;
use Data::Dumper qw(Dumper);

our $VERSION = '0.11';

use Perl::Maven::WebTools qw(pm_show_page);

# from Perl::Maven::Monitor and changed to be a functiona and not a method
sub mongodb {
	my ($collection) = @_;
	my $client = MongoDB::MongoClient->new( host => 'localhost', port => 27017 );
	my $database = $client->get_database('PerlMaven');
	return $database->get_collection($collection);
}

get '/' => sub {
	my $db = mongodb('perl_projects');
	my @all = map { $_->{project} } $db->find->all;
	pm_show_page(
		{ article => 'modules', template => 'digger/modules' },
		{
			projects => \@all,
		}
	);
};

get '/:project' => sub {
	my $project = param('project');

	my $db = mongodb('perl');
	my @all = map { delete $_->{_id}; $_ } $db->find( { project => $project } )->all;
	pm_show_page(
		{ article => 'modules', template => 'digger/module' },
		{
			project => $project,
			files   => \@all,
		}
	);

};

1;

