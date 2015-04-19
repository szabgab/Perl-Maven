package Perl::Maven::Monitor::Pypi;
use 5.010;
use Moo::Role;
use XML::Feed ();
use boolean;
use Data::Dumper qw(Dumper);
use LWP::Simple qw(get);
use JSON::MaybeXS qw(decode_json encode_json);

our $VERSION = '0.11';

sub fetch_pypi {
	my ($self) = @_;

	$self->_log('Fetching from pypi');

	my $latest_url = 'https://pypi.python.org/pypi?%3Aaction=rss';
	my $newest_url = 'https://pypi.python.org/pypi?%3Aaction=packages_rss';

	my $pypi = $self->mongodb('pypi');

	my $new_feed = XML::Feed->parse( URI->new($newest_url) );
	if ( not $new_feed ) {
		die "Could not fetch feed from '$newest_url' " . XML::Feed->errstr;
	}
	my %first;
	for my $entry ( $new_feed->entries ) {

		#say 'New: ' . $entry->link;
		$first{ $entry->link } = 1;
	}

	my $feed = XML::Feed->parse( URI->new($latest_url) );
	if ( not $feed ) {
		die "Could not fetch feed from '$latest_url' " . XML::Feed->errstr;
	}

	my $count_feed = 0;
	my $count_add  = 0;

	for my $entry ( $feed->entries ) {
		$count_feed++;
		my %data;

		# pyglut 1.0.0
		$data{title} = $entry->title;

		#http://pypi.python.org/pypi/pyglut/1.0.0
		$data{link} = $entry->link;
		( $data{distribution}, $data{version} ) = $data{link} =~ m{http://pypi.python.org/pypi/([^/]+)/([^/]+)$};
		$data{abstract} = $entry->content->body;
		$data{date}     = $entry->issued;          # DateTime
		if ( $first{"http://pypi.python.org/pypi/$data{distribution}"} ) {
			$data{first} = boolean::true;
		}

		my $res = $pypi->find_one(
			{
				'distribution' => $data{distribution},
				'version'      => $data{version}
			}
		);
		next if $res;

		my $json   = get "$data{link}/json";
		my $distro = decode_json $json;

		$data{author} = $distro->{info}{author};

		#die Dumper $distro;
		#next;

		#die Dumper \%data;
		$count_add++;
		$pypi->insert( \%data );

		#say '';
		#say $data{title};
		#say $data{link};
	}

	$self->_log("Added Pypi $count_add from a total of $count_feed in the feed.");
	$self->_log('All the entries in the feed were added. Increase frequency!') if $count_add >= $count_feed;
	$self->_log( 'Total number of entries in Pypi: ' . $pypi->count );

	return;
}

1;

