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

my $file = dirname(dirname abs_path $0) . "/cpan.json";
my $data = {};
if (-e $file) {
    $data = from_json scalar read_file $file;
}

my $mcpan = MetaCPAN::API->new;

update_subscriptions();
collect_changes();
generate_messages();
send_messages();
write_file $file, to_json($data, { utf8 => 1, pretty => 1 });

sub update_subscriptions {
    foreach my $uid (sort keys %{ $data->{subscribers} }) {
#        say "Subscriber $uid";
        my $msg = '';
        foreach my $name ( sort keys %{$data->{subscribers}{$uid}{modules} }) {
#            print "$name\n";
            $data->{modules}{$name} ||= {};
        }
    }

    # TODO go over modules and remove the ones that has no subscriber??
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
            print $data->{subscribers}{$uid}{msg};
          }
        }
        delete $data->{subscribers}{$uid}{msg};
    }

    return;
}

sub collect_changes {
    foreach my $name (sort keys %{ $data->{modules} }) {
#        say "Module $name";
        my $module   = $mcpan->module( $name );
        my $change = '';
        if (not defined $data->{modules}{$name}{version}) {
            $change = "Module $name N/A => $module->{version}\n";
        } elsif ($data->{modules}{$name}{version} ne $module->{version}) {
            $change = "Module $name $data->{modules}{$name}{version} => $module->{version}\n";
        }
        if ($change) {
            my $dist = $mcpan->release( distribution => $module->{distribution} );
            #say "$module->{distribution}  ";
            foreach my $dep (@{ $dist->{dependency} }) {
                #say "   $dep->{module}  $dep->{version}"
                if (not exists $data->{modules}{$name}{dependencies}{$dep->{module}}) {
                    $change .= "Dependency added $dep->{module} $dep->{version}\n";
                } elsif ( $data->{modules}{$name}{dependencies}{$dep->{module}} ne $dep->{version}) {
                    $change .= "Dependency changed $dep->{module} $data->{modules}{$name}{dependencies}{$dep->{module}} => $dep->{version}\n";
                }
                $data->{modules}{$name}{dependencies}{$dep->{module}} = $dep->{version};
            }
        }

        $data->{modules}{$name}{change} = $change;
        $data->{modules}{$name}{version} = $module->{version};
    }
}

sub generate_messages {
    foreach my $uid (sort keys %{ $data->{subscribers} }) {
#        say "Subscriber $uid";
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

