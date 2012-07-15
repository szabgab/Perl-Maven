package Perl::Maven;
use Dancer ':syntax';
use Perl::Maven::DB;

our $VERSION = '0.1';
my $TIMEOUT = 60*60*24*10;
my $FROM = 'Gabor Szabo <gabor@szabgab.com>';

use Business::PayPal;
use Data::Dumper qw(Dumper);
use DateTime;
use Digest::SHA;
use Email::Valid;
#use YAML qw(DumpFile LoadFile);
use MIME::Lite;
use File::Basename qw(fileparse);
use POSIX ();

use Perl::Maven::Page;

my $sandbox = 'https://www.sandbox.paypal.com/cgi-bin/webscr';
my $real_Cert = <<"CERT";
-----BEGIN CERTIFICATE-----
MIIGSzCCBTOgAwIBAgIQLjOHT2/i1B7T//819qTJGDANBgkqhkiG9w0BAQUFADCB
ujELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQL
ExZWZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTswOQYDVQQLEzJUZXJtcyBvZiB1c2Ug
YXQgaHR0cHM6Ly93d3cudmVyaXNpZ24uY29tL3JwYSAoYykwNjE0MDIGA1UEAxMr
VmVyaVNpZ24gQ2xhc3MgMyBFeHRlbmRlZCBWYWxpZGF0aW9uIFNTTCBDQTAeFw0x
MTAzMjMwMDAwMDBaFw0xMzA0MDEyMzU5NTlaMIIBDzETMBEGCysGAQQBgjc8AgED
EwJVUzEZMBcGCysGAQQBgjc8AgECEwhEZWxhd2FyZTEdMBsGA1UEDxMUUHJpdmF0
ZSBPcmdhbml6YXRpb24xEDAOBgNVBAUTBzMwMTQyNjcxCzAJBgNVBAYTAlVTMRMw
EQYDVQQRFAo5NTEzMS0yMDIxMRMwEQYDVQQIEwpDYWxpZm9ybmlhMREwDwYDVQQH
FAhTYW4gSm9zZTEWMBQGA1UECRQNMjIxMSBOIDFzdCBTdDEVMBMGA1UEChQMUGF5
UGFsLCBJbmMuMRowGAYDVQQLFBFQYXlQYWwgUHJvZHVjdGlvbjEXMBUGA1UEAxQO
d3d3LnBheXBhbC5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCd
szetUP2zRUbaN1vHuX9WV2mMq0IIVQ5NX2kpFCwBYc4vwW/CHiMr+dgs8lDduCfH
5uxhyRxKtJa6GElIIiP8qFB5HFWf1uUgoDPC1he4HaxUkowCnVEqjEowOy9R9Cr4
yyrmqmMEDccVsx4d3dOY2JF1FrLDHT7qH/GCBnyYw+nZJ88ci6HqnVJiNM+NX/D/
d7Y3r3V1bp7y1DaJwK/z/uMwNCC+lcM59w+nwAvLutgCW6WitFHMB+HpSsOSJlIZ
ydpj0Ox+javRR1FIdhRUFMK4wwcbD8PvULi1gM+sYsJIzP0mHDlhWRIDImG1zmy2
x7ZLp0HA5WayjI5aSn9fAgMBAAGjggHzMIIB7zAJBgNVHRMEAjAAMB0GA1UdDgQW
BBQxqt0MVbSO4lWE5aB52xc8nEq5RTALBgNVHQ8EBAMCBaAwQgYDVR0fBDswOTA3
oDWgM4YxaHR0cDovL0VWU2VjdXJlLWNybC52ZXJpc2lnbi5jb20vRVZTZWN1cmUy
MDA2LmNybDBEBgNVHSAEPTA7MDkGC2CGSAGG+EUBBxcGMCowKAYIKwYBBQUHAgEW
HGh0dHBzOi8vd3d3LnZlcmlzaWduLmNvbS9ycGEwHQYDVR0lBBYwFAYIKwYBBQUH
AwEGCCsGAQUFBwMCMB8GA1UdIwQYMBaAFPyKULqeuSVae1WFT5UAY4/pWGtDMHwG
CCsGAQUFBwEBBHAwbjAtBggrBgEFBQcwAYYhaHR0cDovL0VWU2VjdXJlLW9jc3Au
dmVyaXNpZ24uY29tMD0GCCsGAQUFBzAChjFodHRwOi8vRVZTZWN1cmUtYWlhLnZl
cmlzaWduLmNvbS9FVlNlY3VyZTIwMDYuY2VyMG4GCCsGAQUFBwEMBGIwYKFeoFww
WjBYMFYWCWltYWdlL2dpZjAhMB8wBwYFKw4DAhoEFEtruSiWBgy70FI4mymsSweL
IQUYMCYWJGh0dHA6Ly9sb2dvLnZlcmlzaWduLmNvbS92c2xvZ28xLmdpZjANBgkq
hkiG9w0BAQUFAAOCAQEAisdjAvky8ehg4A0J3ED6+yR0BU77cqtrLUKqzaLcLL/B
wuj8gErM8LLaWMGM/FJcoNEUgSkMI3/Qr1YXtXFvdqo3urqMhi/SsuUJU85Gnoxr
Vr0rWoBqOOnmcsVEgtYeusK0sQbxq5JlE1eq9xqYZrKuOuA/8JS1V7Ss1iFrtA5i
pwotaEK3k5NEJOQh9/Zm+fy1vZfUyyX+iVSlmyFHC4bzu2DlzZln3UzjBJeXoEfe
YjQyLpdUhUhuPslV1qs+Bmi6O+e6htDHvD05wUaRzk6vsPcEQ3EqsPbdpLgejb5p
9YDR12XLZeQjO1uiunCsJkDIf9/5Mqpu57pw8v1QNA==
-----END CERTIFICATE-----
CERT
my $real_Certcontent = <<CERTCONTENT;
Subject Name: /1.3.6.1.4.1.311.60.2.1.3=US/1.3.6.1.4.1.311.60.2.1.2=Delaware/businessCategory=Private Organization/serialNumber=3014267/C=US/postalCode=95131-2021/ST=California/L=San Jose/street=2211 N 1st St/O=PayPal, Inc./OU=PayPal Production/CN=www.paypal.com
Issuer  Name: /C=US/O=VeriSign, Inc./OU=VeriSign Trust Network/OU=Terms of use at https://www.verisign.com/rpa (c)06/CN=VeriSign Class 3 Extended Validation SSL CA
CERTCONTENT


