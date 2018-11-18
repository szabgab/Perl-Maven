package Perl::Maven::CodeExplain;
use 5.010;
use strict;
use warnings;
use Dancer2 appname => 'Perl::Maven';

our $VERSION = '0.11';
my $CODE_EXPLAIN_LIMIT = 20;

use POSIX ();

get '/explain' => sub {
	require Code::Explain;
	my %data = (
		code_explain_version => $Code::Explain::VERSION,
		limit                => $CODE_EXPLAIN_LIMIT,
	);
	return template 'explain', \%data;
};

post '/explain' => sub {
	my $code = params->{'code'};
	$code = '' if not defined $code;
	$code =~ s/^\s+|\s+$//g;

	my %data = (
		code_explain_version => $Code::Explain::VERSION,
		limit                => $CODE_EXPLAIN_LIMIT,
		code                 => $code,
	);
	if ($code) {
		$data{html_code} = _escape($code);
		if ( length $code > $CODE_EXPLAIN_LIMIT ) {
			$data{too_long} = length $code;
		}
		else {
			require Code::Explain;
			my $ce = Code::Explain->new( code => $code );
			$data{explanation} = $ce->explain();
			$data{ppi_dump}    = [ map { _escape($_) } $ce->ppi_dump ];
			$data{ppi_explain}
				= [ map { $_->{code} = _escape( $_->{code} ); $_ } $ce->ppi_explain ];
		}

		my $time = time;
		my $log_file
			= path( config->{appdir}, 'logs', 'code_' . POSIX::strftime( '%Y%m', gmtime($time) ) );
		if ( open my $fh, '>>', $log_file ) {
			print $fh '-' x 20, "\n";
			print $fh scalar( gmtime $time ) . "\n";
			print $fh "$code\n\n";
			close $fh;
		}
	}
	return to_json \%data;
};

##########################################################################################
sub _escape {
	my $txt = shift;
	$txt =~ s/</&lt;/g;
	$txt =~ s/>/&gt;/g;
	return $txt;
}

true;

