package Perl::Maven::Feed;
use strict;
use warnings;
use 5.010;

sub new {
	my ($class, %data) = @_;
	my $self = bless \%data, $class;
	$self->{path} // 'atom';
	return $self;
}


sub atom {
	my ($self) = @_;

	my $url = $self->{url};
	$url =~ s{/*$}{};

	my $xml = '';
	$xml .= qq{<?xml version="1.0" encoding="utf-8"?>\n};
	$xml .= qq{<feed xmlns="http://www.w3.org/2005/Atom">\n};
	$xml .= qq{<link href="$url/$self->{path}" rel="self" />\n};
	$xml .= qq{<title>$self->{title}</title>\n};
	$xml .= qq{<id>$url/</id>\n};
	$xml .= qq{<updated>$self->{updated}Z</updated>\n};

	foreach my $e (@{ $self->{entries} }) {
		$xml .= qq{<entry>\n};

		$xml .= qq{  <title>$e->{title}</title>\n};
		$xml .= qq{  <summary type="html">$e->{summary}</summary>\n};
		$xml .= qq{  <updated>$e->{updated}Z</updated>\n};

		$xml .= qq{  <link rel="alternate" type="text/html" href="$e->{link}" />};
		$xml .= qq{  <id>$e->{id}</id>\n};
		$xml .= qq{  <content type="html">$e->{content}</content>\n};

		if ($e->{author}) {
			$xml .= qq{    <author>\n};
			$xml .= qq{      <name>$e->{author}{name}</name>\n};
			#$xml .= qq{      <email>$e->{author}{email}</email>\n};
			$xml .= qq{    </author>\n};
		}

		$xml .= qq{</entry>\n};
	};
	$xml .= qq{</feed>\n};

	return $xml;
}



1;

