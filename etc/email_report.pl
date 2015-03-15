use strict;
use warnings;
use 5.010;

use lib 'lib';
use Perl::Maven::DB;

my $db  = Perl::Maven::DB->new('pm.db');
my $emails = $db->{dbh}->selectall_arrayref('SELECT email FROM user');;
#say scalar @$emails;

# skip the free mail systems
my %SKIP = map { $_ => 1 } qw(
	gmail.com
	hotmail.com
	hotmail.fr
	hotmail.ca
	hotmail.com.tr
	hotmail.gr
	hotmail.cm
	msn.com
	yahoo.com
	yahoo.co.in
	yahoo.in
	yahoo.fr
	yahoo.co.uk
	yahoo.co.id
	yahoo.ca
	yahoo.com.br
	yahoo.de
	yahoo.com.tw
	mail.com
	sina.com
	ymail.com
	outlook.com
	comcast.net
	rediffmail.com
	qq.com
	aol.com
	live.com
	me.com
	mac.com
	verizon.net
	googlemail.com
	126.com
	163.com
	mail.ru
	gmx.de
	gmx.net
	web.de
);

my %stats;
foreach my $email (@$emails) {
	next if $email->[0] =~ /\s/; # should not be such addresses
	next if $email->[0] !~ /\@/; # should not be such addresses
	my ($domain) = $email->[0] =~ /\@(.*)/;
	next if $SKIP{$domain};
	push @{ $stats{$domain} }, $email->[0];
}
foreach my $domain (keys %stats) {
	@{ $stats{$domain} } = sort @{ $stats{$domain} };
}

say scalar keys %stats;
foreach my $domain (sort {
		scalar(@{$stats{$a}}) <=>  scalar(@{$stats{$b}})
			or 
		$a cmp $b
	} keys %stats) {
	printf "%4s %s\n", scalar(@{ $stats{$domain} }), $domain;
	foreach my $email (@{ $stats{$domain} }) {
		say "      $email";
	}
}

