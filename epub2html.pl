#! /usr/bin/perl -w

use strict;
use warnings;
use feature 'say';
use Getopt::Long;
use File::Copy;
use Archive::Extract;
use XML::LibXML;
use File::Slurp;
use File::Path qw(remove_tree);

my $imgmode = 0;
### If enabled (-i) :
### Retrieve images if wanted (doesn't not deal with dir/img so far)
my $options = GetOptions( 'img|i+' => \$imgmode, );

die "Please feed me with epub files !"
  unless ( $ARGV[0] =~ /\.epub$/i );

my $filename = $ARGV[0];
$filename =~ s/\.epub$/$'/i;

### Archive::Extract is an idiot...
copy( $ARGV[0], $filename . '.zip' );

my $epub = Archive::Extract->new( archive => $filename . '.zip' );

### Do not unzip files in current dir, this is messy !
mkdir 'epub'
  or die "Unable to make dir 'epub' : $!";
chdir 'epub'
  or die "Unable to change to dir 'epub' : $!";
my $current_dir = 'epub';
my $parentdir   = '../';
$epub->extract
  or warn "Unable to extract $ARGV[0] : $!";

### Well, I thought OEBPS/ was required, it isn't
### So we'll hack it quickly
my @files = read_dir('.');
my %files = map { $_ => 1 } @files;
if ( exists( $files{'OEBPS'} ) ) {
    chdir 'OEBPS'
      or die "Unable to change to OEBPS : $!";
    $current_dir = 'OEBPS';
    $parentdir   = '../../';
}

my $parser = XML::LibXML->new();
my $doc    = $parser->parse_file( glob('*.opf') );

### Required, doesn't work if xmlns:opf is not set
my $xpc = XML::LibXML::XPathContext->new($doc);
$xpc->registerNs( opf => 'http://www.idpf.org/2007/opf' );

my @htmlfiles;
my @imgfiles;

### Quick XPath requests
foreach my $item ( $xpc->findnodes('//opf:item') ) {
    if ( $item->findvalue('@media-type') eq 'application/xhtml+xml' ) {
        push( @htmlfiles, $item->findvalue('@href') );
    }
    elsif ( $item->findvalue('@media-type') =~ m/image/ ) {
        push( @imgfiles, $item->findvalue('@href') );
    }

}

##### I know I shouldn't use regexp on HTML blah blah blah
##### it does work and it is *much much* faster than what I tested otherwise

my $header = qq{
<html>
 <!-- This ugly file is automatically generated by epub2html.pl -->
 <!-- It is intend to produce a simple HTML file out of an EPUB file -->
 <!-- Basically to be read in w3m or other text-based web-browsers -->
 <!-- (which is why I don't care about img) -->
 <!-- https://github.com/SebDeclercq/scriptsOfMine/blob/master/epub2html.pl -->
<body>
};

write_file( $parentdir . $filename . '.html',
    { binmode => ':utf8', append => 1 }, $header );

for (@htmlfiles) {
    my $file = read_file( $_, { binmode => ':utf8' } );
    $file =~ s/.*<body[^>]*>//si;
    $file =~ s/(<img src=")/$1img\//i;
    $file =~ s/<\/body> *<\/html>//si;
    write_file( $parentdir . $filename . '.html',
        { binmode => ':utf8', append => 1 }, $file );
}

my $footer = q{
  </body>
</html>
};

write_file( $parentdir . $filename . '.html',
    { binmode => ':utf8', append => 1 }, $footer );

if ( $imgmode == 1 ) {
    mkdir $parentdir . 'img'
      or warn "Unable to create img directory : $!";

    for (@imgfiles) {
        copy( $_, $parentdir . 'img/' . $_ )
          or warn "Unable to copy $_ : $!";
    }
}

chdir $parentdir;
remove_tree 'epub'
  or die "Unable to delete epub directory : $!";
unlink $filename . '.zip';
