package Perl::Maven::Debug;
use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Exporter qw(import);
use DataTime;

our $VERSION = '0.11';
our @EXPORT  = qw(tmplog);

=head1 NAME

Perl::Maven::Debug - simple debug tool

=head1 DESCRPTION

Tool used to log some data to a file in a well-known location unrelated to Dancer.
Might be used on the production server by temporarily adding calls to

    use Perl::Maven::Debug qw(tmplog);
    tmplog("name", $var, $other);

See also L<Perl::Maven>.

=cut

sub tmplog {
	my @data = @_;

	my $now  = DataTime->now;
	my $file = '/tmp/perl-maven.log';
	if ( open my $fh, '>>encoding(UTF-8)', $file ) {
		print $fh "---------------------------------- $now\n";
		for my $entry (@data) {
			if ( ref $entry ) {
				print $fh Dumper $entry;
			}
			else {
				print $fh $entry;
			}
			print $fh "\n";
		}
	}
}

1;

