#! /usr/bin/perl -w

use strict;
use warnings;
use IO::Handle;
use LWP::Simple;
use File::Slurp;
use Email::Send;
use Email::Simple::Creator;

# LIGHT DyDNS with Perl and GMail
# Checking SSH Server IP in order to commit
# changes on Client (debian).
# Automation with crontab, 3 times a day :
# 0 8,16,24 * * perl /path/to/ipcheck-SERVER.pl

open ERROR, '>>', 'error.log' or die "unable to open : $!";      # Opening log file
STDERR->fdopen( \*ERROR, 'w') or die "unable to redirect : $!";  # Redirect SDTERR to log file

my ($ipFile,$oldIP) = ("ipcheck",0);                             # Recover old IP value *if exists*
chomp($oldIP = read_file($ipFile)) if -e $ipFile;


my $link = get("http://checkip.dyndns.org")                      # Get current IP
  or die "can't fetch url : $!\n";
my $currIP = $& if $link =~ /\d+(\.\d+){3}/;


unless ($oldIP eq $currIP) {
  &sendmail;
  write_file($ipFile,$currIP);                                   # Append current IP to IPfile
  &loginfo('changes');
} else {&loginfo('nochanges')}



close (ERROR);

sub sendmail {   # Sending email via GMail
  my ($from,$password) =   ('FOO','BAR');
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
sub loginfo {   # Keeping trace of changes and controls
  if ($_[0] eq 'changes') {
    my $newline = "--- ".localtime()." ---\t".$currIP."\n";
    append_file('error.log',$newline);
  }
  elsif ($_[0] eq 'nochanges') {
    my $newline = "--- ".localtime()." ---\tNo Changes\n";
    append_file('error.log',$newline);
  }
}
