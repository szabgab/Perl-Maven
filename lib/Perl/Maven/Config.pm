package Perl::Maven::Config;
use strict;
use warnings;

=head1 NAME

Perl::Maven::Config - read the mymaven.yml configuration file

=head1 DESCRPTION

  my $mymaven = Perl::Maven::Config->new('/path/to/mymaven.yml'); 
  my $cfg = $mymaven->config('hostname.org');
  $cfg->{site}


See sample configuration file: C<t/files/mymaven.yml>.

See also L<Perl::Maven>.

=cut

our $VERSION = '0.11';

use Cwd qw(abs_path);
use Data::Dumper qw(Dumper);
use File::Basename qw(dirname);
use Hash::Merge::Simple qw(merge);
use YAML::XS qw(LoadFile);
use Storable qw(dclone);

sub new {
	my ( $class, $path ) = @_;

	$path = $ENV{MYMAVEN_YML} || $path;

	die "Missing configuration file '$path'" if not -e $path;

	my $self = bless {
		root => ( dirname( dirname( abs_path($path) ) ) || abs_path('.') ),
		config => scalar LoadFile($path),
	}, $class;

	foreach my $domain ( keys %{ $self->{config}{domains} } ) {
		$self->{hosts}{$domain} = $domain;
		foreach my $host ( keys %{ $self->{config}{domains}{$domain}{sites} } ) {
			$self->{hosts}{$host} = $domain;
		}
	}
	return $self;
}

sub config {
	my ( $self, $fullhost ) = @_;

	my $host   = host($fullhost);
	my $domain = $self->{hosts}{$fullhost};
	die "Hostname '$fullhost' not in configuration file\n" if not defined $domain;
	my $mymaven = dclone $self->{config}{domains}{$domain};
	$mymaven->{domain} = $domain;
	my $lang = substr( $host, 0, -length($domain) - 1 ) || 'en';

	die 'localhost is not supported'
		if $host =~ /localhost/;    # avoid stupid mistakes

	$host =~ s/:.*//;               # remove port

	# TODO check in the sites.yml file?
	#if (! config->{mymaven}{$host}) {
	#	die "No such host '$host'"; # Avoid more stupid mistakes
	#return config->{mymaven}{default};
	#}

	$mymaven->{lang} = $lang;
	my $host_config = $mymaven->{sites}{$host};
	if ($host_config) {
		$mymaven = merge( $mymaven, $host_config );
	}

	#my $real_host_config = $mymaven->{sites}{ realhost($fullhost) };
	#if ($real_host_config) {
	#	$mymaven = merge( $mymaven, $real_host_config );
	#}
	delete $mymaven->{sites};

	#die Dumper $mymaven;
	$mymaven->{root} = $self->_update_root( $mymaven->{root} );
	$mymaven->{meta} = $self->_update_root( $mymaven->{meta} );
	$mymaven->{dirs}{$_} = $self->_update_root( $mymaven->{dirs}{$_} ) for keys %{ $mymaven->{dirs} };

	#die Dumper $mymaven;

	$mymaven->{site}
		= _slash( $mymaven->{root} . '/sites/' . $mymaven->{lang} );

	#die Dumper $mymaven;
	return $mymaven;
}

sub _slash {
	my ($path) = @_;
	$path =~ s{//+}{/}g;
	return $path;
}

sub _update_root {
	my ( $self, $path ) = @_;
	return $path if $path =~ m{^/};    # absolute path should not be changed
	return _slash("$self->{root}/$path");
}

sub realhost {
	my ($host) = @_;
	$host =~ s/:.*//;                  # remove port
	return $host;
}

sub host {
	my ($host) = @_;
	$host =~ s/:.*//;                  # remove port
	$host =~ s/\.local$//g;            # development environemt domain.com.local
	return $host;
}

1;

