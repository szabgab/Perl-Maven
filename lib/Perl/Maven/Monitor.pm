package Perl::Maven::Monitor;
use Moo;
use 5.010;
use Data::Dumper qw(Dumper);
use Cpanel::JSON::XS qw(decode_json encode_json);
use Path::Tiny qw(path);
use MetaCPAN::Client;
use Email::Stuffer;
use Email::Sender::Transport::SMTP ();
use Time::Local qw(timegm);
use MongoDB;
use DateTime::Tiny;

#with('Perl::Maven::Monitor::Pypi');
with('Perl::Maven::Monitor::CPAN');

our $VERSION = '0.11';

=pod

Run bin/monitor.pl

Separate fetching from feeds to local database.

1) all/unique/new
2) modules/authors/regex



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
has limit => ( is => 'ro', default  => 100 );
has hours => ( is => 'ro', default  => 24 );    # shall we restrict this to these numbers 1, 24, 168  ??
has conf  => ( is => 'ro' );
has verbose => ( is => 'ro' );
has config  => ( is => 'rw' );

# TODO apply the regex filter when the user enters the regex and reject the ones we don't want to handle.
#$partials{$_} = '' for grep {/^\^?[a-zA-Z0-9:-]+\$?$/} keys %{ $sub->{partials} };

# TOTO
#if ( $count == $self->limit ) {
#	# report that we should incease the limit
#	$html{footer} = sprintf
#		q{We have reached the limit of CPAN distributions retreived that was set to %s. Some distributions might have been left out from this report.},
#		$self->limit;
#}

my @services = qw(cpan);    # pypi

sub BUILD {
	my ($self) = @_;

	my $config_file = $self->conf // $self->root . '/config/cpan.json';

	if ( not -e $config_file ) {
		$self->_log("No config file '$config_file'");
		return;
	}

	my $config = decode_json path($config_file)->slurp_utf8;
	$self->config($config);
	$self->_log("Config file '$config_file' read");

	#die Dumper $config;
	return;
}

sub fetch {
	my ( $self, $what ) = @_;

	my @todo = $what ? ($what) : @services;
	foreach my $what (@todo) {
		my $method = "fetch_$what";
		$self->$method;
	}
	return;
}

sub prepare {
	my ( $self, $source ) = @_;
	$self->_log("Prepare $source reports");

	my $now   = time;
	my $start = $now - 60 * 60 * $self->hours;
	my ( $sec, $min, $hour, $day, $month, $year ) = gmtime $start;
	my $start_time = DateTime::Tiny->new(
		year   => 1900 + $year,
		month  => 1 + $month,
		day    => $day,
		hour   => $hour,
		minute => $min,
		second => $sec,
	);

	my %data;

	my $collection = $self->mongodb($source);
	my $recent     = $collection->find( { date => { '$gt', $start_time } } )->sort( { date => -1 } );
	my $count      = 0;
	my %unique;
	while ( my $r = $recent->next ) {
		$count++;

		#print Dumper $r;
		#<STDIN>;
		push @{ $data{all} },    $r;
		push @{ $data{unique} }, $r if not $unique{ $r->{distribution} }++;
		push @{ $data{new} },    $r if $r->{first};
		if ( $r->{author} ) {
			push @{ $data{authors}{ $r->{author} } }, $r;
		}
		else {
			#$self->_log('WARN: author is empty in ' . Dumper $r);
		}
		push @{ $data{distributions}{ $r->{distribution} } }, $r;
		push @{ $data{modules}{$_} }, $r for @{ $r->{modules} };
	}

	#say $count;

	return \%data;
}

