package Perl::Maven::Monitor::CPAN;
use 5.010;
use Moo::Role;
use boolean;
use Data::Dumper qw(Dumper);
use Cpanel::JSON::XS qw(decode_json);

use LWP::UserAgent;

our $VERSION = '0.11';

sub fetch_cpan {
	my ($self) = @_;

	$self->_log('Fetching from MetaCPAN');
	my $mcpan  = MetaCPAN::Client->new;
	my $recent = $mcpan->recent( $self->limit );
	$self->_log( 'recent downloaded from MetaCPAN limit: ' . $self->limit );

	my $cpan = $self->mongodb('cpan');

	my $count = 0;

	while ( my $r = $recent->next ) {    # https://metacpan.org/pod/MetaCPAN::Client::Release
		    #die Dumper $r;
		    #my ( $year, $month, $day, $hour, $min, $sec ) = split /\D/, $r->date;    #2015-04-05T12:10:00
		    #my $time = timegm( $sec, $min, $hour, $day, $month - 1, $year );
		    #last if $time < $now - 60 * 60 * $self->hours;
		my $rd = DateTime::Tiny->from_string( $r->date );    #2015-04-05T12:10:00

		my %data;
		$data{distribution} = $r->distribution;
		$data{name}         = $r->name;
		$data{author}       = $r->author;
		$data{abstract}     = ( $r->abstract // '' );
		$data{date}         = $rd;
		$data{first}        = $r->first ? boolean::true : boolean::false;
		$data{modules}      = $r->provides;
		$data{version}      = $r->version;
		$data{dependency}   = $r->dependency;
		$data{license}      = $r->license;
		$data{metadata}     = $r->metadata;

		my $res = $cpan->find_one( { name => $data{name} } );
		next if $res;    # TODO or shall we quit here?

		$self->travis_ci( \%data );

		$count++;
		$cpan->insert( \%data );

		#last if $count > 10;

		#die Dumper \%data;
	}
	$self->_log("CPAN inserted $count entries");
	$self->_log(
		'WARN - More than 90% of the CPAN modules were added. Either the limit or the frequencey should be increased!')
		if $count > 0.9 * $self->limit;
	$self->_log( 'Total number of entries in CPAN: ' . $cpan->count );
	return;
}

sub travis_ci {
	my ( $self, $data ) = @_;

	#print Dumper $data->{metadata}{resources}{repository};
	my $repo_url = $data->{metadata}{resources}{repository}{web} || $data->{metadata}{resources}{repository}{url};
	if ( not $repo_url ) {

		#$data->{error} = 'No repository url';
		return;
	}
	$repo_url =~ s{^git://github.com/(.*)\.git$}{https://github.com/$1};
	$repo_url =~ s{^https?://github.com/(.*?)/?}{https://github.com/$1};

	#say $repo_url;
	$data->{_cm_}{repository_url} = $repo_url;

	my ($repo) = $repo_url =~ m{^https://github.com/(.*)$};
	if ( not $repo ) {

		#$data->{error} = sprintf q{Repository is not on GitHub '%s'}, $data->{metadata}{resources}{repository}{url};
		return;
	}

	#$data->{_cm_}{github_repo} = "http://github.com/$repo";
	my $ua = LWP::UserAgent->new;

	# Try to fetch travis.yml from GitHub
	my $travis_yml_url = "https://raw.githubusercontent.com/$repo/master/.travis.yml";
	$self->_log("Fetching $travis_yml_url");
	my $response = $ua->get($travis_yml_url);
	if ( not $response->is_success ) {
		$data->{_cm_}{travis_yml} = boolean::false;

		#$data->{error} = 'travis.yml not found on GitHub';
		return;
	}
	$data->{_cm_}{travis_yml} = boolean::true;

	# If there is, fetch the status from Travis-CI
	#my $travis_url = "https://api.travis-ci.org/repos/$repo/builds";
	#$self->_log("Fetching $travis_url");
	#my $res = $ua->get( $travis_url, 'Accept' => 'application/vnd.travis-ci.2+json' );
	#if ( not $res->is_success ) {
	#	$data->{error} = 'Could not fetch the status from Travis-CI';
	#	return;
	#}
	#my @builds = eval { @{ decode_json( $res->content )->{builds} } };
	#if ($@) {
	#	$data->{error} = "Error fetching travis status: $@";
	#	return;
	#}
	#$data->{travis_status}         = __get_travis_status(@builds);
	#$data->{travis_status_checked} = DateTime::Tiny->now;
	return;
}

sub __get_travis_status {
	my @builds = @_;

	return 'unknown' unless @builds;
	my $state = $builds[0]->{state};

	return $state    if $state =~ /cancel|pend/;
	return 'error'   if $state =~ /error/;
	return 'failing' if $state =~ /fail/;
	return 'passing' if $state =~ /pass/;
	return 'unknown';
}

1;

