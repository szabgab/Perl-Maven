package Perl::Maven::Monitor;
use Moo;
use 5.010;
use Data::Dumper qw(Dumper);
use JSON::MaybeXS qw(decode_json encode_json);
use Path::Tiny qw(path);
use MetaCPAN::Client;
use Email::Stuffer;
use Email::Sender::Transport::SMTP ();
use Time::Local qw(timegm);

our $VERSION = '0.11';

=pod

Run bin/monitor.pl

Send details about the distributions released in the last ELAPSED_TIME (where ELAPSED_TIME can be 1 hour, 24 hours, 7 days)

*) all    - unfiltered
*) unique - Filter the distribution to include each one only once.
*) modules - provides given module
*) author  - released by given author


*) partial_module - Any module in certain namespaces
*) immediate prerequisites of a given module
*) immediate prerequisites of any module of a given author
*) new    - This is the first time the distribution was released.
*) gap    - First release after a big gap (1 year)
*) diff   - Large change in number of lines of code since the most recent release.
*) Module the user has starred on MetaCPAN

Each subscription belongs to a user (and each user can have multiple subscriptions).

We collect all the data from MetaCPAN based on the recent feed.
Then for each subscription we build the e-mail and send it.

Load config file
Fetch N most recent uploads to CPAN

=cut

has root  => ( is => 'ro', required => 1 );
has limit => ( is => 'ro', default  => 1000 );
has hours => ( is => 'ro', default  => 24 );     # shall we restrict this to these numbers 1, 24, 168  ??

