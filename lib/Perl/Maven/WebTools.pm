package Perl::Maven::WebTools;
use Dancer2 appname => 'Perl::Maven';
use Data::Dumper       qw(Dumper);
use Perl::Maven::Debug qw(tmplog);
use Carp               qw(carp);

my $TIMEOUT = 60 * 60 * 24 * 365;

our $VERSION = '0.11';

my %all_the_authors;

use Exporter qw(import);
our @EXPORT_OK = qw(logged_in get_ip mymaven generate_code pm_template read_tt pm_show_abstract pm_show_page authors);

sub myhost {
	my $host = request->host;
	$host =~ s/\.local:5000//;
	return $host;
}

sub mymaven {
	my $mymaven = Perl::Maven::Config->new( path( config->{appdir}, config->{mymaven_yml} ) );
	return $mymaven->config( myhost() );
}

sub _generate_code {
	my @chars = ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 );
	my $code  = time;
	$code .= $chars[ rand( scalar @chars ) ] for 1 .. 20;
	return $code;
}

sub logged_in {

	#my $email = session('email');
	#if ($email) {
	#	my $db   = setting('db');
	#	my $user  = $db->get_user_by_email($email);
	#	session uid => $user->{id};
	#	session email => undef;
	#}

	if (    session('logged_in')
		and session('uid')
		and session('last_seen') > time - $TIMEOUT )
	{
		session last_seen => time;
		return 1;
	}
	return 0;

}

sub get_ip {

	# direct access
	my $ip = request->remote_address;
	if ( $ip eq '::ffff:127.0.0.1' or $ip eq '127.0.0.1' ) {

		# forwarded by Nginx
		my $forwarded = request->forwarded_for_address;
		if ($forwarded) {
			$ip = $forwarded;
		}
	}
	return $ip;
}

sub _resources {
	if ( scalar(@_) % 2 == 0 ) {
		carp("odd number of elements for hash will follow: _resources(@_)");
	}
	my ( $template, %args ) = @_;

	$args{show_right} = 0;
	return pm_template( $template, \%args );
}

sub pm_template {
	my ( $template, $params ) = @_;
	delete $params->{password};
	my $url  = request->base || '';
	my $path = request->path || '';
	$params->{canonical} = "$url/$path";

	if ( request->path =~ /\.json$/ ) {
		return to_json $params;
	}
	return template $template, $params;
}

sub read_tt {
	my ( $file, $pre_process ) = @_;
	$pre_process //= {};

	my $tt = eval {
		Perl::Maven::Page->new(
			inline => mymaven->{inline},
			media  => mymaven->{dirs}{media},
			root   => mymaven->{root},
			file   => $file,
			tools  => setting('tools'),
			pre    => $pre_process,
		)->read->process(mymaven)->merge_conf( mymaven->{conf} )->data;
	};
	if ($@) {
		error "This error: '$@' should have been caught when the meta files were generated!";
		return {};
	}
	else {
		return $tt;
	}
}

sub pm_show_abstract {
	my ($params) = @_;
	my $tt = read_tt( $params->{path} );

	return redirect $tt->{redirect} if $tt->{redirect};
	$tt->{promo} = $params->{promo} // 1;

	delete $tt->{mycontent};
	_add_author($tt);
	return template 'propage', $tt;
}

sub pm_show_page {
	my ( $params, $data, $pre_process ) = @_;
	$data        //= {};
	$pre_process //= {};

	my $filepath
		= ( delete $params->{path} || ( mymaven->{site} . '/pages' ) ) . "/$params->{article}.txt";

	if ( not -e $filepath ) {
		status 'not_found';
		return template 'error', { 'no_such_article' => 1 };
	}

	my $tt = read_tt( $filepath, $pre_process );

	if ( $tt->{tags} and mymaven->{special} ) {
		( $tt->{feed} ) = grep { mymaven->{special}{$_} } @{ $tt->{tags} };
	}

	return redirect $tt->{redirect} if $tt->{redirect};
	if ( not $tt->{status}
		or ( $tt->{status} !~ /^(show|draft|done)$/ ) )
	{
		status 'not_found';
		return template 'error', { 'no_such_article' => 1 };
	}
	( $tt->{date} ) = split /T/, $tt->{timestamp};

	_add_author($tt);

	my $translator = $tt->{translator};
	my $authors    = authors();
	if ( $translator and $authors->{$translator} ) {
		$tt->{translator_name} = $authors->{$translator}{author_name};
		$tt->{translator_img}  = $authors->{$translator}{author_img};
		$tt->{translator_google_plus_profile}
			= $authors->{$translator}{author_google_plus_profile};
	}
	else {
		if ($translator) {
			error("'$translator'");
		}
		delete $tt->{translator};
	}

	$tt->{$_} = $data->{$_} for keys %$data;
	my $url  = request->base || '';
	my $path = request->path || '';
	$url =~ s{http://}{https://};
	if ( length($path) > 0 and substr( $path, 0, 1 ) eq '/' ) {
		$path = substr( $path, 1 );
	}

	$tt->{canonical} = "$url$path";

	return template $params->{template}, $tt;
}

sub _add_author {
	my ($tt) = @_;

	my $nick    = $tt->{author};
	my $authors = authors();
	if ( $nick and $authors->{$nick} ) {
		$tt->{author_name} = $authors->{$nick}{author_name};
		$tt->{author_img}  = $authors->{$nick}{author_img};
		$tt->{author_html} = $authors->{$nick}{author_html};
		$tt->{author_google_plus_profile}
			= $authors->{$nick}{author_google_plus_profile};
	}
	else {
		delete $tt->{author};
	}
}

sub authors {
	_read_authors();
	return $all_the_authors{ myhost() };
}

sub _read_authors {
	my $host = myhost();

	#tmplog(myhost, mymaven);

	# TODO: The list of author is currently a global which means two sites on the same server can get messed up.
	# for now we are re-reading the whole thing again and again.
	# Later we can prefix the authors hash with the mymaven->{root} and then we can have two or more separate subhashes.
	#
	#return if %all_the_authors;

	# Path::Tiny would throw an exception if it could not open the file
	# but we for Perl::Maven this file is optional
	eval {
		my $fh = Path::Tiny::path( mymaven->{root} . '/authors.txt' );

		# TODO add row iterator interface to Path::Tiny https://github.com/dagolden/Path-Tiny/issues/107
		foreach my $line ( $fh->lines_utf8 ) {
			chomp $line;
			my ( $nick, $name, $img, $google_plus_profile ) = split /;/, $line;
			$all_the_authors{$host}{$nick} = {
				author_name                => $name,
				author_img                 => ( $img || 'white_square.png' ),
				author_google_plus_profile => $google_plus_profile,
			};
			my $personal = mymaven->{root} . "/authors/$host/$nick.txt";
			if ( -e $personal ) {
				$all_the_authors{$host}{$nick}{author_html} = Path::Tiny::path($personal)->slurp_utf8;
			}
		}
	};
	return;
}

true;

