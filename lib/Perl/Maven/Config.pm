package Perl::Maven::Config;
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Hash::Merge::Simple qw(merge);
use YAML         qw(LoadFile);
use Storable     qw(dclone);

sub new {
	my ($class, $path) = @_;

	return bless {
		path     => $path,
		config   => scalar LoadFile($path),
	}, $class;
}

sub config {
	my ($self, $fullhost) = @_;

	my $host = host($fullhost);
	my $domain;
	if ($host =~ /([^.]+\.(com|net|org))$/) {
		$domain = $1;
	} elsif ($host =~ /([^.]+\.[^.]+\.[^.]+)$/) {
		$domain = $1;
	} else {
		die "Could not map '$host' to domain";
	}
	my $lang = substr($host, 0, - length($domain) - 1) || 'en';

	die 'localhost is not supported' if $host =~ /localhost/; # avoid stupid mistakes

	$host =~ s/:.*//; # remove port

	# TODO check in the sites.yml file?
	#if (! config->{mymaven}{$host}) {
	#	die "No such host '$host'"; # Avoid more stupid mistakes
		#return config->{mymaven}{default};
	#}

	my $config = $self->{config};
	my $mymaven = dclone $config->{$domain};
	$mymaven->{lang} = $lang;
	my $host_config = $mymaven->{sites}{$host};
	if ($host_config) {
		$mymaven = merge( $mymaven, $host_config );
	}
	delete $mymaven->{sites};

	$mymaven->{site} = $mymaven->{root} . '/sites/' . $mymaven->{lang};
	#die Dumper $mymaven;
	return $mymaven;
}

sub realhost {
	my ($host) = @_;
	$host =~ s/:.*//; # remove port
	return $host;
}
sub host {
	my ($host) = @_;
	$host =~ s/:.*//; # remove port
	$host =~ s/\.(local|linux|win32)$//g; # development environemts domain.com.linux or domain.com.win32 or domain.com.local
	return $host;
}

1;

