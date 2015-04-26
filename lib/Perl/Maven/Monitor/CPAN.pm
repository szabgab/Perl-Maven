package Perl::Maven::Monitor::CPAN;
use 5.010;
use Moo::Role;
use boolean;
use Data::Dumper qw(Dumper);

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

		my $res = $cpan->find_one( { name => $data{name} } );
		next if $res;    # TODO or shall we quit here?

		$count++;
		$cpan->insert( \%data );

		#die Dumper \%data;
	}
	$self->_log("CPAN inserted $count entries");
	$self->_log(
		'WARN - More than 90% of the CPAN modules were added. Either the limit or the frequencey should be increased!')
		if $count > 0.9 * $self->limit;
	$self->_log( 'Total number of entries in CPAN: ' . $cpan->count );
	return;
}

1;