my $Cert = <<CERT;
-----BEGIN CERTIFICATE-----
MIIGUzCCBTugAwIBAgIQQcO4g86BppQ1JLIKmUw/VDANBgkqhkiG9w0BAQUFADCB
ujELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQL
ExZWZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTswOQYDVQQLEzJUZXJtcyBvZiB1c2Ug
YXQgaHR0cHM6Ly93d3cudmVyaXNpZ24uY29tL3JwYSAoYykwNjE0MDIGA1UEAxMr
VmVyaVNpZ24gQ2xhc3MgMyBFeHRlbmRlZCBWYWxpZGF0aW9uIFNTTCBDQTAeFw0x
MTA5MDEwMDAwMDBaFw0xMzA5MzAyMzU5NTlaMIIBFzETMBEGCysGAQQBgjc8AgED
EwJVUzEZMBcGCysGAQQBgjc8AgECEwhEZWxhd2FyZTEdMBsGA1UEDxMUUHJpdmF0
ZSBPcmdhbml6YXRpb24xEDAOBgNVBAUTBzMwMTQyNjcxCzAJBgNVBAYTAlVTMRMw
EQYDVQQRFAo5NTEzMS0yMDIxMRMwEQYDVQQIEwpDYWxpZm9ybmlhMREwDwYDVQQH
FAhTYW4gSm9zZTEWMBQGA1UECRQNMjIxMSBOIDFzdCBTdDEVMBMGA1UEChQMUGF5
UGFsLCBJbmMuMRowGAYDVQQLFBFQYXlQYWwgUHJvZHVjdGlvbjEfMB0GA1UEAxQW
d3d3LnNhbmRib3gucGF5cGFsLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
AQoCggEBAOgLoTxH7wR+fQFXznItNcPuPDKQhdUIWLRvG2uMDQDeolaPF4L5Dvn5
yazgycHMjYBxinH02Sc7k69OqFDCiOiLpIpRLsVCqTZUixIHmsZP6gPMYsYm6a+C
cvpOnqYQ02XE+CIWjN92cK5BKBebtPc9us0MtcPAnuU8Pyp4l7OdLNukjDgXuxZ3
rbnKKb7Z/3kkmzQTeshNWbDLYcgUR2OiibD/lsQpcoYtlPcsXcA+R+HAaYIY3JXc
U2q7RwxCK19kSRcuxKdNNV+/RjBL3Ttbf0LLMiqjWgKpAWpRUjfu08tl7vxR6SCl
aRzoJwnQDwosBtT8I8OiZ8sldmc4btkCAwEAAaOCAfMwggHvMAkGA1UdEwQCMAAw
HQYDVR0OBBYEFE/LQp+SfkYxbltojftEGXrE7GTQMAsGA1UdDwQEAwIFoDBCBgNV
HR8EOzA5MDegNaAzhjFodHRwOi8vRVZTZWN1cmUtY3JsLnZlcmlzaWduLmNvbS9F
VlNlY3VyZTIwMDYuY3JsMEQGA1UdIAQ9MDswOQYLYIZIAYb4RQEHFwYwKjAoBggr
BgEFBQcCARYcaHR0cHM6Ly93d3cudmVyaXNpZ24uY29tL3JwYTAdBgNVHSUEFjAU
BggrBgEFBQcDAQYIKwYBBQUHAwIwHwYDVR0jBBgwFoAU/IpQup65JVp7VYVPlQBj
j+lYa0MwfAYIKwYBBQUHAQEEcDBuMC0GCCsGAQUFBzABhiFodHRwOi8vRVZTZWN1
cmUtb2NzcC52ZXJpc2lnbi5jb20wPQYIKwYBBQUHMAKGMWh0dHA6Ly9FVlNlY3Vy
ZS1haWEudmVyaXNpZ24uY29tL0VWU2VjdXJlMjAwNi5jZXIwbgYIKwYBBQUHAQwE
YjBgoV6gXDBaMFgwVhYJaW1hZ2UvZ2lmMCEwHzAHBgUrDgMCGgQUS2u5KJYGDLvQ
UjibKaxLB4shBRgwJhYkaHR0cDovL2xvZ28udmVyaXNpZ24uY29tL3ZzbG9nbzEu
Z2lmMA0GCSqGSIb3DQEBBQUAA4IBAQAoyJqVjD1/73TyA0GU8Q2hTuTWrUxCE/Cv
D7b3zgR3GXjri0V+V0/+DoczFjn/SKxi6gDWvhH7uylPMiTMPcLDlp8ulgQycxeF
YxgxgcNn37ztw4f2XV/U9N5MRJrrtj5Sr4kAzEk6jPORgh1XfklgPgb1k/mJWWZw
l1AksZwbxMp/adNq1+gyfG65cIgVMiLXYYMr+UJXwey+/e6GVcOhLdEiKmxT6u3M
lsQPBEHGmGM3WDRpCqb7lBPMXP9GkNBfF36IVOu7jzgP69prSKjICk2fPC1+ktAF
KUmGOOMrAuewXyJ8wRuRjbtPikYdApAnHjd7quQWApwUJyOCKr99
-----END CERTIFICATE-----
CERT

