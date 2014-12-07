package Perl::Maven::Sendmail;
use strict;
use warnings;

our $VERSION = '0.11';

use Email::Stuffer;
use Email::Sender::Transport::SMTP qw();

use Exporter qw(import);
our @EXPORT_OK = qw(send_mail html2text);

sub send_mail {
	my ( $header, $raw_content ) = @_;

	my $html    = $raw_content->{html};
	my $text    = $raw_content->{text} || html2text($html);
	my $subject = delete $header->{Subject};
	my $from    = delete $header->{From};
	my $to      = delete $header->{To};

	my $email = Email::Stuffer->text_body($text)->html_body($html)->subject($subject)->from($from)->transport(
		Email::Sender::Transport::SMTP->new(
			{
				host => 'localhost',
			}
		)
	);
	foreach my $key ( keys %$header ) {
		$email->header( $key, $header->{$key} );
	}
	$email->to($to)->send_or_die;
}

sub html2text {
	my $html = shift;

	$html =~ s{</?p>}{\n}gi;
	$html =~ s{<a href="([^"]+)">([^<]+)</a>}{$2 [ $1 ]}gi;

	$html =~ s{<[^>]+>}{}g;

	return $html;
}

1;

