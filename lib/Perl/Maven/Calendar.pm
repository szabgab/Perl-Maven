package Perl::Maven::Calendar;
use strict;
use warnings;

use Data::ICal               ();
use Data::ICal::Entry::Event ();
use DateTime                 ();
use DateTime::Format::ICal   ();
use DateTime::Duration       ();
use Cpanel::JSON::XS qw(encode_json decode_json);
use Path::Tiny qw(path);

sub create_calendar {
	my ($filepath) = @_;

	my $calendar = Data::ICal->new;
	my $now      = DateTime->now;

	my $events = decode_json( path($filepath)->slurp_utf8 );
	for my $event (@$events) {
		my $ical_event = Data::ICal::Entry::Event->new;
		my $begin      = DateTime->new( $event->{begin} );
		my $duration   = DateTime::Duration->new( $event->{duration} );
		$ical_event->add_properties(
			summary         => $event->{summary},
			description     => $event->{description},
			dtstart         => DateTime::Format::ICal->format_datetime($begin),
			location        => $event->{location},
			url             => $event->{url},
			duration        => DateTime::Format::ICal->format_duration($duration),
			'last-modified' => DateTime::Format::ICal->format_datetime($now),
		);
		$calendar->add_entry($ical_event);
	}

	return $calendar->as_string;
}

1;
