# usage : perl script.pl file nom
open FILE, $ARGV[0] or die $!;
my $query = lc($ARGV[-1]);
for (<FILE>) {
  push(@lines,split("\n",$_));
}
for (@lines) {
  if (m/^[^\s]/) {
    $author = (split("\t",$_))[0];
    $book = (split("\t",$_))[1];
    $bbg{$author} = "\n\t".$book;
  }else {
    $book = $' if m/^\s+/;
    $bbg{$author} .= ";\n\t".$book;
  }
}
foreach (keys %bbg) {
  print $_.' : '.$bbg{$_}."\n" if m/$query/i;
}
