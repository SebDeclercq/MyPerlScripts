#! /usr/bin/perl -w

use strict;
use warnings;

use File::Slurp;
use feature 'say';

use Facebook::Graph::Query;
use Google::Search;

### Querying Facebook Graph
my $fb = Facebook::Graph::Query->new();
# Enter FB id here
my $fbquery = "";
my $people = $fb->find($fbquery)->request->as_hashref
  or die "Not accessible for now\n";

my %people = %{$people};

### Querying Google
my $ggquery = "$people{'name'} -inurl:$people{'id'}";
my $search = Google::Search->Web( query => $ggquery );
while (my $result = $search->next) {
  my $display = $result->rank.' '.$result->uri;
  foreach ($result) {
#    say $display;
    append_file('SearchResult', $display."\n");
  }
}



