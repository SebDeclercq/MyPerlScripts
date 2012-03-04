#! /usr/bin/perl -w

use strict;
use warnings;
use Tie::File;
use LWP::UserAgent;
use feature qw ( say );

# Collect New Emails from GMail
my ($user,$password) = ('FOO','BAR');
my $ua = LWP::UserAgent->new;
my $req = HTTP::Headers->new;
$req = HTTP::Request->new(GET => 'https://mail.google.com/mail/feed/atom');
$req->authorization_basic($user,$password);
my $response = $ua->request($req);

# Getting New IP value from server
my @response = split ("\n",$response->content);
my @newips;
foreach my $line (@response) {
  if ($line =~ m/^<summary>New IP is : (?<ip>\d+(\.\d+){3})/) {
    push (@newips,$+{ip});
  }
}
my $newip = $newips[0]; # Case of multiple unread emails with server alerts

# Change IP value to .bashrc : updating link to SSH server

tie my @file, 'Tie::File', "$ENV{HOME}/.bashrc"
  or die "can't open file : $!\n";
foreach (@file) {
  s/(alias sshserver=[^\d]+)(\d+(\.\d+){3})/$1$newip/;
}
untie @file;
