package Perl::Maven::Config;
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use YAML         qw(LoadFile);
use Storable     qw(dclone);

sub new {
	my ($class, $host, $path) = @_;

	return bless {
		host     => host($host),
		realhost => realhost($host),
		path     => $path,
	}, $class;
}

sub config {
	my ($self) = @_;

	my $host = $self->{host};
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

	my $config = LoadFile($self->{path});

	my $mymaven = dclone $config->{$domain};
	$mymaven->{lang} = $lang;
	if ($config->{$domain}{sites}{$host}) {
		my $host_config = $config->{$domain}{sites}{$host};
		if ($host_config) {
			foreach my $key (keys %$host_config) {
				$mymaven->{$key} = $host_config->{$key};
			}
		}
	}

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

