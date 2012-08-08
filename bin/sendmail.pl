#!/usr/bin/perl
use strict;
use warnings;
use v5.12;

use Data::Dumper qw(Dumper);
use Getopt::Long qw(GetOptions);
use MIME::Lite;
use Cwd qw(abs_path cwd);
use File::Slurp    qw(read_file);
use WWW::Mechanize;
use DBI;

my $dsn = "dbi:SQLite:dbname=pm.db";

my $dbh = DBI->connect($dsn, "", "", {
	RaiseError => 1,
	PrintError => 0,
	AutoCommit => 1,
});

my $emails = $dbh->selectall_arrayref(q{
   SELECT email
   FROM user, subscription, product
   WHERE user.id=subscription.uid
     AND user.verify_time is not null
     AND product.id=subscription.pid
     AND product.code=?
}, undef, 'perl_maven_cookbook');
#die Dumper $emails;

my %opt;
GetOptions(\%opt,
	'to=s',
	'url=s'
) or die;
die "Usage: $0 --to mail\@address.com --url http://url\n" if not $opt{to} or not $opt{url};

my $from = 'Gabor Szabo <gabor@perl5maven.com>';

my $w = WWW::Mechanize->new;
#say $opt{url};
$w->get($opt{url});
my $subject = '[Perl Maven] ' . $w->title;

my %content;
$content{html} = $w->content;
$content{text} = html2text($w->content);


if ($opt{to} eq 'all') {
	#my $emails = ['szabgab@gmail.com', 'gabor@perl.org.il'];
	my $total = scalar @$emails;
	print "Sending to $total number of addresses\n";
	my $count = 0;
	foreach my $email (@$emails) {
		$count++;
		say "$count out of $total  to $email->[0]";
		sendmail($email->[0]);
		sleep 1;
	}
} else {
	sendmail($opt{to});
}

sub sendmail {
	my $to = shift;

	my $msg = MIME::Lite->new(
		'From'     => $from,
		'To'       => $to,
		'Type'     => 'multipart/alternative',
		'Subject'  => $subject,
		);
	$msg->attr('List-Id'  => 'Perl 5 Maven newsletter <newsletter.perl5maven.com>'),

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
