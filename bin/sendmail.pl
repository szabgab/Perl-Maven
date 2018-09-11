#!/usr/bin/perl
use strict;
use warnings;
use v5.12;

use Data::Dumper qw(Dumper);
use Getopt::Long qw(GetOptions);

use Cwd qw(abs_path cwd);
use File::Basename qw(dirname);
#use Dancer2;
use YAML::XS qw(LoadFile);
use Digest::SHA;

binmode( STDOUT, ':encoding(UTF-8)' );
binmode( STDERR, ':encoding(UTF-8)' );

use lib 'lib';
use Perl::Maven;
use Perl::Maven::Config;
use Perl::Maven::DB;
use Perl::Maven::Sendmail qw(send_mail html2text);

my $dancer = Perl::Maven->psgi_app;

main();
exit;
################################################################################

sub main {

	my %opt;
	GetOptions( \%opt, 'to=s@', 'exclude=s@', 'url=s', 'send', 'domain=s' ) or usage();
	usage() if not $opt{to} or not $opt{url} or not $opt{domain};

	my $cfg     = LoadFile('config.yml');
	my $mymaven = Perl::Maven::Config->new( $cfg->{mymaven_yml} );
	die "Domain '$opt{domain}' could not be found in configuration file"
		if not $mymaven->{config}{domains}{ $opt{domain} };

	my $config = $mymaven->config( $opt{domain} );
	$mymaven = $config;

	send_messages(
		$mymaven,
		{
			From      => $mymaven->{from},
			'List-Id' => $mymaven->{listid},
		},
		\%opt,
	);
}

sub build_content {
	my ( $url,  $query_string ) = @_;
	my ( $host, $path_info )    = $url =~ m{https?://([^/]+)(/.*)};

	my $env = {
		'REMOTE_ADDR'     => '127.0.0.1',
		'REQUEST_METHOD'  => 'GET',
		'SCRIPT_NAME'     => '',
		'psgi.url_scheme' => 'http',
		'HTTP_HOST'       => $host,
		'PATH_INFO'       => $path_info,
		'QUERY_STRING'    => $query_string,
		'SERVER_PROTOCOL' => 'HTTP/1.1',
		'REQUEST_URI'     => $path_info,
	};
	my $r = $dancer->($env);

	#die $r->[0]; # http status
	my $utf8 = $r->[2][0];                           # html
	my ($title) = $utf8 =~ m{<title>(.*)</title>};

	die 'missing title' if not $title;

	my %content;
	$content{html} = $utf8;
	$content{text} = html2text($utf8);

	return $title, \%content;
}

sub send_messages {
	my ( $mymaven, $header, $opt ) = @_;

	my %todo;
	my $db = Perl::Maven::DB->new( $mymaven->{dbfile} );

	# TODO remove the hard coding here
	my $unsubscribe_link = grep { $_ eq 'perl_maven_cookbook' } @{ $opt->{to} };
	foreach my $to ( @{ $opt->{to} } ) {
		if ( $to =~ /\@/ ) {
			$todo{$to} //= 0;
			say "Including 1 ($to)";
		}
		else {
			my $emails = $db->get_subscribers($to);
			my $total  = scalar @$emails;
			say "Including $total number of addresses ($to)";
			foreach my $email (@$emails) {
				$todo{ $email->[0] } = $email->[1];
			}
		}
	}
	foreach my $no ( @{ $opt->{exclude} } ) {
		if ( $no =~ /\@/ ) {
			if ( exists $todo{$no} ) {
				delete $todo{$no};
				say "Excluding 1 ($no)";
			}
		}
		else {
			my $emails = $db->get_subscribers($no);
			my $total  = scalar @$emails;
			say "Excluding $total number of addresses ($no)";
			foreach my $email (@$emails) {
				if ( exists $todo{ $email->[0] } ) {
					delete $todo{ $email->[0] };
				}
			}
		}
	}

	my $planned = scalar keys %todo;
	say "Total number of addresses: $planned";
	my $count = 0;
	foreach my $to ( sort { $todo{$a} <=> $todo{$b} } keys %todo ) {

		$count++;
		say "$count out of $planned to $to";
		next if not $opt->{send};
		$header->{To} = $to;
		my $code = Digest::SHA::sha1_hex("unsubscribe$mymaven->{unsubscribe_salt}$to");
		my ( $title, $content ) = build_content( $opt->{url}, ( $unsubscribe_link ? "code=$code&amp;email=$to" : '' ) );
		$header->{Subject} = ( $mymaven->{prefix} . ' ' . $title );

		my $err = send_mail( $header, $content );
		if ($err) {
			say "ERR: $err";
		}
		sleep 1;
	}
	say "Total sent $count. Planned: $planned";
	return;
}

sub usage {
	print <<"END_USAGE";
Usage: $0

    --url http://url
    --to mail\@address.com
    --to produc_name            (all the subscribers of this product)
    --domain NAME               (the domain name)

    --send if I really want to send the messages

    --exclude       Anything that --to can accept - excluded these

END_USAGE

	my $db       = Perl::Maven::DB->new('pm.db');
	my $products = $db->get_products;
	foreach my $code (
		sort
		keys %$products
		)
	{
		say "    --to $code";
	}
	exit;
}
