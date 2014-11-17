package Perl::Maven::PayPal;
use Dancer ':syntax';
use Perl::Maven::DB;
use Perl::Maven::Config;

use POSIX;
use Data::Dumper qw(Dumper);

our $VERSION = '0.11';

my $sandbox     = 0;
my $sandbox_url = 'https://www.sandbox.paypal.com/cgi-bin/webscr';

sub mymaven {
	my $mymaven = Perl::Maven::Config->new(
		path( config->{appdir}, config->{mymaven_yml} ) );
	return $mymaven->config( request->host );
}

# Start by requireing the user to be loged in first

# Plan:
# If user logged in, add purchase information to his account

# If user is not logged in
#  If the e-mail supplied by Paypal is in our database already
#     assume they are the same user and add the purchase to that account
#     and even log the user in (how?)
# If the e-mail exists but not yet verified in the system ????

# If this is a new e-mail, save the data as a new user and
# at the end of the transaction ask the user if he already
# has an account or if a new one should be created?
# If he wants to use the existing account, ask for credentials,
# after successful login merge the two accounts

# last_name
# first_name
# payer_email

get '/buy' => sub {
	if ( not Perl::Maven::logged_in() ) {
		return template 'error', { please_log_in => 1 };

		# TODO redirect back the user once logged in!!!
	}
	my $products = setting('products');
	my $what     = param('product');
	my $type     = param('type') || 'standard';
	if ( not $what ) {
		return template 'error', { 'no_product_specified' => 1 };
	}
	if ( not $products->{$what} ) {
		return template 'error', { 'invalid_product_specified' => 1 };
	}
	if ( $type eq 'annual' ) {    # TODO remove hardcoding
		$products->{$what}{price} = 90;
	}
	return template 'buy',
		{ %{ $products->{$what} }, button => paypal_buy( $what, $type, 1 ), };
};

get '/canceled' => sub {

	#debug 'get canceled ' . Dumper params();
	return template 'error', { canceled => 1 };
	return 'canceled';
};

any '/paid' => sub {

	#debug 'paid ' . Dumper params();
	return template 'thank_you_buy';
};

any '/paypal' => sub {
	my %query = params();

	#debug 'paypal ' . Dumper \%query;
	my $id = param('custom');
	my $paypal = paypal( id => $id );

	my ( $txnstatus, $reason ) = $paypal->ipnvalidate( \%query );
	if ( not $txnstatus ) {
		log_paypal( "IPN-no $reason", \%query );
		return 'ipn-transaction-failed';
	}

	my $paypal_data = from_yaml setting('db')->get_transaction($id);
	if ( not $paypal_data ) {
		log_paypal( 'IPN-unrecognized-id', \%query );
		return 'ipn-transaction-invalid';
	}
	my $payment_status = $query{payment_status} || '';
	if ( $payment_status eq 'Completed' or $payment_status eq 'Pending' ) {
		my $email = $paypal_data->{email};

  #debug "subscribe '$email' to '$paypal_data->{what}'" . Dumper $paypal_data;
		setting('db')->subscribe_to( $email, $paypal_data->{what} );
		log_paypal( 'IPN-ok', \%query );
		return 'ipn-ok';
	}

	log_paypal( 'IPN-failed', \%query );
	return 'ipn-failed';
};

###################################### subroutines:
sub paypal {
	my @params = @_;

	if ($sandbox) {
		push @params, address => $sandbox_url;
	}
	Business::PayPal->new(@params);
}

sub paypal_buy {
	my ( $what, $type, $quantity ) = @_;

	my $products = setting('products');
	my $usd      = $products->{$what}{price};

	# TODO remove special case for recurring payment
	my %params;
	if ( $what eq 'perl_maven_pro' ) {
		%params = (
			src => 1,
			cmd => '_xclick-subscriptions',

			a3 => $usd,
			p3 => 1,
			t3 => 'M',    # monthly
		);
		if ( $type eq 'annual' ) {    # TODO remove hardcoding
			$usd        = 90;
			$params{a3} = $usd;
			$params{t3} = 'Y';
		}
	}
	else {
		$params{amount} = $usd;
	}

# uri_for returns an URI::http object but because Business::PayPal is using CGI.pm
# and the hidden() method of CGI.pm checks if this is a reference and then blows up.
# so we have to forcibly stringify these values. At least for now in Business::PayPal 0.04
	my $cancel_url = uri_for('/canceled');
	my $return_url = uri_for('/paid');
	my $notify_url = uri_for('/paypal');
	my $paypal     = paypal();
	my $button     = $paypal->button(
		business      => mymaven->{paypal}{email},
		item_name     => $products->{$what}{name},
		quantity      => $quantity,
		return        => "$return_url",
		cancel_return => "$cancel_url",
		notify_url    => "$notify_url",
		%params,
	);
	my $id = $paypal->id;

	#debug $button;

	my $paypal_data = session('paypal') || {};

	my $email = Perl::Maven::logged_in() ? session('email') : '';
	my %data = (
		what     => $what,
		quantity => $quantity,
		usd      => $usd,
		email    => $email,
	);
	$paypal_data->{$id} = \%data;
	session paypal => $paypal_data;
	setting('db')->save_transaction( $id, to_yaml \%data );

	log_paypal( 'buy_button', { id => $id, %data } );

	return $button;
}

sub log_paypal {
	my ( $action, $data ) = @_;

	my $ts = time;
	my $logfile
		= config->{appdir}
		. '/logs/paypal_'
		. POSIX::strftime( '%Y%m%d', gmtime($ts) );

	#debug $logfile;
	if ( open my $out, '>>', $logfile ) {
		print $out POSIX::strftime( '%Y-%m-%d', gmtime($ts) ), " - $action\n";
		print $out Dumper $data;
		close $out;
	}
	return;
}

true;

# vim:noexpandtab
# vim:ts=4
