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

with('Perl::Maven::Monitor::Pypi');

our $VERSION = '0.11';

=pod

Run bin/monitor.pl


  Send details about the distributions released in the last ELAPSED_TIME (where ELAPSED_TIME can be 1 hour, 1 day, or 1 week)
 <li>An "email" where we are going to send the messages.</li>
 <li>A "userid" that connects it to the PerlMaven user account which has the e-mail address in it.
 <li>An elapsed_time value which is 1, 24, or 168 (day and week in hours).

- One-click unsubscribe:
   In each e-mail include a link to unsubscribe (and another link to modify subscription)
   Both can lead to the same page where the user can
     1) delete this subscription
     2) disable this susbscriptin (this will keep the subscription in the database to make it easy to enable later)
     3) Change the subscription

- Include information about the run (hours, limit)
- Report the total elapsed time of the process
- Report the total memory used by the process


*) immediate prerequisites of a given module
*) immediate prerequisites of any module of a given author
*) gap    - First release after a big gap (1 year)
*) diff   - Large change in number of lines of code since the most recent release.
*) Module the user has starred on MetaCPAN

We collect all the data from MetaCPAN based on the recent feed.
Then for each subscription we build the e-mail and send it.

Load config file
Fetch N most recent uploads to CPAN



=head2 PyPi

Frequently fetch the RSS feed and update the locally cached information
use the locally stored data to fetch the "most recent" list


=cut

has root  => ( is => 'ro', required => 1 );
has limit => ( is => 'ro', default  => 1000 );
has hours => ( is => 'ro', default  => 24 );     # shall we restrict this to these numbers 1, 24, 168  ??
has conf  => ( is => 'ro' );

