use strict;
use warnings;
use Data::Dumper;

die "Usage: $0 /var/log//nginx/code-maven.com.log \n" if not @ARGV;

foreach my $file (@ARGV) {
	die "Cannot handle $file\n" if $file !~ /\.log(\.\d)?$/;
	open my $fh, '<', $file or die;
	my %download;
	my %seen;
	while ( my $line = <$fh> ) {

		#next if $line !~ /\.mp3/;
		my ( $ip, $mp ) = $line =~ m{^(\S+)\s.*?GET\s+\S+/([^/]+\.mp[34])\s};
		next if not $mp;             # e.g. HEAD instead of GET
		                             #die $line if not $mp3;
		next if $seen{$mp}{$ip}++;
		$download{$mp}++;
	}
	print Dumper \%download;
}