my $Certcontent = <<CERTCONTENT;
Subject Name: /1.3.6.1.4.1.311.60.2.1.3=US/1.3.6.1.4.1.311.60.2.1.2=Delaware/businessCategory=Private Organization/serialNumber=3014267/C=US/postalCode=95131-2021/ST=California/L=San Jose/street=2211 N 1st St/O=PayPal, Inc./OU=PayPal Production/CN=www.sandbox.paypal.com
Issuer  Name: /C=US/O=VeriSign, Inc./OU=VeriSign Trust Network/OU=Terms of use at https://www.verisign.com/rpa (c)06/CN=VeriSign Class 3 Extended Validation SSL CA
CERTCONTENT

chomp $Cert;
chomp $Certcontent;

$Business::PayPal::Cert = $Cert;
$Business::PayPal::Certcontent = $Certcontent;

my %products = (
	'perl_maven_cookbook' => {
		name  => 'Perl Maven Cookbook',
		price => 0,
	},
	'beginner_perl_maven_ebook' => {
		name  => 'Beginner Perl Maven E-book',
		price => 0.01,
	},
);

if (not config->{appdir}) {
	require Cwd;
	set appdir => Cwd::cwd;
}

my $db = Perl::Maven::DB->new( config->{appdir} . "/pm.db" );
my %authors;

hook before => sub {
	read_authors();
};

