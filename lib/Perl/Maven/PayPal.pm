package Perl::Maven::PayPal;
use Dancer2 appname => 'Perl::Maven';
use Perl::Maven::DB;
use Perl::Maven::Config;
use Perl::Maven::WebTools qw(logged_in pm_error pm_message);
use Perl::Maven::Sendmail qw(send_mail);

use POSIX;
use Data::Dumper qw(Dumper);
use LWP::UserAgent;
use Business::PayPal;

our $VERSION = '0.11';

my $sandbox     = 0;
my $sandbox_url = 'https://www.sandbox.paypal.com/cgi-bin/webscr';

sub mymaven {
	my $mymaven = Perl::Maven::Config->new( path( config->{appdir}, config->{mymaven_yml} ) );
	return $mymaven->config( request->host );
}

get '/buy' => sub {
	if ( not logged_in() ) {
		session url => request->path;
		return pm_message('please_log_in');
	}
	my $products = setting('products');
	my $what     = param('product');
	my $type     = param('type') || 'standard';
	if ( not $what ) {
		return pm_error('no_product_specified');
	}
	if ( not $products->{$what} ) {
		return pm_error('invalid_product_specified');
	}
	if ( $type eq 'annual' ) {    # TODO remove hardcoding
		$products->{$what}{price} = 90;
	}
	return template 'buy', { %{ $products->{$what} }, button => paypal_buy( $what, $type, 1 ), };
};

get '/canceled' => sub {
	return pm_message('canceled');
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

	my $header = {
		From    => mymaven->{from},
		To      => mymaven->{admin}{email},
		Subject => 'PayPal  IPN received',
	};

	my $body    = '';
	my $content = request->body;
	log_paypal( 'IPN content', { body => $content } );
	$body .= "<h2>IPN content</h2>\n";
	$body .= "<pre>\n$content\n</pre>\n";

	my $id     = param('custom');
	my $paypal = paypal( id => $id );

	my ( $txnstatus, $reason ) = $paypal->ipnvalidate( \%query );
	if ( not $txnstatus ) {

		# This probably means someone other than PayPal has accessed the /paypal URL
		# We want to log this an maybe look into it.
		# for this we probably want to log the IP of the client that sent this request
		# maybe even send an e-mail alert?
		# TODO we should report this

		log_paypal( "IPN - could not verify - $reason", \%query );
		$body .= "<h2>IPN - could not verify</h2>\n";
		$body .= "<pre>\n";
		$body .= $reason;
		$body .= "\n</pre>\n";
		$body .= "<pre>\n";
		$body .= Dumper \%query;
		$body .= "\n</pre>\n";

		send_mail( $header, { html => $body } );

		# Let's disregard this validation for now
		#return '';
	}

	my $paypal_data = from_yaml setting('db')->get_transaction($id);
	if ( not $paypal_data ) {

		# PayPal sent us some message related to a request - they claim we sent -
		# but we cannot find that request. Do they make the mistake?
		# Has somene else sent them the request on our behalf?
		# Have we lost the request?
		# TODO we should report this
		log_paypal( 'IPN-unrecognized-id', \%query );
		$body .= "<h2>IPN-unrecognized-id</h2>\n";
		$body .= "<pre>\n";
		$body .= Dumper \%query;
		$body .= "\n</pre>\n";
		send_mail( $header, { html => $body } );
		return '';
	}
	my $payment_status = $query{payment_status} || '';

	# When allowing for "one month free", there won't be a payment_status at all
	# there won't be a txn_id either (transaction id)
	#if ( $payment_status eq 'Completed' or $payment_status eq 'Pending' ) {
	my $uid = $paypal_data->{uid};

	my %params = (
		uid  => $uid,
		code => $paypal_data->{what}
	);
	log_paypal( 'subscribe_to', \%params );
	$body .= "<h2>subscribe_to</h2>\n";
	$body .= "<pre>\n";
	$body .= Dumper \%params;
	$body .= "\n</pre>\n";
	eval { setting('db')->subscribe_to(%params); };

	if ($@) {
		my $err = $@;
		log_paypal( 'exception', { ex => $err } );
		$body .= "<h2>exception</h2>\n";
		$body .= "<pre>\n";
		$body .= $err;
		$body .= "\n</pre>\n";
	}
	log_paypal( 'IPN-ok', \%query );
	$body .= "<h2>IPN-ok</h2>\n";
	$body .= "<b>txn_type</b>=$query{txn_type}<br>\n";
	$body .= "<b>payer</b>=$query{first_name} $query{last_name} &lt;$query{payer_email}&gt;<br>\n";
	$body .= "<b>payment_gross</b>=$query{payment_gross}<br>\n";
	$body .= "<pre>\n";
	$body .= Dumper \%query;
	$body .= "\n</pre>\n";
	send_mail( $header, { html => $body } );
	return '';

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
	my ( $what, $type, $quantity, $button_text ) = @_;

	my $products = setting('products');
	my $usd      = $products->{$what}{price};

	# TODO remove special case for recurring payment
	my %params;
	if ( $what eq 'code_maven_pro' ) {
		%params = (
			src => 1,
			cmd => '_xclick-subscriptions',

			a3 => $usd,
			p3 => 1,
			t3 => 'M',    # monthly
		);
		$button_text = qq{$usd USD per month};

		my $trial = mymaven->{trial};
			if ( $type eq 'trial' and $trial ) {
			$params{a1} = $trial->{a1};
			$params{p1} = $trial->{p1};
			$params{t1} = 'M';
		}

		#if ( $type eq 'trial' ) {
		#	$params{p1} = 1;
		#	$params{t1} = 'M';

		#	#$button_text = qq{1 USD for the first month and then $usd USD per month};
		#	#$button_text = qq{1 USD for the first month};
		#	$button_text = q{Sign me up to the Perl Maven Pro for $1!};
		#}

		#if ( $type eq 'annual-1' ) {    # TODO remove hardcoding
		#	$params{a1}  = 1;
		#	$params{p1}  = 1;
		#	$params{t1}  = 'M';
		#	$usd         = 90;
		#	$params{a3}  = $usd;
		#	$params{t3}  = 'Y';                     # yearly
		#	$button_text = qq{$usd USD per year};
		#}
		if ( $type eq 'annual' ) {    # TODO remove hardcoding
									  #$params{a1} = 60;
									  #$params{p1} = 1;
									  #$params{t1} = 'Y';
			$usd         = 90;
			$params{a3}  = $usd;
			$params{t3}  = 'Y';                     # yearly
			$button_text = qq{$usd USD per year};
		}
	}
	else {
		$params{amount} = $usd;
	}
	$button_text ||= 'Buy';

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

		#button_image  => qq{<button type="button" class="btn btn-success">$button_text</button>},
		button_image =>
			qq{<input type="submit" class="btn btn-success" value="$button_text" id="paypal_submit_button" />},
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

	my $uid  = logged_in() ? session('uid') : '';
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

	my $ts      = time;
	my $logfile = config->{appdir} . '/logs/paypal_' . POSIX::strftime( '%Y%m%d', gmtime($ts) );

	#debug $logfile;
	if ( open my $out, '>>', $logfile ) {
		print $out POSIX::strftime( '%Y-%m-%d', gmtime($ts) ), " - $action\n";
		print $out Dumper $data;
		close $out;
	}
	return;
}

true;

