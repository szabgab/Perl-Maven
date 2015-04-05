package Perl::Maven::Monitor;
use Moo;
use 5.010;
use Data::Dumper qw(Dumper);
use JSON::MaybeXS qw(decode_json encode_json);
use Path::Tiny qw(path);
use MetaCPAN::Client;
use Email::Stuffer;
use Email::Sender::Transport::SMTP ();

=pod

Run bin/monitor.pl

Send details about the distributions released in the last ELAPSED_TIME (where ELAPSED_TIME can be 1 hour, 24 hours, 7 days)

1) All - unfiltered
2) Filter the distribution to include each one only once.

load config file
fetch N most recent uploads to CPAN

=cut

has root => ( is => 'ro', required => 1 );

sub run {
	my ($self) = @_;

	my $config_file = $self->root . '/cpan.json';

	if ( not -e $config_file ) {
		_log("No config file '$config_file'");
		return;
	}

	my $config = decode_json path($config_file)->slurp_utf8;

	#die Dumper $config;
	my %all;
	my %new;
	my %modules;
	foreach my $username ( keys %{ $config->{subscribers} } ) {
		$modules{$_} = 1 for keys %{ $config->{subscribers}{$username}{modules} };
		if ( $config->{subscribers}{$username}{all} ) {
			$all{$username}++;
		}
		if ( $config->{subscribers}{$username}{new} ) {
			$new{$username}++;
		}
	}

	#die Dumper \%all;
	#die Dumper \%modules;
	#foreach my $module (keys %modules) {
	#}
	# fetch recent module
	my $mcpan  = MetaCPAN::Client->new;
	my $recent = $mcpan->recent(10);
	my $html .= <<'HTML';
<html><head><title>All</title></head><body>
<h1>Recently uploaded CPAN distributions</h1>
HTML
	my $html_all = qq{<h2>All the recently uploaded distributions</h2>\n};
	$html_all .= qq{<table>\n};
	$html_all .= qq{<tr><th>Distribution</th><th>Author</th><th>Abstract</th><th>Date</th></tr>\n};
	while ( my $r = $recent->next ) {    # https://metacpan.org/pod/MetaCPAN::Client::Release
		    #my ($year, $month, $day, $hour, $min, $sec) = split /\D/, $r->date; #2015-04-05T12:10:00
		    #my $rd = DateTime::Tiny->from_string( $r->date ); #2015-04-05T12:10:00

		$html_all .= q{<tr>};
		$html_all .= sprintf qq{<td><a href="http://metacpan.org/release/%s">%s</a></td>}, $r->distribution, $r->name;
		$html_all .= sprintf qq{<td><a href="http://metacpan.org/author/%s">%s</a></td>}, $r->author, $r->author;
		$html_all .= sprintf qq{<td>%s</td>}, $r->abstract;
		$html_all .= sprintf qq{<td>%s<td>},  $r->date;
		$html_all .= q{</tr>};

		#say join ', ', @{$r->provides};
		#say $r->name; (distribution-version)
	}
	$html_all .= qq{</table>\n};

	$html .= $html_all;

	$html .= qq{</body></html>};
	my $msg_all = Email::Stuffer

		#->text_body($text)
		->html_body($html)->subject('Recently uploaded CPAN distributions')->from('Gabor Szabo <gabor@perlmaven.com>')
		->transport(
		Email::Sender::Transport::SMTP->new(
			{
				host => 'mail.perlmaven.com',
			}
		)
		);

	foreach my $username ( sort keys %all ) {
		my $to = $config->{subscribers}{$username}{email};
		_log("Sending to '$to'");
		$msg_all->to($to)->send;
	}
}

sub _log {
	my ($msg) = @_;
	print "LOG: $msg\n";
}

1;