hook before_template => sub {
	my $t = shift;
	$t->{title} ||= 'Perl 5 Maven - for people who want to get the most out of programming in Perl';
	if (logged_in()) {
		($t->{username}) = split /@/, session 'email';
	}
	return;
};

get '/' => sub {
	_display('index', 'main', 'index');
};
get '/archive' => sub {
	_display('archive', 'archive', 'system');
};
get '/atom' => sub {
	my $pages;
	my $file = 'feed';
	if (open my $fh, '<', path(config->{appdir}, '..', 'articles', 'meta', "$file.json")) {
		local $/ = undef;
		my $json = <$fh>;
		$pages = from_json $json;
	}

	my $ts = DateTime->now;

	my $url = 'http://perl5maven.com';
	my $xml = '';
	$xml .= qq{<?xml version="1.0" encoding="utf-8"?>\n};
	$xml .= qq{<feed xmlns="http://www.w3.org/2005/Atom">\n};
	$xml .= qq{<link href="$url/atom" rel="self" />\n};
	$xml .= qq{<title>Perl 5 Maven</title>\n};
	$xml .= qq{<id>$url/</id>\n};
	$xml .= qq{<updated>${ts}Z</updated>\n};
	foreach my $p (@$pages) {
		$xml .= qq{<entry>\n};
		$xml .= qq{  <title>$p->{title}</title>\n};
		$xml .= qq{  <summary type="html"><![CDATA[$p->{abstract}]]></summary>\n};
		$xml .= qq{  <updated>$p->{timestamp}Z</updated>\n};
		$xml .= qq{  <link rel="alternate" type="text/html" href="$url/$p->{filename}.html" />};
		my $id = $p->{id} ? $p->{id} : "$url/$p->{filename}.html";
		$xml .= qq{  <id>$id</id>\n};
		$xml .= qq{  <content type="html"><![CDATA[$p->{abstract}]]></content>\n};
		if ($p->{author}) {
			$xml .= qq{    <author>\n};
			$xml .= qq{      <name>$authors{$p->{author}}{author_name}</name>\n};
			#$xml .= qq{      <email></email>\n};
			$xml .= qq{    </author>\n};
		}
		$xml .= qq{</entry>\n};
	}
	$xml .= qq{</feed>\n};

	content_type 'application/atom+xml';
	return $xml;
};

sub _display {
	my ($file, $template, $layout) = @_;

	my $tt;
	if (open my $fh, '<', path(config->{appdir}, '..', 'articles', 'meta', "$file.json")) {
		local $/ = undef;
		my $json = <$fh>;
		$tt->{pages} = from_json $json;
	}
	template $template, $tt, { layout => $layout };
};

post '/send-reset-pw-code' => sub {
	my $email = param('email');
	if (not $email) {
		return template 'error', { no_email => 1 };
	}
	$email = lc $email;
	my $user = $db->get_user_by_email($email);
	if (not $user) {
		return template 'error', {invalid_email => 1};
	}
	if (not $user->{verify_time}) {
		# TODO: send e-mail with verification code
		return template 'error', {not_verified_yet => 1};
	}

	my $code = _generate_code();
	$db->set_password_code($user->{email}, $code);

	my $html = template 'reset_password_mail', {
		url => uri_for('/set-password'),
		id => $user->{id},
		code => $code,
	}, {
		layout => 'email',
	};

	sendmail(
		From    => $FROM,
		To      => $email,
		Subject => 'Code to reset your Perl 5 Maven password',
		html    => $html,
	);


	template 'error', {
		reset_password_sent => 1,
	};
};

get '/set-password/:id/:code' => sub {
	my $error = pw_form();
	return $error if $error;
	template 'set_password', {
		id   => param('id'),
		code => param('code'),
	};
};

post '/set-password' => sub {
	my $error = pw_form();
	return $error if $error;

	my $password = param('password');
	my $id = param('id');
	my $user = $db->get_user_by_id($id);

	return template 'error', {
		bad_password => 1,
	} if not $password or length($password) < 6;

	session email => $user->{email};
	session logged_in => 1;
	session last_seen => time;

	$db->set_password($id, Digest::SHA::sha1_base64($password));

	template 'error', { password_set => 1 };
};

get '/login' => sub {
	template 'login';
};

