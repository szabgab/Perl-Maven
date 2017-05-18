package Perl::Maven::Analyze;
use 5.010;
use strict;
use warnings;
use Moo;
use MooX::Options;

use Archive::Any ();
use Cwd qw(getcwd);
use Data::Dumper qw(Dumper);
use MetaCPAN::Client ();
use MongoDB          ();
use LWP::Simple qw(getstore);
use Path::Tiny qw(path);
use Capture::Tiny qw(capture);
use Cpanel::JSON::XS qw(decode_json);
use Path::Iterator::Rule ();
use File::Temp qw(tempdir);
use Perl::PrereqScanner;

our $VERSION = '0.11';

option limit => ( is => 'ro', default => 1, format => 'i' );
option verbose => ( is => 'ro', default => 0 );
option conf => ( is => 'ro', required => 0, format => 's', doc => 'Path to configuration JSON file' );
option dir =>
	( is => 'ro', required => 0, format => 's', doc => 'Path to directory that holds the source code of the projects' );

sub _log {
	my ( $self, $msg ) = @_;
	say $msg if $self->verbose;
}

sub run {
	my ($self) = @_;
	$self->_log('run');

	$self->fetch_cpan;

	#$self->process_projects;

}

sub process_projects {
	my ($self) = @_;

	my $home_dir = getcwd();
	my $dir      = $self->dir;
	die "Dir '$dir' does not exist\n" if not -d $dir;
	my $config = decode_json path( $self->conf )->slurp_utf8;
	foreach my $p ( @{ $config->{projects} } ) {

		#say Dumper $p;
		next if not $p->{enabled};
		my $path = "$dir/$p->{dir}";
		if ( -e $path ) {
			if ( $p->{type} eq 'git' ) {
				$self->_log("git pull for '$p->{git_url}'");
				chdir $path;
				my ( $stdout, $stderr, $exit ) = capture { system 'git pull -q' };

				#if 'Already up-to-date.';
				say "OUT: $stdout";
				say "ERR: $stderr";
				say "EXIT: $exit";
				chdir $home_dir;
			}
			else {
				warn "Type '$p->{type}' is not handled yet\n";
				next;
			}
		}
		else {
			if ( $p->{type} eq 'git' ) {
				chdir $dir;
				$self->_log("Cloning '$p->{git_url}'");
				my ( $stdout, $stderr, $exit ) = capture { system "git clone -q $p->{git_url} $p->{dir}" };

				#say "OUT: $stdout"; # expect to be empty
				#say "ERR: $stderr"; # expect to be empty
				#say "EXIT: $exit"; # expect 0
				chdir $home_dir;

				#$self->analyze_project($p, '.');
			}
			else {
				warn "Type '$p->{type}' is not handled yet\n";
				next;
			}
		}
	}

	return;
}

sub analyze_project {
	my ( $self, $p, $dir ) = @_;

	# list all the files
	# go over files one
	$self->_log("DIR $dir");
	my $rule = Path::Iterator::Rule->new;
	my @files = $rule->all( $dir, { relative => 1 } );
	$self->_log( 'Files: ' . Dumper \@files );

	my $db      = $self->mongodb('perl');
	my $scanner = Perl::PrereqScanner->new;
	my @docs;
	foreach my $file (@files) {

		#say $file;
		my $path = "$dir/$file";
		say "Missing $file" if not -e $path;
		next if $file !~ /\.(pl|pm)$/;

		# Huge files (eg currently Perl::Tidy) will cause PPI to barf
		# So we need to catch those, keep calm, and carry on
		my $prereqs = eval { $scanner->scan_file($path); };
		if ($@) {
			warn $@;
			next;
		}

		my $depsref = $prereqs->as_string_hash();
		my %data    = (
			project => $p->{project},
			version => $p->{version},
			author  => $p->{author},

	   # at one point I think I saw cpan module release with the same version number MetaCPAN should probably catch that
	   # but maybe we should also notice, protect ourself and maybe even complain
			file    => $file,
			depends => $depsref,
		);
		push @docs, \%data;

	}

	# not supported in old MongoDB
	#$db->delete_many( { project => $p->{project} } );
	$db->remove( { project => $p->{project} } );

	my $db_modules = $self->mongodb('perl_modules');

	# not yet supported on the server
	#$db->insert_many( \@docs );
	#$self->mongodb('perl_projects')->insert_one( { project => $p->{project} } );
	foreach my $d (@docs) {
		$db->insert($d);
		foreach my $module ( keys %{ $d->{depends} } ) {
			$self->_log("Adding module '$module'");
			eval { $db_modules->insert( { _id => $module } ) };    # disregard duplicate error
		}
	}
	eval { $self->mongodb('perl_projects')->insert( { _id => $p->{project} } ) };
	return;
}

sub fetch_cpan {
	my ($self) = @_;

	my $mcpan  = MetaCPAN::Client->new;
	my $recent = $mcpan->recent( $self->limit );
	my $db     = $self->mongodb('perl');

	while ( my $r = $recent->next ) {    # https://metacpan.org/pod/MetaCPAN::Client::Release
		$self->_log( 'project: ' . $r->distribution . ' version: ' . $r->version );
		my $res = $db->find_one( { project => $r->distribution, version => $r->version } );
		next if $res;                    # already processed

		my $dir = tempdir( CLEANUP => 1 );

		#say $r->distribution;   # EBook-EPUB-Lite
		#say 'Processing ', $r->name;    # EBook-EPUB-Lite-0.71
		my $local_zip_file = $dir . '/' . $r->archive;

		my $rc = getstore( $r->download_url, $local_zip_file );
		if ( $rc != 200 ) {    # RC_OK
			say 'ERROR: Failed to download ', $r->download;
			next;
		}

		#say glob "$dir/*";
		#say -e $local_zip_file ? 'exists' : 'not';

		my $archive = Archive::Any->new($local_zip_file);
		if ( not defined $archive ) {
			say "ERROR: Could not launch Archive::Any for '$local_zip_file'";
			next;
		}
		$archive->extract($dir);
		my @files = $archive->files;
		undef $archive;
		unlink $local_zip_file;
		my %data = (
			project => $r->distribution,
			version => $r->version,
			author  => $r->author,
		);
		$self->analyze_project( \%data, $dir );

	}
	return;
}

1;

# from Perl::Maven::Monitor
sub mongodb {
	my ( $self, $collection ) = @_;
	my $client = MongoDB::MongoClient->new( host => 'localhost', port => 27017 );
	my $database = $client->get_database('PerlMaven');
	return $database->get_collection($collection);
}

1;