sub run {
	my ($self) = @_;

	my $config_file = $self->root . '/config/cpan.json';

	if ( not -e $config_file ) {
		_log("No config file '$config_file'");
		return;
	}

	my $config = decode_json path($config_file)->slurp_utf8;

	#die Dumper $config;
	#my %all;
	my %unique;

	#my %new;
	my %partial_modules;
	my %modules;
	my %authors;
	foreach my $sub ( @{ $config->{subscriptions} } ) {
		$partial_modules{$_} = {} for keys %{ $sub->{partial_modules} };
		$modules{$_}         = '' for keys %{ $sub->{modules} };
		$authors{$_}         = '' for keys %{ $sub->{authors} };
	}

	#die Dumper \%modules;
	#foreach my $module (keys %modules) {
	#}
	# fetch recent module

	my $now = time;
	my $count;

	my $mcpan  = MetaCPAN::Client->new;
	my $recent = $mcpan->recent( $self->limit );
	my %html;
	my $html_all    = '';
	my $html_unique = '';
	while ( my $r = $recent->next ) {    # https://metacpan.org/pod/MetaCPAN::Client::Release
		my ( $year, $month, $day, $hour, $min, $sec ) = split /\D/, $r->date;    #2015-04-05T12:10:00
		my $time = timegm( $sec, $min, $hour, $day, $month - 1, $year );
		last if $time < $now - 60 * 60 * $self->hours;

		#my $rd = DateTime::Tiny->from_string( $r->date ); #2015-04-05T12:10:00

		#die Dumper $r->metadata;
		#die $r->first;  # is this already in use?

		$count++;
		my $html = '';
		$html .= q{<tr>};
		$html .= sprintf q{<td><a href="http://metacpan.org/release/%s">%s</a></td>}, $r->distribution, $r->name;
		$html .= sprintf q{<td><a href="http://metacpan.org/author/%s">%s</a></td>}, $r->author, $r->author;
		$html .= sprintf q{<td>%s</td>},                    $r->abstract;
		$html .= sprintf q{<td style="width:130px">%s<td>}, $r->date;       # , ($now - $time);
		$html .= qq{</tr>\n};

		$html_all .= $html;

		if ( not $unique{ $r->distribution }++ ) {
			$html_unique .= $html;
		}

		if ( defined $authors{ $r->author } ) {
			$authors{ $r->author } .= $html;
		}

		foreach my $module ( @{ $r->provides } ) {

			#my @parts = split /::/, $module;
			#my ($part) = grep { $partial_modules{$_} } @parts;
			if ( defined $modules{$module} ) {
				$modules{$module} .= $html;
			}

			#	if ($part) {
			#		$partial_modules{$part}{$module} = 1;
			#	}
			#}
		}

		#say join ', ', @{$r->provides};
	}

	if ($html_all) {
		$html{all} = qq{<h2>All the recently uploaded distributions</h2>\n};
		$html{all} .= qq{<table>\n};
		$html{all} .= qq{<tr><th>Distribution</th><th>Author</th><th>Abstract</th><th>Date</th></tr>\n};
		$html{all} .= $html_all;
		$html{all} .= qq{</table>\n};
	}

	if ($html_unique) {
		$html{unique} = qq{<h2>Unique recently uploaded distributions</h2>\n};
		$html{unique} .= qq{<table>\n};
		$html{unique} .= qq{<tr><th>Distribution</th><th>Author</th><th>Abstract</th><th>Date</th></tr>\n};
		$html{unique} .= $html_unique;
		$html{unique} .= qq{</table>\n};
	}

	foreach my $sub ( @{ $config->{subscriptions} } ) {

		my $html_content = '';
		if ( $sub->{all} ) {
			$html_content .= $html{all};
		}

		if ( $sub->{unique} ) {
			$html_content .= $html{unique};
		}

		# modules
		my $html_modules = '';
		foreach my $module ( sort keys %{ $sub->{modules} } ) {
			if ( $modules{$module} ) {
				$html_modules .= $modules{$module};
			}
		}
		if ($html_modules) {
			$html_content .= qq{<h2>Changed Modules monitored by module name</h2>\n};
			$html_content .= qq{<table>\n};
			$html_content .= qq{<tr><th>Distribution</th><th>Author</th><th>Abstract</th><th>Date</th></tr>\n};
			$html_content .= $html_modules;
			$html_content .= qq{</table>\n};
		}

		# partial_modules
		#my $html_parts = '';
		#foreach my $part ( sort keys %{ $sub->{partial_modules} } ) {
		#	if ( $partial_modules{$part} ) {
		#		foreach my $module (keys %{ $partial_modules{$part} } ) {
		#			$html_parts .= $modules{$module};
		#		}
		#	}
		#}
		#if ($html_parts) {
		#	$html_content .= qq{<h2>Changed Modules monitored by partial module name</h2>\n};
		#	$html_content .= qq{<table>\n};
		#	$html_content .= qq{<tr><th>Distribution</th><th>Author</th><th>Abstract</th><th>Date</th></tr>\n};
		#	$html_content .= $html_parts;
		#	$html_content .= qq{</table>\n};
		#}

		# authors
		my $html_authors = '';
		foreach my $author ( sort keys %{ $sub->{authors} } ) {
			if ( $authors{$author} ) {
				$html_authors .= $authors{$author};
			}
		}
		if ($html_authors) {
			$html_content .= qq{<h2>Changed Modules by monitored authors</h2>\n};
			$html_content .= qq{<table>\n};
			$html_content .= qq{<tr><th>Distribution</th><th>Author</th><th>Abstract</th><th>Date</th></tr>\n};
			$html_content .= $html_authors;
			$html_content .= qq{</table>\n};
		}

		next if not $html_content;

		my $html_body = qq{<html><head><title>CPAN</title></head><body>\n};
		$html_body .= qq{<h1>Recently uploaded CPAN distributions</h1>\n};
		$html_body .= $html_content;

		if ( $count == $self->limit ) {

			# report that we should incease the limit
			$html_body
				.= sprintf
				q{We have reached the limit of CPAN distributions retreived that was set to %s. Some distributions might have been left out from this report.},
				$self->limit;
		}
		$html_body .= qq{</body></html>\n};

		my $to = $sub->{email};
		_log("Sending to '$to'");
		Email::Stuffer

			#->text_body($text)
			->html_body($html_body)->subject("Recently uploaded CPAN distributions - $sub->{title}")
			->from('Gabor Szabo <gabor@perlmaven.com>')
			->transport( Email::Sender::Transport::SMTP->new( { host => 'mail.perlmaven.com' } ) )->to($to)->send;
	}

}

sub _log {
	my ($msg) = @_;
	print "LOG: $msg\n";
}

1;

