use strict;
use warnings;

use DBI;
use Data::Dumper;
use DateTime::Tiny;
use lib 'lib';
use Perl::Maven::DB;
use boolean;

my $db = Perl::Maven::DB->new;

my $dsn = 'dbi:SQLite:dbname=pm.db';
my $dbh = DBI->connect(
	$dsn, '', '',
	{
		RaiseError       => 1,
		PrintError       => 0,
		AutoCommit       => 1,
		FetchHashKeyName => 'NAME_lc',
	}
);

add_users();
add_products();
add_subscriptions();
add_transactions();

exit;

sub add_users {
	my %whitelist;
	my $sth_w = $dbh->prepare('SELECT * FROM login_whitelist WHERE uid=?');
	$sth_w->execute;
	while ( my $h = $sth_w->fetchrow_hashref ) {
		delete $h->{id};
		push @{ $whitelist{ $h->{uid} } }, $h;
	}

	my $sth = $dbh->prepare('SELECT * FROM user');
	$sth->execute;
	while ( my $h = $sth->fetchrow_hashref ) {

		#print Dumper $h;
		if ( delete $h->{admin} ) {
			$h->{admin} = boolean::true;
		}
		if ( delete $h->{login_whitelist} ) {
			$h->{whitelist_enabled} = boolean::true;
		}
		if ( not defined $h->{name} ) {
			delete $h->{name};
		}
		if ( not defined $h->{password} ) {
			delete $h->{password};
		}
		delete $h->{verify_code};
		delete $h->{password_reset_code};
		delete $h->{password_reset_timeout};
		$h->{subscriptions} = [];
		foreach my $f (qw(register_time verify_time)) {
			my $t = delete $h->{$f};
			if ($t) {
				my @time = gmtime($t);
				$h->{$f} = DateTime::Tiny->new(
					year   => $time[5] + 1900,
					month  => $time[4],
					day    => $time[3],
					hour   => $time[2],
					minute => $time[1],
					second => $time[0],
				);
			}
		}
		if ( $whitelist{ $h->{id} } ) {
			$h->{whitelist} = $whitelist{ $h->{id} };
		}

		#print Dumper $h;
		$db->{db}->get_collection('user')->insert($h);
	}
}

sub add_products {
	my $sth = $dbh->prepare('SELECT * FROM product');
	$sth->execute;
	while ( my $h = $sth->fetchrow_hashref ) {
		$db->{db}->get_collection('products')->insert($h);
	}
}

sub add_subscriptions {
	my %product;
	foreach my $p ( $db->{db}->get_collection('products')->find->all ) {
		$product{ $p->{id} } = $p->{code};
	}

	#die Dumper \%product;

	my $sth = $dbh->prepare('SELECT * FROM subscription');
	$sth->execute;
	while ( my $h = $sth->fetchrow_hashref ) {
		$db->{db}->get_collection('user')
			->update( { id => $h->{uid} }, { '$push', => { subscriptions => $product{ $h->{pid} } } } );
	}
}

sub add_transactions {
	my $sth = $dbh->prepare('SELECT * FROM transactions');
	$sth->execute;
	while ( my $h = $sth->fetchrow_hashref ) {
		my $t = delete $h->{ts};
		if ($t) {
			my @time = gmtime($t);
			$h->{ts} = DateTime::Tiny->new(
				year   => $time[5] + 1900,
				month  => $time[4],
				day    => $time[3],
				hour   => $time[2],
				minute => $time[1],
				second => $time[0],
			);
		}
		$db->{db}->get_collection('transactions')->insert($h);
	}
}

sub add_verification {
	my $sth = $dbh->prepare('SELECT * FROM verification');
	$sth->execute;
	while ( my $h = $sth->fetchrow_hashref ) {
		my $user = $db->{db}->get_collection('user')->find_one( { id => $h->{uid} } );
		die if not $user;
		$h->{uid} = $user->{_id};

		my $t = delete $h->{timestamp};
		if ($t) {
			my @time = gmtime($t);
			$h->{timestamp} = DateTime::Tiny->new(
				year   => $time[5] + 1900,
				month  => $time[4],
				day    => $time[3],
				hour   => $time[2],
				minute => $time[1],
				second => $time[0],
			);
		}
		$db->{db}->get_collection('transactions')->insert($h);
	}

}

