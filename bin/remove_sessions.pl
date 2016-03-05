use strict;
use warnings;

opendir my $dh, 'sessions' or die;
my $days = 30;
print "Age limit: $days days\n\n";

my $total   = 0;
my $old     = 0;
my $deleted = 0;
while ( my $f = readdir $dh ) {
	next if $f =~ /^\./;
	next if $f !~ /\.yml$/;
	$total++;
	if ( -M "sessions/$f" > $days ) {
		$old++;
		if ( unlink "sessions/$f" ) {
			$deleted++;
		}
	}
}
print "Total:   $total\n";
print "Old:     $old\n";
print "Deleted: $deleted\n";
