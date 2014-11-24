package Perl::Maven::PayPal;
use Dancer ':syntax';
use Perl::Maven::DB;
use Perl::Maven::Config;
use Perl::Maven::WebTools qw(logged_in);

use POSIX;
use Data::Dumper qw(Dumper);
use LWP::UserAgent;

our $VERSION = '0.11';

my $sandbox     = 0;
my $sandbox_url = 'https://www.sandbox.paypal.com/cgi-bin/webscr';

sub mymaven {
	my $mymaven = Perl::Maven::Config->new(
		path( config->{appdir}, config->{mymaven_yml} ) );
	return $mymaven->config( request->host );
}

=pod

=head2 If the user is already logged in to Perl Maven

When viewing a page (eg. /pro ) we have a button that will lead to the /buy url.
When user arrives to the /buy URL shows the paypal button and saves a unique value for this potential
transaction.

When we get an IPN message we need to check what kind of message is that.

Product types
1) One-time payment
   paied -> enable
   Refund payment -> disable

2) Subscription:
     payment arrives on date covering a period => enable and set expiration date on the product
     cancelled => does not need to do anything, the exparation date will take care of it
     refund => disable
     'Payment Skipped' ??
3) Subscription with some free period
     When the user signs up to the service, we enable and set an expiration date
     cancelled => we can either cancel the subscription or we can let it expire
     The rest is the same as in 2)
4) Giving free subscription to someone
    Set an expiration date
    Be also able to allow 'no expiration date'

On a regular base we run a script that checks for expired services and removes them from the user.
If someone tries to sign up to a service that was expired we can let the user do this.
I think the only loophole might be people signing up to free subscription, cancelling it and then signing up again.
This is not a big issue for us, but we could save a flag that says, 'this user has already had a free period'
and then not let the free signup. I don't think this is worth the effort now.

Daily cron job that will check all the subscriptions and send e-mail to the ones that will be charged in the next 24 hours.
(or some other time period)
It will also remove subscriptions that have expired a while ago. (e.g. a week ago)





=head2 If the user is not logged in

or now we require the user to be logged in when starting the transaction,
ut later we should implement a version when the user can start withot being logged in.
hen the question will be: shall we create a new account with the e-mail received from PayPal
  or shall we look for the account of the user.
If the e-mail supplied by Paypal is in our database already
   assume they are the same user and add the purchase to that account
   and even log the user in (how?)
If the e-mail exists but not yet verified in the system ????
If this is a new e-mail, save the data as a new user and
at the end of the transaction ask the user if he already
has an account or if a new one should be created?
If the user wants to use the existing account, ask for credentials,
after successful login merge the two accounts

=cut

get '/buy' => sub {
	if ( not logged_in() ) {
		return template 'error', { please_log_in => 1 };
		session url => request->path;
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
	return template 'error', { canceled => 1 };
	return 'canceled';
};

any '/paid' => sub {
	return template 'thank_you_buy';
};

# IPN listener: https://developer.paypal.com/webapps/developer/docs/classic/ipn/integration-guide/IPNImplementation/
# https://developer.paypal.com/webapps/developer/applications/ipn_simulator
# resend old IPNs from IPN history: https://www.paypal.com/il/cgi-bin/webscr?cmd=_display-ipns-history&nav=0%2e3%2e4
any '/paypal' => sub {
	my %query = params();

	my $content = request->body;
	log_paypal( 'IPN content', { body => $content } );

	my $id = param('custom');
	my $paypal = paypal( id => $id );

	my ( $txnstatus, $reason ) = $paypal->ipnvalidate( \%query );
	if ( not $txnstatus ) {

# This probably means someone other than PayPal has accessed the /paypal URL
# We want to log this an maybe look into it.
# for this we probably want to log the IP of the client that sent this request
# maybe even send an e-mail alert?
# TODO we should report this

		log_paypal( "IPN - could not verify - $reason", \%query );
		return '';
	}

	my $paypal_data = from_yaml setting('db')->get_transaction($id);
	if ( not $paypal_data ) {

	 # PayPal sent us some message related to a request - they claim we sent -
	 # but we cannot find that request. Do they make the mistake?
	 # Has somene else sent them the request on our behalf?
	 # Have we lost the request?
	 # TODO we should report this
		log_paypal( 'IPN-unrecognized-id', \%query );
		return '';
	}
	my $payment_status = $query{payment_status} || '';

  # When allowing for "one month free", there won't be a payment_status at all
  # there won't be a txn_id either (transaction id)
  #if ( $payment_status eq 'Completed' or $payment_status eq 'Pending' ) {
	my $uid = $paypal_data->{id};

	my %params = (
		uid  => $uid,
		code => $paypal_data->{what}
	);
	log_paypal( 'subscribe_to', \%params );
	eval { setting('db')->subscribe_to(%params); };
	if ($@) {
		log_paypal( 'exception', { ex => $@ } );
	}
	log_paypal( 'IPN-ok', \%query );
	return '';

	#}

	#log_paypal( 'IPN-failed', \%query );
	#return '';
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
		if ( $type eq 'trial' ) {
			$params{a1} = 0;
			$params{p1} = 1;
			$params{t1} = 'M';
		}
		if ( $type eq 'annual' ) {    # TODO remove hardcoding
			$usd        = 90;
			$params{a3} = $usd;
			$params{t3} = 'Y';        # yearly
		}
	}
	else {
		$params{amount} = $usd;
	}

# https://www.paypal.com/en/cgi-bin/webscr?cmd=_pdn_subscr_techview_outside
# https://developer.paypal.com/docs/classic/paypal-payments-standard/integration-guide/Appx_websitestandard_htmlvariables/
# a3 = amount to billed each recurrence
# p3 = number of time periods between each recurrence
# t3 = time period (D=days, W=weeks, M=months, Y=years)

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

	my $uid = logged_in() ? session('uid') : '';
	my %data = (
		what     => $what,
		quantity => $quantity,
		usd      => $usd,
		uid      => $uid,
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

