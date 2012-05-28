#!/usr/bin/perl
use strict;
use warnings;
use v5.12;

use Getopt::Long qw(GetOptions);
use MIME::Lite;
use Cwd qw(abs_path cwd);
use File::Slurp    qw(read_file);
use WWW::Mechanize;

my %opt;
GetOptions(\%opt,
	'to=s',
	'url=s'
) or die;
die "Usage: $0 --to mail\@address.com --url http://url\n" if not $opt{to} or not $opt{url};

my $from = 'Gabor Szabo <gabor@szabgab.com>';

my $w = WWW::Mechanize->new;
#say $opt{url};
$w->get($opt{url});
my $subject = $w->title;

my %content;
$content{html} = $w->content;
$content{text} = html2text($w->content);


if ($opt{to} eq 'aa') {
	my @emails = ('szabgab@gmail.com', 'gabor@perl.org.il');
	foreach my $email (@emails) {
		sendmail($email);
	}
} else {
	sendmail($opt{to});
}

sub sendmail {
	my $to = shift;
	
	my $msg = MIME::Lite->new(
		From     => $from,
		To       => $to,
		Type     => 'multipart/alternative',
		Subject  => $subject,
		);

	my %type = (
		text => 'text/plain',
		html => 'text/html',
	);

	foreach my $t (qw(text html)) {
		my $att = MIME::Lite->new(
				Type     => 'text',
				Data     => $content{$t},
				Encoding => 'quoted-printable',
		);
		$att->attr("content-type" => "$type{$t}; charset=UTF-8");
		$att->replace("X-Mailer" => "");
		$att->attr('mime-version' => '');
		$att->attr('Content-Disposition' => '');

		$msg->attach($att);
	}
	$msg->send;
	
	return;
}

sub html2text {
	my $html = shift;
	
	$html =~ s{</?p>}{\n}gi;
	$html =~ s{<a href="([^"]+)">([^<]+)</a>}{$2 [ $1 ]}gi;

	$html =~ s{<[^>]+>}{}g;

	return $html;
}