post '/login' => sub {
	my $email    = param('email');
	my $password = param('password');

	return template 'error', {
		missing_data => 1,
	} if not $password or not $email;

	my $user = $db->get_user_by_email($email);
	if (not $user->{password}) {
		return template 'login', { no_password => 1 };
	}

	return template 'error', { invalid_pw => 1 }
		if $user->{password} ne Digest::SHA::sha1_base64($password);

	session email => $user->{email};
	session logged_in => 1;
	session last_seen => time;

	redirect '/account';
};

get '/unsubscribe' => sub {
	return redirect '/login' if not logged_in();

	my $email = session('email');

	$db->unsubscribe_from($email, 'perl_maven_cookbook');
	template 'error', { unsubscribed => 1 }
};

get '/subscribe' => sub {
	return redirect '/login' if not logged_in();

	my $email = session('email');
	$db->subscribe_to($email, 'perl_maven_cookbook');
	template 'error', { subscribed => 1 }
};


get '/logged-in' => sub {
	return logged_in() ? 1 : 0;
};

get '/register' => sub {
		return template 'registration_form', {
			standalone => 1,
		};
};

post '/register' => sub {
	my $email = param('email');
	if (not $email) {
		return template 'registration_form', {
			no_mail => 1,
			standalone => 1,
		};
	}
	if (not Email::Valid->address($email)) {
		return template 'registration_form', {
			invalid_mail => 1,
			standalone => 1,
		};
	}

	# check for uniqueness after lc
	$email = lc $email;

	my $user = $db->get_user_by_email($email);
	#debug Dumper $user;
	if ($user and $user->{verify_time}) {
		return template 'registration_form', {
			duplicate_mail => 1,
			standalone => 1,
		};
	}

	my $code = _generate_code();

	# basically resend the old code
	my $id;
	if ($user) {
		$code = $user->{verify_code};
		$id = $user->{id};
	} else {
		$id = $db->add_registration($email, $code);
	}

	# save  email and code (and date)
	my $html = template 'verification_mail', {
		url => uri_for('/verify'),
		id => $id,
		code => $code,
	}, {
		layout => 'email',
	};
	sendmail(
		From    => $FROM,
		To      => $email,
		Subject => 'Please finish the Perl 5 Maven registration',
		html    => $html,
	);
	return template 'response';
};

get '/logout' => sub {
	session logged_in => 0;
	redirect '/';
};

get '/account' => sub {
	return redirect '/login' if not logged_in();

	# list all the purchased products !
	my $cookbook = get_download_file('perl_maven_cookbook');
	my $email = session('email');

	template 'account', {
		filename => "/download/perl_maven_cookbook/$cookbook",
		linkname => $cookbook,
		subscribed => $db->is_subscribed($email, 'perl_maven_cookbook'),
	};
};

get '/download/:dir/:file' => sub {
	my $dir  = param('dir');
	my $file = param('file');

	# TODO better error reporting or handling when not logged in
	return redirect '/'
		if not logged_in();
	return redirect '/' if $dir ne 'perl_maven_cookbook';

	# check if the user is really subscribed to the newsletter?
	return redirect '/' if not $db->is_subscribed(session('email'), 'perl_maven_cookbook');

	send_file(path(config->{appdir}, '..', 'articles', 'download', $dir, $file), system_path => 1);
};

get '/verify/:id/:code' => sub {
	my $id = param('id');
	my $code = param('code');

	my $user = $db->get_user_by_id($id);

	if (not $user) {
		return template 'error', { invalid_uid => 1 };
	}

	if (not $user->{verify_code} or not $code or $user->{verify_code} ne $code) {
		return template 'error', { invalid_code => 1 };
	}

	if ($user->{verify_time}) {
		my $cookbook = get_download_file('perl_maven_cookbook');

		return template 'thank_you', {
			filename => "/download/perl_maven_cookbook/$cookbook",
			linkname => $cookbook,
		};
	}

	if (not $db->verify_registration($id, $code)) {
		return template 'verify_form', {
			error => 1,
		};
	}

	$db->subscribe_to($user->{email}, 'perl_maven_cookbook');

	session email => $user->{email};
	session logged_in => 1;
	session last_seen => time;

	sendmail(
		From    => $FROM,
		To      => $user->{email},
		Subject => 'Thank you for registering',
		html    => template('post_verification_mail', {
			url => uri_for('/account'),
		}, { layout => 'email', }),
#		attachments => ['/home/gabor/save/perl_maven_cookbook_v0.01.pdf'],
	);

	sendmail(
		From    => 'Perl 5 Maven <gabor@perl5maven.com>',
		To      => 'Gabor Szabo <gabor@szabgab.com>',
		Subject => 'New Perl 5 Maven newsletter registration',
		html    => "$user->{email} has registered",
	);

	my $cookbook = get_download_file('perl_maven_cookbook');

	template 'thank_you', {
		filename => "/download/perl_maven_cookbook/$cookbook",
		linkname => $cookbook,
	};
};

