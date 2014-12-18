package Perl::Maven::Jobs;
use Dancer2 appname => 'Perl::Maven';

get '/jobs-employer' => sub {
	template 'jobs_employer', { a => 1, };
};

true;

