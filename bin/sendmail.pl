#!/usr/bin/perl
use strict;
use warnings;
use v5.12;

use Data::Dumper qw(Dumper);
use Getopt::Long qw(GetOptions);
#use MIME::Lite;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP qw();
use Email::MIME::Creator;
#use Email::Sender;
use Cwd qw(abs_path cwd);
use File::Slurp    qw(read_file);
use WWW::Mechanize;
use DBI;
use YAML qw();
use Try::Tiny;

binmode(STDOUT, ':utf8');



my $dsn = "dbi:SQLite:dbname=pm.db";

my $dbh = DBI->connect($dsn, "", "", {
	RaiseError => 1,
	PrintError => 0,
	AutoCommit => 1,
});

my $config = YAML::LoadFile('config.yml');
my $mymaven = $config->{mymaven}{default};
my $from = $mymaven->{from};

my %opt;
GetOptions(\%opt,
	'to=s@',
	'url=s',
	'send',
) or usage();
usage() if not $opt{to} or not $opt{url};

my ($subject, %content) = build_content();
send_messages();
exit;
################################################################################

sub build_content {
	my $w = WWW::Mechanize->new;
	$w->get($opt{url});
	die 'missing title' if not $w->title;
	my $subject = $mymaven->{prefix} . ' ' . $w->title;

	my %content;
	my $utf8 = $w->content;
	$content{html} = $utf8;
	$content{text} = html2text($utf8);

	return $subject, %content;
}

sub send_messages {
    my %sent;
    my $count = 0;
    my $planned = 0;
    foreach my $to (@{$opt{to}}) {
	    if ($to =~ /\@/) {
            $planned++;
            next if $sent{$to};
	    send_mail($to);
            $count++;
            $sent{$to} = 1;
	    } else {
		    my $emails = $dbh->selectall_arrayref(q{
		        SELECT email
		        FROM user, subscription, product
		        WHERE user.id=subscription.uid
		          AND user.verify_time is not null
		          AND product.id=subscription.pid
		          AND product.code=?
		    }, undef, $to);
	#'perl_maven_cookbook'
	#die Dumper $emails;
		    my $total = scalar @$emails;
		    print "Sending to $total number of addresses\n";
		    next if not $opt{send};
		    foreach my $email (@$emails) {
                $planned++;
                my $address = $email->[0];
                next if $sent{$address};
			    $count++;
                $sent{$address} = 1;
			    say "$count out of $total to $address";
			    send_mail($address);
			    sleep 1;
            }
		}
	}
	say "Total sent $count. Planned: $planned";
	return;
}

sub send_mail {
	my $to = shift;

	my %type = (
		text => 'text/plain',
		html => 'text/html',
	);
	#print $content{text};
	#exit;

	my @parts;
	foreach my $t (qw(text html)) {
		push @parts, Email::MIME->create(
			attributes => {
				content_type   => $type{$t},
				disposition    => 'attachment',
				encoding       => 'quoted-printable',
				#encoding       => 'base64',
				#encoding       => '8bit',
				charset         => 'UTF-8',
			},
			body_str => $content{$t},
		);
	}
	#print $parts[1]->as_string;
	#exit;

	my $msg = Email::MIME->create(
		header_str => [
			'From'     => $from,
			'To'       => $to,
			#'Type'     => 'multipart/alternative',
			'Subject'  => $subject,
			'List-Id'  => $mymaven->{listid},
			],
		parts => \@parts,
	);
	#print $msg->as_string;
	#exit;

	try {
		sendmail(
			$msg,
    			{
				from => 'gabor@perl5maven.com', # TODO
				transport => Email::Sender::Transport::SMTP->new({
          				host => 'localhost',
					#port => $SMTP_PORT,
      				})
    			}
  		);
	} catch {
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

sub usage {
	print <<"END_USAGE";
Usage: $0 --url http://url
    --send if I really want to send the messages

    --to mail\@address.com
#    --to all                      (all the subscribers) currently not supported

END_USAGE

	my $products = $dbh->selectall_arrayref(q{
	   SELECT code, name
	   FROM product
	});
	foreach my $p (@$products) {
		say "    --to $p->[0]";
	}
	exit;
}
