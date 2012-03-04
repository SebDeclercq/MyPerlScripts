#! /usr/bin/perl -w
use strict;
use warnings;
use IO::Handle;
use LWP::Simple;
use File::Slurp;
use Email::Send;
use Email::Simple::Creator;

open ERROR, '>>', 'error.log' or die "unable to open : $!";
STDERR->fdopen( \*ERROR, 'w') or die "unable to redirect : $!";

my ($ipFile,$oldIP) = ("ipcheck",0);
chomp($oldIP = read_file($ipFile)) if -e $ipFile;


my $link = get("http://checkip.dyndns.org")
  or die "can't fetch url : $!\n";
my $currIP = $& if $link =~ /\d+(\.\d+){3}/;


unless ($oldIP eq $currIP) {
  &sendmail;
  write_file($ipFile,$currIP);
}



close (ERROR);

sub sendmail {
  my ($from,$password) =   ("FOO","BAR");
  my ($to,$title,$message) = ($from,'IP has changed !',"New IP is : $currIP\n"); # Changing $to if needed

  my $mailer = Email::Send->new( {
        mailer => 'SMTP::TLS',
        mailer_args => [
            Host => 'smtp.gmail.com',
            Port => 587,
            User => $from,
            Password => $password,
        ]
    } );
  my $email = Email::Simple->create(
        header => [
            From    => $from,
            To      => $to,
            Subject => $title,
        ],
        body => $message,
    );

    eval { $mailer->send($email) };
    die "Error sending email: $@" if $@;
}