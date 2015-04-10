package Perl::Maven::Monitor::CPAN;
use 5.010;
use Moo::Role;
use boolean;

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

		my $res = $cpan->find_one( { name => $data{name} } );
		next if $res;                                        # TODO or shall we quit here?

		$count++;
		$cpan->insert( \%data );

		#warn Dumper \%data;
	}
	$self->_log("CPAN inserted $count entries");
	if ( not $count ) {
		$self->_log('WARN - No new CPAN modules were added. Either limit or frequencey should be increased!');
	}
	return;
}

1;

