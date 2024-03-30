use strict;
use warnings;
use 5.010;

use Net::Twitter;
use Config::Tiny;
use Data::Dumper qw(Dumper);
use File::HomeDir;
use Cpanel::JSON::XS qw(decode_json);
use Path::Tiny       qw(path);

my $file = 'meta/perlmaven.com/perlmaven.com/meta/archive.json';
my $url  = 'https://perlmaven.com';

my $data    = decode_json path($file)->slurp_utf8;
my @entries = map { { filename => $_->{filename}, title => $_->{title}, } }
	grep { $_->{filename} !~ m{^pro/} } @$data;

#die Dumper \@entries;
my $this = $entries[ int rand( scalar @entries ) ];
die if not $this;

my $config_file = File::HomeDir->my_home . '/.twitter';
die "$config_file is missing\n" if not -e $config_file;
my $config = Config::Tiny->read( $config_file, 'utf8' );

#print Dumper $config;

my $nt = Net::Twitter->new(
	ssl                 => 1,
	traits              => [qw/API::RESTv1_1/],
	consumer_key        => $config->{perlmaven}{api_key},
	consumer_secret     => $config->{perlmaven}{api_secret},
	access_token        => $config->{perlmaven}{access_token},
	access_token_secret => $config->{perlmaven}{access_token_secret},
);

my $response = $nt->update("$this->{title} $url/$this->{filename}");
