package t::lib::Test;
use strict;
use warnings;

use base 'Exporter';

our @EXPORT = qw(start stop);

use Cwd qw(cwd);
use File::Basename qw(basename);
use File::Spec;
use File::Temp qw(tempdir);
use File::Copy qw(copy move);

my $backup;
my $process;

sub start {
    my $dir = tempdir( CLEANUP => 1 );

    # print STDERR "# $dir\n";
	my ($cnt) = split /_/, basename $0;

    $ENV{PERL_MAVEN_TEST} = 1;
    $ENV{PERL_MAVEN_PORT} = 20_000+$cnt;
    $ENV{PERL_MAVEN_MAIL} = File::Spec->catfile( $dir, 'mail.txt' );

	my $t = time;
	if (-e 'pm.db') {
		$backup = "pm.db.$t";
		move 'pm.db', $backup;
	}
	system "$^X bin/convert.pl" and die;


	my $root = cwd();
    if ( $^O =~ /win32/i ) {
        require Win32::Process;

        #import Win32::Process;

        Win32::Process::Create( $process, $^X,
            "perl -Ilib -It\\lib $root\\bin\\app.pl",
            0, Win32::Process::NORMAL_PRIORITY_CLASS(), "." )
            || die ErrorReport();
    } else {
	    $process = fork();

        die "Could not fork() while running on $^O" if not defined $process;

        if ($process) { # parent
            sleep 1;
            return $process;
        }

        my $cmd = "$^X -Ilib -It/lib $root/bin/app.pl";
        exec $cmd;
    }

    return 1;
}

sub stop {
    return if not $process;
    if ( $^O =~ /win32/i ) {
        $process->Kill(0);
    } else {
        kill 9, $process;
    }
}

END {
    stop();
	if ($backup) {
		move $backup, 'pm.db';
	}
}


1;

