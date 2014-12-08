package Perl::Maven::Sendmail;
use strict;
use warnings;

our $VERSION = '0.11';

use Email::Stuffer;
use Email::Sender::Transport::SMTP qw();

use Exporter qw(import);
our @EXPORT_OK = qw(send_mail html2text);

sub send_mail {
	my ( $raw_header, $raw_content ) = @_;

	my %header = %$raw_header;

	my $html    = $raw_content->{html};
	my $text    = $raw_content->{text} || html2text($html);
	my $subject = delete $header{Subject};
	my $from    = delete $header{From};
	my $to      = delete $header{To};

	my $email = Email::Stuffer->text_body($text)->html_body($html)->subject($subject)->from($from)->transport(
		Email::Sender::Transport::SMTP->new(
			{
				host => 'localhost',
			}
		)
	);
	foreach my $key ( keys %header ) {
		$email->header( $key, $header{$key} );
	}

	# TODO: send would return an Email::Sender::Success__WITH__Email::Sender::Role::HasMessage object on success
	# but it is unclear what would be returned if it failed
	# so for now we return undef on success and the exception string on failure
	my $err;
	eval { $email->to($to)->send_or_die; 1 } or do { $err = $@ // 'Unknonw error'; };
	return $err;
}

sub html2text {
	my $html = shift;

	$html =~ s{</?p>}{\n}gi;
	$html =~ s{<a href="([^"]+)">([^<]+)</a>}{$2 [ $1 ]}gi;

	$html =~ s{<[^>]+>}{}g;

	return $html;
}

1;

