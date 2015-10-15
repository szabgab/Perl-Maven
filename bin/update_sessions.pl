use strict;
use warnings;
use 5.010;

# converting old sessions with e-mail addresses to new sessions with uid
use Data::Dumper;
use YAML::XS qw(LoadFile DumpFile);
use lib 'lib';
use Perl::Maven::DB;
my $db = Perl::Maven::DB->new('pm.db');

opendir my $dh, 'sessions' or die;

while ( my $f = readdir $dh ) {
	next if $f =~ /^\./;
	next if $f !~ /\d{10}\.yml$/;
	my $data = LoadFile "sessions/$f";

	#die Dumper $data;
	my $email = delete $data->{email};
	next if not $email;
	my $user = $db->get_user_by_email($email);
	$data->{uid} = $user->{id};
	DumpFile( "sessions/$f", $data );

}

