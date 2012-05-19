package Perl::Maven::DB;
use strict;
use warnings;

use DBI;

my $instance;

sub new {
  my ($class, $dbfile) = @_;

  return $instance if $instance;

  my $dsn = "dbi:SQLite:dbname=$dbfile";
  my $dbh = DBI->connect($dsn, "", "", {
     RaiseError => 1,
	 PrintError => 0,
	 AutoCommit => 1,
  });

  $instance = bless {
    dbh => $dbh,
  }, $class;

  return $instance;
}

sub add_registration {
  my ($self, $email, $code) = @_;

  $self->{dbh}->do('INSERT INTO user (email, verify_code, register_time)
     VALUES (?, ?, ?)',
    undef,
	$email, $code, time);
  my $id = $self->{dbh}->last_insert_id('', '', '', '');

  return $id;
}

sub get_user_by_email {
  my ($self, $email) = @_;

  my $hr = $self->{dbh}->selectrow_hashref('SELECT * FROM user WHERE email=?',
    undef, $email);

  return $hr;
}
sub get_user_by_id {
  my ($self, $id) = @_;

  my $hr = $self->{dbh}->selectrow_hashref('SELECT * FROM user WHERE id=?',
    undef, $id);

  return $hr;
}

sub verify_registration {
  my ($self, $id, $code) = @_;

  $self->{dbh}->do('UPDATE user SET verify_time=? WHERE id=?',
    undef, time, $id);
}

sub set_password_code {
	my ($self, $email, $code) = @_;
	$self->{dbh}->do('UPDATE user
		SET password_reset_code=?, password_reset_timeout=?
		WHERE email=?',
		undef, $code, time+60*60, $email);
}


1;
