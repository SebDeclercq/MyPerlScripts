#! /usr/bin/perl -w

use strict;
use warnings;
use Google::Search;
use WWW::Google::PageRank;
use feature qq/say/;
use Getopt::Long;

my ($kw,$type) = ('ufr+idist','web');
GetOptions('keyword|kw=s'  => \$kw,
	   'type|t=s'      => \$type);
chomp($kw,$type);
$type = lc($type);
my (@uris,@results);

getresults($type);

my $j = 1;
foreach my $uri (@uris) {
  my $pr = WWW::Google::PageRank->new;
  say "The PageRank of $results[$j]\n(result n°$j) is :\t".
    $pr->get($uri) if defined($pr->get($uri));
  $j++;
}




sub getresults {
  if ($_[0] =~ m/(web|blog|news)/) {
    my $type = $_[0];
    my $search = Google::Search->$type( $kw );
    for ( my $i = 0 ; $i < 9 ; $i++ ) {
      while (my $result = $search->result($i)) {
	push (@uris,$result->uri);
	push (@results,$result->titleNoFormatting);
	last;
      }
    }
  } else {
    say "Unsupported type of search : choose web, blog or news";
  }
}