get '/buy' => sub {
	if (not logged_in()) {
		return template 'error', {please_log_in => 1};
		# TODO redirect back the user once logged in!!!
	}
	my $what = param('product');
	if (not $what) {
		return template 'error', {'no_product_specified' => 1};
	}
	if (not $products{$what}) {
		return template 'error', {'invalid_product_specified' => 1};
	}
	return template 'buy', {
		%{ $products{$what} },
		button => paypal_buy($what, 1),
	};
};
get '/canceled' => sub {
	debug 'get canceled ' . Dumper params();
	return template 'error', { canceled => 1};
	return 'canceled';
};
get '/paid'  => sub {
	debug 'paid ' . Dumper params();
	return template 'thank_you_buy';
};
any '/paypal'  => sub {
	my %query = params();
	debug 'paypal ' . Dumper \%query;
	my $id = param('custom');
	#my $paypal = Business::PayPal->new(id => $id);
	my $paypal = Business::PayPal->new(address => $sandbox, id => $id);
	my ($txnstatus, $reason) = $paypal->ipnvalidate(\%query);
	if (not $txnstatus) {
		log_paypal("IPN-no $reason", \%query);
		return 'ipn-transaction-failed';
	}

	my $paypal_data = from_yaml $db->get_transaction($id);
	if (not $paypal_data) {
		log_paypal('IPN-unrecognized-id', \%query);
		return 'ipn-transaction-invalid';
	}
	my $payment_status = $query{payment_status} || '';
	if ($payment_status eq 'Completed' or $payment_status eq 'Pending') {
		my $email = $paypal_data->{email};
		debug "subscribe '$email' to '$paypal_data->{what}'" . Dumper $paypal_data;
		$db->subscribe_to($email, $paypal_data->{what});
		log_paypal('IPN-ok', \%query);
		return 'ipn-ok';
	}

	log_paypal('IPN-failed', \%query);
	return 'ipn-failed';
};

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

get '/img/:file' => sub {
	my $file = param('file');
	return if $file !~ /^[\w-]+\.(\w+)$/;
	my $ext = $1;
#	return config->{appdir} . "/../articles/img/$file";
	send_file(
		config->{appdir} . "/../articles/img/$file",
#		"d:\\work\\articles\\img\\$file",
		content_type => $ext,
		system_path => 1,
	);
};

get '/mail/:article' => sub {

	my $article = param('article');

	my $path = config->{appdir} . "/../articles/mail/$article.tt";
	return 'NO path' if not -e $path;

	my $tt = read_tt($path);
	return template 'error', {'no_such_article' => 1}
		if not $tt->{status} or $tt->{status} ne 'show';

	return template 'mail', $tt, {	layout => 'email' };
};

get qr{/(.+)} => sub {
	my ($article) = splat;


	my $path = config->{appdir} . "/../articles/$article.tt";
	return template 'error', {'no_such_article' => 1} if not -e $path;

	my $tt = read_tt($path);
	return template 'error', {'no_such_article' => 1}
		if not $tt->{status} or $tt->{status} ne 'show';
	($tt->{date}) = split /T/, $tt->{timestamp};

	my $nick = $tt->{author};
	if ($nick and $authors{$nick}) {
		$tt->{author_name} = $authors{$nick}{author_name};
		$tt->{author_img} = $authors{$nick}{author_img};
		$tt->{google_plus_profile} = $authors{$nick}{google_plus_profile};
	} else {
		delete $tt->{author};
	}

	return template 'page', $tt, { layout => 'page' };
};

##########################################################################################

sub pw_form {
	my $id = param('id');
	my $code = param('code');
	# if there is such userid with such code and it has not expired yet
	# then show a form
	return template 'error', {missing_data => 1}
		if not $id or not $code;

	my $user = $db->get_user_by_id($id);
	return template 'error', {invalid_uid => 1}
		if not $user;
	return template 'error', {invalid_code => 1}
		if not $user->{password_reset_code} or
		$user->{password_reset_code} ne $code
		or not $user->{password_reset_timeout}
		or $user->{password_reset_timeout} < time;

	return;
}