sub generate_html_cpan {
	my ( $self, $data ) = @_;

	my $html = qq{<table>\n};
	$html .= qq{<tr><th>Distribution</th><th>Author</th><th>Abstract</th><th>Date</th></tr>\n};

	for my $r (@$data) {
		$html .= q{<tr>};
		$html .= sprintf q{<td><a href="http://metacpan.org/release/%s">%s</a></td>}, $r->{distribution}, $r->{name};
		$html .= sprintf q{<td><a href="http://metacpan.org/author/%s">%s</a></td>}, $r->{author}, $r->{author};
		$html .= sprintf q{<td>%s</td>}, ( $r->{abstract} // '' );
		$html .= sprintf q{<td style="width:130px">%s<td>}, $r->{date};
		$html .= qq{</tr>\n};
	}
	$html .= qq{</table>\n};

	return $html;
}

sub generate_html_pypi {
	my ( $self, $data ) = @_;

	#die Dumper $data;

	my $html = qq{<table>\n};
	$html .= qq{<tr><th>Distribution</th><th>Author</th><th>Abstract</th></tr>\n};

	for my $r (@$data) {
		$html .= q{<tr>};
		$html .= sprintf q{<td><a href="https://pypi.python.org/pypi/%s">%s</a></td>}, $r->{distribution},
			$r->{distribution};
		$html .= sprintf q{<td>%s</td>}, ( $r->{author}   // '' );
		$html .= sprintf q{<td>%s</td>}, ( $r->{abstract} // '' );
		$html .= qq{</tr>\n};
	}
	$html .= qq{</table>\n};

	return $html;

}

sub send {
	my ( $self, $source, $data ) = @_;
	$self->_log("Send $source reports");

	my $config = $self->config;
	foreach my $sub ( @{ $config->{subscriptions} } ) {

		#print Dumper $sub;
		next if not $sub->{enabled};
		next if $sub->{source} ne $source;

		my $generate_html = "generate_html_$source";

		my $html_content = '';
		if ( $sub->{all} ) {
			$html_content .= qq{<h2>All the recently uploaded distributions</h2>\n};
			$html_content .= $self->$generate_html( $data->{all} );
		}

		if ( $sub->{unique} ) {
			$html_content .= qq{<h2>Unique recently uploaded distributions</h2>\n};
			$html_content .= $self->$generate_html( $data->{unique} );
		}
		if ( $sub->{new} ) {
			$html_content .= qq{<h2>Recently uploaded new distributions</h2>\n};
			$html_content .= $self->$generate_html( $data->{new} );
		}

		# modules
		if ( $sub->{modules} ) {
			my @dists;
			foreach my $module ( sort @{ $sub->{modules} } ) {
				if ( $data->{modules}{$module} ) {
					push @dists, @{ $data->{modules}{$module} };
				}
			}
			if (@dists) {
				$html_content .= qq{<h2>Changed Modules monitored by module name</h2>\n};
				$html_content .= $self->$generate_html( \@dists );
			}
		}

		# distribution-regex
		if ( $sub->{'distribution-regex'} ) {
			foreach my $regex ( sort @{ $sub->{'distribution-regex'} } ) {
				my @dists;

				my $reg = qr/$regex/;
				foreach my $r ( @{ $data->{all} } ) {
					if ( $r->{name} =~ /$reg/ ) {
						push @dists, $r;
					}
				}
				if (@dists) {
					$html_content
						.= qq{<h2>Changed Distributions monitored by regex for distribution name - $regex</h2>\n};
					$html_content .= $self->$generate_html( \@dists );
				}
			}

			#$html_content .= qq{<h2>Changed Distributions monitored by partial module name</h2>\n};
			#$html_content .= $self->$generate_html( \@dists );
		}

		# module-regex
		if ( $sub->{'module-regex'} ) {
			foreach my $regex ( sort @{ $sub->{'module-regex'} } ) {
				my @dists;

				my $reg = qr/$regex/;
				foreach my $r ( @{ $data->{all} } ) {
					if ( grep {/$reg/} @{ $r->{modules} } ) {
						push @dists, $r;
					}
				}
				if (@dists) {
					$html_content .= qq{<h2>Changed Distributions monitored by regex for module name - $regex</h2>\n};
					$html_content .= $self->$generate_html( \@dists );
				}
			}

			#$html_content .= qq{<h2>Changed Distributions monitored by partial module name</h2>\n};
			#$html_content .= $self->$generate_html( \@dists );
		}

		# authors
		if ( $sub->{authors} ) {
			foreach my $author ( sort @{ $sub->{authors} } ) {
				if ( $data->{authors}{$author} ) {
					$html_content .= qq{<h2>Changed Modules by monitored authors - $author</h2>\n};
					$html_content .= $self->$generate_html( $data->{authors}{$author} );
				}
			}
		}

		next if not $html_content;

		my $html_body = qq{<html><head><title>$source</title></head><body>\n};
		$html_body .= qq{<h1>Recently uploaded $source distributions</h1>\n};
		$html_body .= $html_content;

		#		$html_body .= $html{footer} // '';

		$html_body .= qq{</body></html>\n};

		my $to = $sub->{email};
		if ( $ENV{EMAIL} ) {
			$to = $ENV{EMAIL};
		}
		my $subject = "Recently uploaded $source distributions - $sub->{title}";
		$self->_log( sprintf( q{Sending '%-40s' to '%s'}, $subject, $to ) );

		Email::Stuffer

			#->text_body($text)
			->html_body($html_body)->subject($subject)->from('Gabor Szabo <gabor@perlmaven.com>')->to($to)->send;
	}
	return;
}

sub report {
	my ( $self, $what ) = @_;

	my @todo = $what ? ($what) : @services;
	foreach my $what (@todo) {

		#my $prepare = "prepare_$what";
		my $data = $self->prepare($what);

		#warn Dumper $data;
		$self->send( $what, $data );
	}

	return;
}

sub mongodb {
	my ( $self, $collection ) = @_;
	my $client = MongoDB::MongoClient->new( host => 'localhost', port => 27017 );
	my $database = $client->get_database('PerlMaven');
	return $database->get_collection($collection);
}

sub _log {
	my ( $self, $msg ) = @_;
	print "LOG: $msg\n" if $self->verbose;
}

1;

