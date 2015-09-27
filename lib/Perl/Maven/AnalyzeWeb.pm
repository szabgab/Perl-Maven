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

my $URL = '/digger/';

hook before_template => sub {
	my $t = shift;
	$t->{digger} = $URL;
};

get '/' => sub {
	pm_show_page( { article => 'modules', template => 'digger/main' }, {} );
};

get '/projects' => sub {
	my $db = mongodb('perl_projects');
	my @all = map { $_->{project} } $db->find->all;
	pm_show_page(
		{ article => 'modules', template => 'digger/projects' },
		{
			projects => \@all,
		}
	);
};

get '/modules' => sub {
	return 'list of all the modules...';
};

get '/p/:project' => sub {
	my $project = param('project');

	my $db = mongodb('perl');
	my @all = map { delete $_->{_id}; $_ } $db->find( { project => $project } )->all;
	pm_show_page(
		{ article => 'modules', template => 'digger/project' },
		{
			project => $project,
			files   => \@all,
		}
	);

};

get '/m/:module' => sub {
	my $module = param('module');

	my $db = mongodb('perl');

	#my @all = map { delete $_->{_id}; $_ } $db->find({ "depends.$module" => { '$exists' => boolean::true } })->all;
	#return Dumper \@all;
	my @all = map {
		{
			author  => $_->{author},
			project => $_->{project},
			version => $_->{version},
			depends => $_->{depends}{$module},
			file    => $_->{file},
		}
	} $db->find( { "depends.$module" => { '$exists' => boolean::true } } )->all;

	#return Dumper \@all;
	pm_show_page(
		{ article => 'modules', template => 'digger/module' },
		{
			projects => \@all,
			module   => $module,
		}
	);
};

1;

