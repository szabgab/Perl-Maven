package Fake;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(passphrase);

sub passphrase {
	my ($password) = @_;
	return bless { password => $password }, 'Fake';
}

sub generate {
	my ($self) = @_;
	return $self->{password};
}

sub matches {
	my ( $self, $password ) = @_;
	return $self->{password} eq $password;
}

1;

