# Getting books by author (from prompt)
#  == IN RESONSE TO == 
# http://forum.ubuntu-fr.org/viewtopic.php?id=941191
#  == FILE SAMPLE ==
# Dupont, Pierre	Livre1
#  	   		Livre2
#			Livre3
# 			Livre4
# Dupond, Paul		LivreA
# 			LivreB
# 			LivreC
# 			LivreD
# Dupont, Jean		LivreA1
#      			LivreB2
#  == USAGE ==
# perl script.pl file name

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
