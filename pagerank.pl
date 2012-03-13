#!/usr/bin/env perl
#@ Perso, je préfère le shebang ci-dessus au traditionnel « #!/usr/bin/perl -w »
#@ Je me suis permis de passer un petit coup de perltidy ;-)

use strict;
use warnings;
use Google::Search;
use WWW::Google::PageRank;
use feature qq/say/;
use Getopt::Long;

#@ Pour améliorer l'algo d'affichage, je me suis permis de créer un nouveau
#@ paramètre ; le nom de variable est clairement pas terrible mais cela
#@ permet de décrire le nombre de pages à afficher
my ( $kw, $type, $results ) = ( 'ufr+idist', 'web', 9 );
GetOptions(
    'keyword|kw=s' => \$kw,
    'type|t=s'     => \$type,
    'result=i'     => \$results
);

#@ j'ai viré le chomp car il ne servait à rien, Getopt::Long permet de
#@ gérer ce genre de choses
$type = lc($type);

#@ changement de structure de données, voir getresults()
my %results;

getresults($type);

#@ Modification de l'algo d'affichage pour tenir compte du changement
#@ de structure de données dans getresults()
my $j = 1;
foreach my $uri ( keys %results ) {
    my $pr = WWW::Google::PageRank->new;
    say "The PageRank of "
      . $results{$uri}
      . "\n(result n°"
      . $j++
      . ") is :\t"
      . $pr->get($uri)
      if defined( $pr->get($uri) );
}

sub getresults {
    #@ Perso, j'utiliserais un autre algo que s'assurer que l'on n'interroge
    #@ que des éléments prévus par Google::Search. Un truc à base d'eval(),
    #@ mais bon, cela fonctionne et c'est un design classique dans les scripts
    if ( $_[0] =~ m/(web|blog|news)/ ) {
        my $type   = $_[0];
        my $search = Google::Search->$type($kw);

        #@ J'ai viré la boucle for. Elle était inutile. L'idée d'un compteur
        #@ était la bonne solution, mais la boucle n'est pas la bonne
        #@ implémentation
        #@ -----------------------------------------------------------------
        #@ J'ai également modifié la condition du while() ; ce n'est pas
        #@ strictement nécessaire mais je trouve que c'est plus lisible et
        #@ plus maintenable
        #@ -----------------------------------------------------------------
        #@ La structure de données la plus indiquées pour gérer ce genre de
        #@ correspondances est plutôt un hash ; enfin, opinion personnelle
        #@ hein :-)
        while ( my $result = $search->next ) {
            last unless $results--;
            $results{ $result->uri } = $result->titleNoFormatting;
        }
    }
    else {
        say "Unsupported type of search : choose web, blog or news";
    }
}

#@ un petit « C-x h M-x flush-lines #@ » dans emacs te permettra de nettoyer
#@ le script de mes commentaires
