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

sub rss {
	my ($self) = @_;

	my $url = $self->{url};
	$url =~ s{/*$}{};

	# itunes specs: http://www.apple.com/itunes/podcasts/specs.html
	my $xml = '';
	$xml .= qq{<?xml version="1.0" encoding="UTF-8"?>};
	$xml .= qq{<rss xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" version="2.0">\n};
	$xml .= qq{<channel>\n};
	$xml .= qq{  <title>$self->{title}</title>\n};
	$xml .= qq{  <link>$url/</link>\n};
	$xml .= qq{  <language>$self->{language}</language>\n};
	$xml .= qq{  <copyright>$self->{copyright}</copyright>\n};
	$xml .= qq{  <description>$self->{description}</description>\n};

	$xml .= qq{  <itunes:subtitle>$self->{subtitle}</itunes:subtitle>\n};
	$xml .= qq{  <itunes:author>$self->{author}</itunes:author>\n};
	$xml .= qq{  <itunes:summary>$self->{summary}</itunes:summary>\n};
	$xml .= qq{  <itunes:owner>\n};
	$xml .= qq{    <itunes:name>$self->{itunes_name}</itunes:name>\n};
	$xml .= qq{    <itunes:email>$self->{itunes_email}</itunes:email>\n};
	$xml .= qq{  </itunes:owner>\n};
#	$xml .= qq{  <itunes:image href="http://example.com/podcasts/everything/AllAboutEverything.jpg" />};
	$xml .= qq{  <itunes:category text="Technology" />\n};

	foreach my $e (@{ $self->{entries} }) {
		$xml .= qq{  <item>\n};
		$xml .= qq{    <title>$e->{title}</title>\n};


		if ($e->{itunes}) {
			$xml .= qq{    <itunes:author>$e->{itunes}{author}</itunes:author>};
#			$xml .= qq{    <itunes:subtitle></itunes:subtitle>\n};
			$xml .= qq{    <itunes:summary>$e->{itunes}{summary}</itunes:summary>\n};
#			$xml .= qq{    <itunes:image href="http://example.com/podcasts/everything/AllAboutEverything/Episode1.jpg" />\n};
			$xml .= qq{    <enclosure url="$e->{enclosure}{url}" length="$e->{enclosure}{length}" type="$e->{enclosure}{type}" />};
			$xml .= qq{    <pubDate>$e->{update} GMT</pubDate>\n};
			$xml .= qq{    <itunes:duration>e->{itunes}{duration}</itunes:duration>\n};
		}


		$xml .= qq{  <description type="html">$e->{summary}</description>\n};
#		$xml .= qq{  <updated>$e->{updated}Z</updated>\n};
		$xml .= qq{  <guid>$e->{link}</guid>\n};
		$xml .= qq{  <link rel="alternate" type="text/html" href="$e->{link}" />};

#		$xml .= qq{  <id>$e->{id}</id>\n};
#		$xml .= qq{  <content type="html">$e->{content}</content>\n};
#		if ($e->{author}) {
#			$xml .= qq{    <author>\n};
#			$xml .= qq{      <name>$e->{author}{name}</name>\n};
#			$xml .= qq{      <email>$e->{author}{email}</email>\n};
#			$xml .= qq{    </author>\n};
#		}
		$xml .= qq{  </item>\n};
	}

	$xml .= qq{</channel>\n};
	$xml .= qq{</rss>\n};

	return $xml;
}




1;

