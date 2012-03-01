#! /usr/bin/perl -w
use strict;
use warnings;
use LWP::Simple;
use File::Slurp;
# REQUIRES sendemail to work
# ( sudo apt-get install sendemail )

my ($ipFile,$oldIP) = ("dyndnscheck",0);
chomp($oldIP = read_file($ipFile)) if -e $ipFile;


my $link = get("http://checkip.dyndns.org")
  or die "can't fetch url : $!\n";
my $currIP = $& if $link =~ /\d+(\.\d+){3}/;


unless ($oldIP eq $currIP) {
  my ($email,$password,$smtp) =   # Defining personal information here ;
  my ($title,$message) = ('IP has changed !',"New IP is : $currIP\n");

  !system 'sendemail','-m', $message,'-f', $email,'-t', $email ,
    '-u', $title ,'-s', $smtp ,'-o', 'tls=yes','-xu', $email, '-xp', $password
      or die "can't use sendemail...";

  write_file($ipFile,$currIP);
}
