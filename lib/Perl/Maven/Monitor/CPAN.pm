package Perl::Maven::Monitor::CPAN;
use 5.010;
use Moo::Role;
use boolean;
use Data::Dumper     qw(Dumper);
use Cpanel::JSON::XS qw(decode_json);
use Path::Tiny       qw(path);

#use Storable qw(dclone);
use Data::Structure::Util qw(unbless);
use version;

use LWP::UserAgent;

has distribution => ( is => 'rw' );

sub ua {
	my ($self)         = @_;
	my ($github_token) = path('config/github-token')->lines( { chomp => 1 } );
	$self->_log("token '$github_token'");
	return LWP::UserAgent->new(
		agent         => 'https://perlmaven.com/',
		Authorization => "token $github_token",
	);
}

our $VERSION = '0.11';

sub get_api {
	my ( $self, $repo, $call ) = @_;
	my $url = "https://api.github.com/repos/$repo";
	if ($call) {
		$url .= $call;
	}
	my $ua = $self->ua;
	$self->_log("get $url");
	my $res = $ua->get($url);
	if ( !$res->is_success ) {
		warn 'Warning for module https://metacpan.org/release/'
			. $self->distribution
			. " GitHub repo: https://github.com/$repo : could not get $url: "
			. $res->status_line;
		warn $res->content;
		return;
	}
	my $data = eval { decode_json( $res->content ) };
	if ($@) {
		warn $@;
		return {};
	}
	return $data;
}

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
			#my $rd = DateTime::Tiny->from_string( $r->date );    #2015-04-05T12:10:00
			#die Dumper $r;

		#my $raw = unbless $r->{data};
		#say Dumper $raw->{metadata};
		#say $raw->{metadata}{authorized};
		#next;

		my %data = ( cpan => $r->{data} );

		#$data{distribution} = $r->distribution;
		#$data{name}         = $r->name;
		#$data{author}       = $r->author;
		#$data{abstract}     = ( $r->abstract // '' );
		#$data{date}         = $rd;
		#$data{first}        = $r->first ? boolean::true : boolean::false;
		#$data{modules}      = $r->provides;
		#$data{version}      = $r->version;
		#$data{dependency}   = $r->dependency;
		#$data{license}      = $r->license;
		#$data{metadata}     = $r->metadata;

		$self->distribution( $r->distribution );
		$self->_log( 'Distribution: ' . $r->distribution );
		$self->_log("Current version: $data{cpan}{version}");
		my $res = $cpan->find_one( { 'cpan.distribution' => $data{cpan}{distribution} } );
		if ($res) {
			$self->_log("Previous version: $res->{cpan}{version}");

			my ( $old, $new );
			eval {
				$old = version->parse( $res->{cpan}{version} );
				$new = version->parse( $data{cpan}{version} );
			};
			if ($@) {
				$self->_log("ERROR parsing version number: $@");
				next;
			}

			if ( $old >= $new ) {
				next;
			}
			$self->_log('Delete previous versions');
			$cpan->delete_many( { 'cpan.distribution' => $data{cpan}{distribution} } );
		}

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
#$self->_log("web: $data->{cpan}{metadata}{resources}{repository}{web}") if $data->{cpan}{metadata}{resources}{repository}{web};
#$self->_log("url: $data->{cpan}{metadata}{resources}{repository}{url}") if $data->{cpan}{metadata}{resources}{repository}{url};
	my $repo_url
		= $data->{cpan}{metadata}{resources}{repository}{web} || $data->{cpan}{metadata}{resources}{repository}{url};
	if ( not $repo_url ) {

		#$data->{error} = 'No repository url';
		return;
	}
	$repo_url =~ s/\.git$//;
	$repo_url =~ s{^git://github.com/(.*)$}{https://github.com/$1};
	$repo_url =~ s{^https?://github.com/(.*?)/?}{https://github.com/$1};

	#$self->_log("repo_url: $repo_url") if $repo_url;

	#say $repo_url;
	$data->{_cm_}{repository_url} = $repo_url;

	my ($repo) = $repo_url =~ m{^https://github.com/(.*)$};
	if ( not $repo ) {

		#$data->{error} = sprintf q{Repository is not on GitHub '%s'}, $data->{metadata}{resources}{repository}{url};
		return;
	}

	my $commits = $self->get_api( $repo, '/commits' );

	#die Dumper $commits;
	my $latest
		= ref $commits eq 'ARRAY' ? $commits->[0] : $commits;    # if it's a single commit, we get the hashref directly
	my $updated = $latest->{commit}->{committer}->{date};

	#$project->{last_updated} = $updated;

	my $tree = $self->get_api( $repo, "/git/trees/$latest->{sha}?recursive=1" );

	#die Dumper $tree;
	my %files = map { $_->{path} => 1 } @{ $tree->{tree} };

	# TODO: we probably don't need the whole structure, and probably not all the files.

#die Dumper \%files;
# sample tree structure:
#                  {
#                    'sha' => 'da35a7638f9b2d3174dc3f131d295bbcb0768c96',
#                    'path' => '.gitignore',
#                    'type' => 'blob',
#                    'size' => 35,
#                    'url' => 'https://api.github.com/repos/perlancar/perl-Config-Apachish-Reader/git/blobs/da35a7638f9b2d3174dc3f131d295bbcb0768c96',
#                    'mode' => '100644'
#                  },

	# Interesting files:
	# .gitignore
	# .notyet      type=tree (directory)
	# dist.ini
	# weaver.ini
	# .travis.yml
	# .perlcriticrc
	# .perltidyrc
	# .tidyallrc
	$data->{github} = $tree->{tree};

	my $ua = $self->ua;

	# Try to fetch travis.yml from GitHub
	#my $travis_yml_url = "https://raw.githubusercontent.com/$repo/master/.travis.yml";
	#$self->_log("Fetching $travis_yml_url");
	#my $response = $ua->get($travis_yml_url);
	#if ( not $response->is_success ) {
	$data->{_cm_}{travis_yml} = $files{'.travis.yml'} ? boolean::true : boolean::false;

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