sub paypal_buy {
	my ($what, $quantity) = @_;

	my $item = $products{$what}{name};
	my $usd  = $products{$what}{price};

	my $paypal = Business::PayPal->new(address => $sandbox);
#	my $paypal = Business::PayPal->new();

	# uri_for returns an URI::http object but because Business::PayPal is using CGI.pm
	# and the hidden() method of CGI.pm checks if this is a reference and then blows up.
	# so we have to forcibly stringify these values. At least for now in Business::PayPal 0.04
	my $cancel_url = uri_for('/canceled');
	my $return_url = uri_for('/paid');
	my $notify_url = uri_for('/paypal');
	my $button = $paypal->button(
		business       => 'gabor@szabgab.com',
		item_name      => $item,
		amount         => $usd,
		quantity       => $quantity,
		return         => "$return_url",
		cancel_return  => "$cancel_url",
		notify_url     => "$notify_url",
	);
	my $id = $paypal->id;
	debug $button;

	my $paypal_data = session('paypal') || {};

	my $email = logged_in() ? session('email') : '';
	my %data = (what => $what, quantity => $quantity, usd => $usd, email => $email );
	$paypal_data->{$id} = \%data; 
	session paypal => $paypal_data;
	$db->save_transaction($id, to_yaml \%data);

	log_paypal('buy_button', {id => $id, %data});

	return $button;
}

sub log_paypal {
	my ($action, $data) = @_;

	my $ts = time;
	my $logfile = config->{appdir} . '/logs/paypal_' . POSIX::strftime("%Y%m%d", gmtime($ts));
	#debug $logfile;
	if (open my $out, '>>', $logfile) {
		print $out POSIX::strftime("%Y-%m-%d", gmtime($ts)), " - $action\n";
		print $out Dumper $data;
		close $out;
	}
	return;
}


sub read_tt {
	my $file = shift;

	return Perl::Maven::Page->new(file => $file)->read;
}


sub read_file {
	my $file = shift;
	open my $fh, '<', $file or return '';
	local $/ = undef;
	return scalar <$fh>;
}



sub sendmail {
	my %args = @_;

	my $html  = delete $args{html};
	# TODO convert to text and add that too

	my $attachments = delete $args{attachments};

	my $mail = MIME::Lite->new(
		%args,
		Type    => 'multipart/mixed',
	);
	$mail->attach(
		Type => 'text/html',
		Data => $html,
	);
	foreach my $file (@$attachments) {
		my ($basename, $dir, $ext) = fileparse($file);
		$mail->attach(
			Type => "application/$ext",
			Path => $file,
			Filename => $basename,
			Disposition => 'attachment',
		);
	}
	if ($ENV{PERL_MAVEN_MAIL}) {
		if (open my $out, '>>', $ENV{PERL_MAVEN_MAIL}) {
			print $out $mail->as_string;
		} else {
			error "Could not open $ENV{PERL_MAVEN_MAIL} $!";
		}
		return;
	}

	$mail->send;
	return;
}

sub logged_in {
	if (session('logged_in') and session('email') and session('last_seen') > time - $TIMEOUT) {
		session last_seen => time;
		return 1;
	}
	return;
}

sub _generate_code {
	my @chars = ('a' .. 'z', 'A' .. 'Z', 0 .. 9);
	my $code = '';
	$code .= $chars[ rand(scalar @chars) ] for 1..20;
	return $code;
}

sub get_download_file {
	my ($subdir) = @_;

	my $dir = path config->{appdir}, '..', 'articles', 'download', $subdir;
	#debug $dir;
	my $file;
	if (opendir my $dh, $dir) {
		($file) = sort grep {$_ !~ /^\./} readdir $dh;
	} else {
		error "$dir : $!";
	}
	return $file;
}

sub read_authors {
	return if %authors;

	open my $fh, '<', config->{appdir} . "/authors.txt" or return;
	while (my $line = <$fh>) {
		chomp $line;
		my ($nick, $name, $img, $google_plus_profile) = split /;/, $line;
		$authors{$nick} = {
			author_name => $name,
			author_img  => $img,
			google_plus_profile => $google_plus_profile,
		};
	}
	return;
}


true;

