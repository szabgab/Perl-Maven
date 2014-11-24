package Perl::Maven::Sendmail;
use strict;
use warnings;

use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP qw();
use Email::MIME::Creator;

use Try::Tiny;

use Exporter qw(import);
our @EXPORT_OK = qw(send_mail html2text);

sub send_mail {
	my ( $header, $raw_content ) = @_;

	my %content = %$raw_content;

	$content{text} ||= html2text( $content{html} );

	my %type = (
		text => 'text/plain',
		html => 'text/html',
	);

	my @parts;
	foreach my $t (qw(html text)) {
		push @parts,
			Email::MIME->create(
			attributes => {
				content_type => $type{$t},
				( $t eq 'text' ? ( disposition => 'attachment' ) : () ),
				encoding => 'quoted-printable',
				charset  => 'UTF-8',
			},
			body_str => $content{$t},
			);
		$parts[-1]->charset_set('UTF-8');
	}

	my $msg = Email::MIME->create(
		header_str => [
			%$header,
			'Type'    => 'multipart/alternative',
			'Charset' => 'UTF-8',
		],
		parts => \@parts,
	);
	$msg->charset_set('UTF-8');

	try {
		sendmail(
			$msg,
			{
				transport => Email::Sender::Transport::SMTP->new(
					{
						host => 'localhost',
					}
				)
			}
		);
	}
	catch {
		warn "sending failed: $_";
	};

	return;
}

sub html2text {
	my $html = shift;

	$html =~ s{</?p>}{\n}gi;
	$html =~ s{<a href="([^"]+)">([^<]+)</a>}{$2 [ $1 ]}gi;

	$html =~ s{<[^>]+>}{}g;

	return $html;
}

1;

