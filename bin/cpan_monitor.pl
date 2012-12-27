#!/usr/bin/perl
use strict;
use warnings;
use 5.010;

# CPAN Monitor
# Allow users to subscribe to module names and to a feature
#   1. send alert when new version is uploaded
#   2. send alert when a new version of a dependency was uploaded

use Data::Dumper;
use MetaCPAN::API;
use JSON qw(from_json to_json);
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Slurp qw(read_file write_file);
use MIME::Lite;
use Getopt::Long qw(GetOptions);

my %opt;
usage() if not @ARGV;
GetOptions(\%opt, 'help', 'run', 'email', 'verbose', 'setup') or usage();
usage() if $opt{help};

sub usage {
    my ($msg) = @_;

    if ($msg) {
        print "**** $msg\n\n";
    }

    print <<"USAGE";
Usage:
    --help

    --run
    --email
    --verbose

    --setup
#    --addsubscriber --name NAME  --email email
USAGE

    exit;
};

my $file = dirname(dirname abs_path $0) . "/cpan.json";

my $data = {};
if ($opt{setup}) {
    die "Cannot run --setup. Database already exists\n" if -e $file;
    save_file();
    exit;
}

usage("Need to call --setup") if not -e $file;


exit if not $opt{run};

$data = from_json scalar read_file $file;


my $mcpan = MetaCPAN::API->new;
update_subscriptions();
collect_changes();
update_changes();
generate_messages();
send_messages();
clear_changes();
save_file();


exit;
##################################################################

sub save_file {
    write_file $file, to_json($data, { utf8 => 1, pretty => 1 });
}

sub _log {
    my $msg = shift;
    return if not $opt{verbose};
    print "$msg\n";
    return;
}

sub update_subscriptions {
    _log("Update subscriptions");
    foreach my $uid (sort keys %{ $data->{subscribers} }) {
        _log("Subscriber $uid");
        my $msg = '';
        foreach my $name ( sort keys %{$data->{subscribers}{$uid}{modules} }) {
            _log("   Start monitoring module $name");
            $data->{modules}{$name} ||= {};
        }
    }

    # TODO go over modules and remove the ones that has no subscriber??
    return;
}


sub collect_changes {
    foreach my $name (sort keys %{ $data->{modules} }) {
        _log("Module $name");
        my $module   = $mcpan->module( $name );
        my $change = '';
        if (not defined $data->{modules}{$name}{version}) {
            $change = "Module $name N/A => $module->{version}\n";
        } elsif ($data->{modules}{$name}{version} ne $module->{version}) {
            $change = "Module $name $data->{modules}{$name}{version} => $module->{version}\n";
        }
        if ($change) {
            my $dist = $mcpan->release( distribution => $module->{distribution} );
            _log("$module->{distribution}  ");
            foreach my $dep (@{ $dist->{dependency} }) {
                next if $dep->{module} eq 'perl';
                _log("   $dep->{module}  $dep->{version}");
                if (not exists $data->{modules}{$name}{dependencies}{$dep->{module}}) {
                    $change .= "Dependency added $dep->{module} $dep->{version}\n";
                } elsif ( $data->{modules}{$name}{dependencies}{$dep->{module}} ne $dep->{version}) {
                    $change .= "Dependency changed $dep->{module} $data->{modules}{$name}{dependencies}{$dep->{module}} => $dep->{version}\n";
                }
                
                $data->{modules}{ $dep->{module} } ||= {}; # add it to the list of modules being monitored
                $data->{modules}{$name}{dependencies}{$dep->{module}} = $dep->{version};
            }
        }

        $data->{modules}{$name}{change} = $change;
        $data->{modules}{$name}{version} = $module->{version};
    }
}

{
    my %deps;

# go over all the modules
#   go over all the dependencies in a recursive way
#     if any of the dependencies has changed, add this information to the "deps_changed" field
    sub update_changes {
        foreach my $name (sort keys %{ $data->{modules} }) {
            %deps = ();
            $deps{$name} = undef;
            _deps($name);
            
            my $changes = '';
            foreach my $d (keys %deps) {
                next if not defined $deps{$d};
                $changes .= "Dep: $d\n   $deps{$d}";
            }
            $data->{modules}{$name}{deps_changed} = $changes;
        }
        return;
    }

    sub _deps {
        my ($name) = @_;
        foreach my $d (sort keys %{ $data->{modules}{$name}{dependencies} || {} }) {
            next if exists $deps{ $d };
            $deps{ $d } = $data->{modules}{$name}{changes};
            _deps($d);
        }
    }
}

sub generate_messages {
    foreach my $uid (sort keys %{ $data->{subscribers} }) {
        _log("Subscriber $uid");
        my $msg = '';
        foreach my $name ( sort keys %{$data->{subscribers}{$uid}{modules} }) {
            if ($data->{modules}{$name}{change}) {
                $msg .= delete $data->{modules}{$name}{change};
            }
        }
        $data->{subscribers}{$uid}{msg} = $msg;
    }
    return;
}

sub send_messages {
    foreach my $uid (sort keys %{ $data->{subscribers} }) {
#        say "Subscriber $uid";
        if ($data->{subscribers}{$uid}{msg}) {
          my $msg = MIME::Lite->new(
            From    => 'Perl Maven <gabor@perl5maven.com>',
            To      => $data->{subscribers}{$uid}{email},
            Subject => 'Perl Maven CPAN update',
            Data    => $data->{subscribers}{$uid}{msg},
          );
          if (@ARGV and $ARGV[0] eq 'send') {
            $msg->send;
          } else {
            print "The message\n";
            print "--------------------\n";
            print $data->{subscribers}{$uid}{msg};
            print "---------------------\n";
          }
        }
        delete $data->{subscribers}{$uid}{msg};
    }

    return;
}

sub clear_changes {
    foreach my $name (sort keys %{ $data->{modules} }) {
        $data->{modules}{$name}{change}       = '';
        $data->{modules}{$name}{deps_changed} = '';
    }
}

