#!/usr/bin/perl -w

use strict;
use warnings;

use Getopt::Long;
use File::Slurp;
use LWP::Simple;

use Data::Dump qw(dump);
use JSON;
use XML::XML2JSON;

my $url = '';
my $file = '';
my $output = './getlinks-result';
my $ext = 'js';

GetOptions('url|u=s' => \$url,
	   'file|f=s' => \$file,
	   'output|o=s' => \$output,
	   'ext|e=s' => \$ext
	  );

my %goodElements = ('links' => {});

my ($mailnum,$urlnum) = (0,0);

if ($url) {
  my $geturl = get($url)
    or die "Can't retrieve $url :\n$!\n";
  my @lines = split("\n",$geturl);

  foreach $_ (@lines) {
    while ($_ =~ m/\b(mailto:)?([-\w_\.]+@[^\.]+\.[a-zA-Z]{2,3})\b/g) {
      $goodElements{links}{"mails"}{"mail$mailnum"} = $2;
      $mailnum++;
    }
    while ($_ =~ m!
  		    \b([a-zA-Z]+://(w{3}\.)?[-\w_\.]+?(\.[a-zA-Z]{2,3})+
  		      (((/?[-\w_\.]+/?)+)?([-\w_\.]+\.\w+)?(\?.=[^\s]+)?))\b
  		  !gx) {
      $goodElements{links}{"urls"}{"url$urlnum"} = $1;
      $urlnum++;
    }
  }
}
if ($file) {
  my @lines = read_file($file);
  foreach $_ (@lines) {
    while ($_ =~ m/\b(mailto:)?([-\w_\.]+@[^\.]+\.[a-zA-Z]{2,3})\b/g) {
      $goodElements{links}{"mails"}{"mail$mailnum"} = $2;
      $mailnum++;
    }
    while ($_ =~ m!
		    \b([a-zA-Z]+://(w{3}\.)?[-\w_\.]+?(\.[a-zA-Z]{2,3})+
		      (((/?[-\w_\.]+/?)+)?([-\w_\.]+\.\w+)?(\?.=[^\s]+)?))\b
		  !gx) {
      $goodElements{links}{"urls"}{"url$urlnum"} = $1;
      $urlnum++;
    }
  }
}
my $encjson = to_json (\%goodElements,{latin1 => 1,pretty => 1});
if ($ext eq 'xml') {
  my $xml2json = XML::XML2JSON->new();
  my $xml = $xml2json->json2xml($encjson);
  write_file ($output.'.xml', $xml);
} else {
  write_file ($output.'.js', $encjson);
}


#dump(from_json($encjson));
