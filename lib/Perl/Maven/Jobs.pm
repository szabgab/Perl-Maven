package Perl::Maven::Jobs;
use Dancer2 appname => 'Perl::Maven';

our $VERSION = '0.11';

use Perl::Maven::WebTools
	qw(logged_in get_ip mymaven pm_error pm_template read_tt pm_show_abstract pm_show_page authors pm_message pm_user_info);

get '/pm/jobs' => sub {
	if ( not logged_in() ) {
		return pm_error('not_logged_in');
	}

	my $uid  = session('uid');
	my $db   = setting('db');
	my $jobs = $db->get_jobs($uid);

	#debug($jobs);
	template 'jobs', { jobs => $jobs };
};

get '/pm/jobs/new' => sub {
	if ( not logged_in() ) {
		return pm_error('not_logged_in');
	}
	template 'jobs_employer';
};

get '/pm/jobs/save.json' => sub {
	if ( not logged_in() ) {
		return pm_error('not_logged_in');
	}
	my $job_id = param('job-id');
	if ($job_id) {
		return to_json { error => 'Editing not supported' };
	}

	my %data;
	$data{title} = param('title');
	$data{title} =~ s/^\s+|\s+$//g;
	if ( not $data{title} ) {
		return to_json { error => 'Missing title' };
	}

	my $db   = setting('db');
	my $uid  = session('uid');
	my $user = $db->get_user_by_id($uid);
	if ( not $user ) {
		return to_json { error => 'User not found' };
	}
	$data{uid} = $uid;
	$db->save_job_post( \%data );

	#return to_json { error => 'Some error' };
	return to_json { ok => 1 };
};

true;