sub run {
	my ($self) = @_;

	my $config_file = $self->conf // $self->root . '/config/cpan.json';

	if ( not -e $config_file ) {
		$self->_log("No config file '$config_file'");
		return;
	}

	my $config = decode_json path($config_file)->slurp_utf8;

	#die Dumper $config;
	#my %all;

	#my %new;
	my %partials;
	my %modules;
	my %authors;
	foreach my $sub ( @{ $config->{subscriptions} } ) {
		next if not $sub->{enabled};

		# TODO apply the regex filter when the user enters the regex and reject the ones we don't want to handle.
		$partials{$_} = '' for grep {/^\^?[a-zA-Z0-9:-]+\$?$/} keys %{ $sub->{partials} };
		$modules{$_}  = '' for keys %{ $sub->{modules} };
		$authors{$_}  = '' for keys %{ $sub->{authors} };
	}

	my %html = $self->collect_cpan( \%authors, \%modules, \%partials );

	foreach my $sub ( @{ $config->{subscriptions} } ) {
		next if not $sub->{enabled};

		my $html_content = '';
		if ( $sub->{all} ) {
			$html_content .= $html{all};
		}

		if ( $sub->{unique} ) {
			$html_content .= $html{unique};
		}

		if ( $sub->{new} ) {
			$html_content .= $html{new};
		}

		# modules
		my $html_modules = '';
		foreach my $module ( sort keys %{ $sub->{modules} } ) {
			if ( $html{modules}{$module} ) {
				$html_modules .= $html{modules}{$module};
			}
		}
		if ($html_modules) {
			$html_content .= qq{<h2>Changed Modules monitored by module name</h2>\n};
			$html_content .= qq{<table>\n};
			$html_content .= qq{<tr><th>Distribution</th><th>Author</th><th>Abstract</th><th>Date</th></tr>\n};
			$html_content .= $html_modules;
			$html_content .= qq{</table>\n};
		}

		# partials
		my $html_parts = '';
		foreach my $part ( sort keys %{ $sub->{partials} } ) {
			if ( $html{partials}{$part} ) {
				$html_content .= qq{<h2>Changed Distributions monitored by partial module name - $part</h2>\n};
				$html_content .= qq{<table>\n};
				$html_content .= qq{<tr><th>Distribution</th><th>Author</th><th>Abstract</th><th>Date</th></tr>\n};
				$html_content .= $html{partials}{$part};
				$html_content .= qq{</table>\n};
			}
		}

		# authors
		my $html_authors = '';
		foreach my $author ( sort keys %{ $sub->{authors} } ) {
			if ( $html{authors}{$author} ) {
				$html_authors .= $html{authors}{$author};
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

		$html_body .= $html{footer} // '';

		$html_body .= qq{</body></html>\n};

		my $to = $sub->{email};
		$self->_log("Sending to '$to'");
		Email::Stuffer

			#->text_body($text)
			->html_body($html_body)->subject("Recently uploaded CPAN distributions - $sub->{title}")
			->from('Gabor Szabo <gabor@perlmaven.com>')
			->transport( Email::Sender::Transport::SMTP->new( { host => 'mail.perlmaven.com' } ) )->to($to)->send;
	}

}

sub collect_cpan {
	my ( $self, $monitored_authors, $monitored_modules, $monitored_partials ) = @_;
	my %html;
	$html{authors}  = {%$monitored_authors};
	$html{modules}  = {%$monitored_modules};
	$html{partials} = {%$monitored_partials};

	my $now = time;
	my $count;
	my %unique;

	my $mcpan       = MetaCPAN::Client->new;
	my $recent      = $mcpan->recent( $self->limit );
	my $html_new    = '';
	my $html_all    = '';
	my $html_unique = '';
	while ( my $r = $recent->next ) {    # https://metacpan.org/pod/MetaCPAN::Client::Release
		my ( $year, $month, $day, $hour, $min, $sec ) = split /\D/, $r->date;    #2015-04-05T12:10:00
		my $time = timegm( $sec, $min, $hour, $day, $month - 1, $year );
		last if $time < $now - 60 * 60 * $self->hours;

		#my $rd = DateTime::Tiny->from_string( $r->date ); #2015-04-05T12:10:00

		#die Dumper $r->metadata;

		$count++;
		my $html = '';
		$html .= q{<tr>};
		$html .= sprintf q{<td><a href="http://metacpan.org/release/%s">%s</a></td>}, $r->distribution, $r->name;
		$html .= sprintf q{<td><a href="http://metacpan.org/author/%s">%s</a></td>}, $r->author, $r->author;
		$html .= sprintf q{<td>%s</td>}, ( $r->abstract // '' );
		$html .= sprintf q{<td style="width:130px">%s<td>}, $r->date;    # , ($now - $time);
		$html .= qq{</tr>\n};

		$html_all .= $html;

		if ( $r->first ) {
			$html_new .= $html;
		}

		if ( not $unique{ $r->distribution }++ ) {
			$html_unique .= $html;
		}

		if ( defined $html{authors}{ $r->author } ) {
			$html{authors}{ $r->author } .= $html;
		}

		foreach my $module ( @{ $r->provides } ) {
			if ( defined $html{modules}{$module} ) {
				$html{modules}{$module} .= $html;
			}
		}

		foreach my $partial ( keys %{ $html{partials} } ) {

			#say "part $partial";
			if ( $r->name =~ /$partial/ or grep {/\Q$partial/} @{ $r->provides } ) {
				$html{partials}{$partial} .= $html;
			}
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

	if ($html_new) {
		$html{new} = qq{<h2>Recently uploaded new distributions</h2>\n};
		$html{new} .= qq{<table>\n};
		$html{new} .= qq{<tr><th>Distribution</th><th>Author</th><th>Abstract</th><th>Date</th></tr>\n};
		$html{new} .= $html_new;
		$html{new} .= qq{</table>\n};
	}

	if ( $count == $self->limit ) {

		# report that we should incease the limit
		$html{footer} = sprintf
			q{We have reached the limit of CPAN distributions retreived that was set to %s. Some distributions might have been left out from this report.},
			$self->limit;
	}

	return %html;
}

sub _log {
	my ( $self, $msg ) = @_;
	print "LOG: $msg\n";
}

1;

