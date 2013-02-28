#!/usr/bin/perl
use warnings;
use strict;

use Getopt::Long;
use Log::Log4perl qw(:easy);
use File::Find::Rule;
use Digest::SHA1;
use File::Slurp;
use Cwd 'abs_path';

my $dir = '.';
my $out = 'deduplicated';
my $no;
my $only;
my $format = 'json';
my $pretty;
my $make = 'links';

my $options = GetOptions(
    'dir|d=s'    => \$dir,
    'no=s'       => \$no,
    'only=s'     => \$only,
    'pretty|p'   => \$pretty,
    'out|o=s'    => \$out,
    'format|f=s' => \$format,
    'make|m=s'   => \$make,
    'help|h'     => \&help,
);

my $logger;
log4perl();

verifyOptions();

chdir $dir    #Useless if $dir = '.' but still
  and mkdir $out;

my $ffr;      #File::Find::Rule
if ( defined($no) ) {
    my $pattern = join( '|', split( ',', $no ) );
    $ffr = File::Find::Rule->file()->not_name(qr{$pattern$}i)->start('.');
    $logger->info(
        "\$ffr = File::Find::Rule->file()->not_name(qr{$pattern$}i)->start('.')"
    );
}
elsif ( defined($only) ) {
    my $pattern = join( '|', split( ',', $only ) );
    $ffr = File::Find::Rule->file()->name(qr{$pattern$}i)->start('.');
    $logger->info(
        "\$ffr = File::Find::Rule->file()->name(qr{$pattern$}i)->start('.')");
}
else {
    $ffr = File::Find::Rule->file()->start('.');
    $logger->info("\$ffr = File::File::Rule->file()->start('.')");
}

my %sha1sums;
while ( my $mfile = $ffr->match ) {
    sha1sum($mfile);
}

if ( $make =~ m/l(inks?)/i ) {
    $logger->info("Option : LINKS");
    makeLinks();
}
else {
    $logger->info("Option : COPIES");
    makeCopies();
}

my %statistics;
statistics();

for my $outformat ( split( ',', $format ) ) {
    if ( $outformat eq 'json' ) {
        eval "use JSON::XS";
        my ( $jsoncontent, $statistics );
        if ( defined($pretty) ) {
            $jsoncontent = JSON::XS->new->pretty->encode( \%sha1sums );
            $statistics  = JSON::XS->new->pretty->encode( \%statistics );
        }
        else {
            $jsoncontent = JSON::XS->new->encode( \%sha1sums );
            $statistics  = JSON::XS->new->encode( \%statistics );
        }
        my $jsonfile = $out . '.json';
        write_file( $jsonfile, \$statistics )
          and append_file( $jsonfile, $jsoncontent )
          and $logger->info("JSON file processed ($jsonfile)")
          or $logger->warn("Unable to process JSON file ($jsonfile) : $!");
    }
    elsif ( $outformat eq 'xml' ) {
        eval "use XML::Writer";
        eval "use IO::File";

        my $xmlfile = $out . '.xml';
        my $output  = IO::File->new(">$xmlfile");
        my $xml;

        if ( defined($pretty) ) {
            $xml = XML::Writer->new(
                OUTPUT      => $output,
                DATA_MODE   => 1,
                DATA_INDENT => 4,
            );
        }
        else {
            $xml = XML::Writer->new( OUTPUT => $output, );
        }

        $xml->startTag('FileDeduplicated');

        $xml->startTag('statistics');
        for my $key ( sort keys %statistics ) {
            $xml->startTag($key);
            $xml->characters( $statistics{$key} );
            $xml->endTag($key);
        }
        $xml->endTag('statistics');

        for my $key ( sort keys %sha1sums ) {
            $xml->startTag( 'file', 'sha1sum' => $key, );

            for ( @{ $sha1sums{$key} } ) {
                $xml->startTag('path');
                $xml->characters($_);
                $xml->endTag('path');
            }
            $xml->endTag('file');
        }
        $xml->endTag('FileDeduplicated');
        $xml->end();

        $output->close() and $logger->info("XML file processed ($xmlfile)")
          or $logger->warn("Unable to process XML file ($xmlfile) : $!");
    }
    else {
        eval "use Spreadsheet::WriteExcel";
        my $workbook = Spreadsheet::WriteExcel->new( $out . '.xls' )
          and $logger->info("Excel file $out.xls created")
          or $logger->warn("Unable to create new Excel file ($out.xls) : $!");

        my $worksheet = $workbook->add_worksheet();
        $worksheet->set_column( 1, 0, 30 );
        $worksheet->set_column( 2, 0, 18 );
        $worksheet->set_column( 3, 0, 45 );
        $worksheet->hide_gridlines(1);
        $worksheet->set_landscape();

        my $fhead = $workbook->add_format(
            bold     => 1,
            bg_color => 'yellow',
            valign   => 'vcenter',
            align    => 'center',
        );
        my $ffilename = $workbook->add_format( italic => 1, );
        my $fsha1 = $workbook->add_format(
            font   => 'Courrier New',
            align  => 'center',
            valign => 'center',
        );
        my $ftitle = $workbook->add_format( bold => 1, );

        my $linenumber = 1;
        $worksheet->merge_range( "B$linenumber:C$linenumber", 'Statistics',
            $fhead );
        $linenumber += 2;
        $worksheet->write( "B$linenumber", "Total files", $ftitle );
        $worksheet->write( "C$linenumber", $statistics{'tot_files'} );
        $linenumber++;
        $worksheet->write( "B$linenumber", "Total directories", $ftitle );
        $worksheet->write( "C$linenumber", $statistics{'tot_dirs'} );
        $linenumber++;
        $worksheet->write( "C$linenumber", '~' . $statistics{'files_by_dir'} );
        $linenumber++;
        $worksheet->write( "B$linenumber", "Number of different files",
            $ftitle );
        $worksheet->write( "C$linenumber", $statistics{'tot_diff_files'} );
        $worksheet->write( "D$linenumber",
            ' (' . $statistics{'pc_diff_files'} . ')' );
        $linenumber++;
        $worksheet->write( "B$linenumber", "Number of (useless) copies",
            $ftitle );
        $worksheet->write( "C$linenumber", $statistics{'tot_useless_copies'} );
        $worksheet->write( "D$linenumber",
            ' (' . $statistics{'pc_useless_copies'} . ')' );
        $linenumber++;
        $worksheet->write( "B$linenumber", "Number of unique files", $ftitle );
        $worksheet->write( "C$linenumber", $statistics{'tot_uniq_files'} );
        $worksheet->write( "D$linenumber",
            ' (' . $statistics{'pc_uniq_files'} . ')' );
        $linenumber++;
        $worksheet->write( "B$linenumber", "Number of double files", $ftitle );
        $worksheet->write( "C$linenumber", $statistics{'tot_doub_files'} );
        $worksheet->write( "D$linenumber",
            ' (' . $statistics{'pc_doub_files'} . ')' );
        $linenumber += 3;

        for my $key ( sort keys %sha1sums ) {
            if ( scalar @{ $sha1sums{$key} } > 1 ) {
                $worksheet->merge_range( "A$linenumber:B$linenumber",
                    'These files are identical', $fhead );
                $linenumber += 2;

                for ( @{ $sha1sums{$key} } ) {
                    $worksheet->write_url( "B$linenumber", 'external:' . $_ );
                    $linenumber++;
                }
                $linenumber++;
                $worksheet->write( "C$linenumber", 'Common SHA1 :', $ftitle );
                $worksheet->write( "D$linenumber", $key,            $fsha1 );
                $linenumber++;

                $worksheet->write( "C$linenumber", 'Link to directory :',
                    $ftitle );
                if ( $make =~ m/l(inks?)/i ) {
                    $worksheet->write_url( "D$linenumber",
                        'external:' . $out . '/' . substr( $key, 34 ) );
                }
                else {
                    my $ext = $1 if @{ $sha1sums{$key} }[0] =~ /(\.[^\.]+)$/;
                    $worksheet->write_url( "D$linenumber",
                        'external:' . $out . '/' . substr( $key, 34 ) . $ext );
                }
                $linenumber += 2;

            }
        }
        $workbook->close();
    }
}

### SUBROUTINES

sub verifyOptions {

    unless ( $make =~ m/l(inks?)?|c(op(ies|y))?/i ) {
        print "Unknown option $make for -make :
Options are :\tL/links  C/Copies
Proceed with default option (links) ?\n";
        chomp( my $answer = <STDIN> );
        if ( $answer =~ m/y(es)?|^$/i ) {
            $make = 'links';
        }
        else { $logger->warn("-make : No Option chosen...") and die; }
    }

    unless ( $format =~ m/xml|json|xls/i ) {
        print "Unknown option $format for -format:
Options are :\txml  json  xls(excel)
Proceed with default option (json) ?\n";
        chomp( my $answer = <STDIN> );
        if ( $answer =~ m/y(es)?|^$/i ) {
            $format = 'json';
        }
        else { $logger->warn("-format : No Option chosen...") and die; }
    }

    if ( defined($no) && defined($only) ) {
        print "Unable to proceed :
Choose files to include or to exclude but not both...\n";
        $logger->warn("-only and -no activated at the same time") and die;
    }
}

sub sha1sum {
    my $file = shift;
    my $fh;
    unless ( open $fh, $file ) {
        $logger->warn("Unable to open $file : $!");
        next;
    }

    my $sha1 = Digest::SHA1->new;
    $sha1->addfile($fh);
    unshift( @{ $sha1sums{ $sha1->hexdigest } }, $file );

    close $fh;

    $logger->info("$file has been treated");
}

sub makeLinks {
    for my $key ( sort keys %sha1sums ) {
        if ( $^O eq 'MSWin32' ) {
            eval "use Win32::Shortcut";
            my $link = Win32::Shortcut->new();
            $link->{'Path'} = abs_path( @{ $sha1sums{$key} }[0] );
            $link->Save( $out . '/' . substr( $key, 34 ) . '.lnk' )
              and $logger->info(
                "Link \"" . substr( $key, 34 ) . "\" has been created" )
              or $logger->warn( "Link for \""
                  . substr( $key, 34 )
                  . "\" cannot be created : $!" );
        }
        elsif ( $^O eq 'linux' ) {
            symlink(
                '../' . @{ $sha1sums{$key} }[0],
                $out . '/' . substr( $key, 34 )
              )
              and $logger->info(
                "Link \"" . substr( $key, 34 ) . "\" has been created" )
              or $logger->warn(
                "Link \"" . substr( $key, 34 ) . "\" cannot be created : $!" );
        }
        else {
            print "OS $^O not (yet) supported for shortcuts...\n"
              and $logger->warn("OS $^O not supported...");
        }
    }
}

sub makeCopies {
    eval "use File::Copy";
    for my $key ( sort keys %sha1sums ) {

        my $filepath = @{ $sha1sums{$key} }[0];
        my $filename = $out . '/' . substr( $key, 34 );
        my $ext      = $1 if $filepath =~ /(\.[^\.]+)$/;
        $filename .= $ext if defined($ext);

        copy( $filepath, $filename )
          and $logger->info("File \"$filename\" copied")
          or $logger->warn("Copying \"$filename\" failed : $!");
    }

}

sub statistics {
    my $ffr2 = File::Find::Rule->directory()->start('.');
    while ( my $mdir = $ffr2->match ) {
        $statistics{'tot_dirs'}++;
    }

    for my $key ( sort keys %sha1sums ) {
        $statistics{'tot_diff_files'}++;
        $statistics{'tot_files'} += scalar @{ $sha1sums{$key} };
        if ( scalar @{ $sha1sums{$key} } == 1 ) {
            $statistics{'tot_uniq_files'}++;
        }
        else {
            $statistics{'tot_doub_files'} += scalar @{ $sha1sums{$key} };
            $statistics{'tot_useless_copies'} +=
              scalar @{ $sha1sums{$key} } - 1;
        }
    }

    $statistics{'files_by_dir'} = sprintf "%3d files by directory",
      $statistics{'tot_files'} / $statistics{'tot_dirs'};
    $statistics{'pc_diff_files'} = sprintf "%3.2f%%",
      $statistics{'tot_diff_files'} / $statistics{'tot_files'} * 100;
    $statistics{'pc_uniq_files'} = sprintf "%3.2f%%",
      $statistics{'tot_uniq_files'} / $statistics{'tot_files'} * 100;
    $statistics{'pc_doub_files'} = sprintf "%3.2f%%",
      $statistics{'tot_doub_files'} / $statistics{'tot_files'} * 100;
    $statistics{'pc_useless_copies'} = sprintf "%3.2f%%",
      $statistics{'tot_useless_copies'} / $statistics{'tot_files'} * 100;
}

sub log4perl {
    Log::Log4perl->easy_init( $WARN, $INFO );

    my $logfile = $dir . '/deduplicated.log';

    my $appender = Log::Log4perl::Appender->new(
        "Log::Dispatch::File",
        filename => $logfile,
        mode     => "append",
    );

    $logger = get_logger();
    $logger->add_appender($appender);

    my $layout =
      Log::Log4perl::Layout::PatternLayout->new("%d %p> %F{1}:%L %M - %m%n");

    $appender->layout($layout);
}

sub help {
    system("perldoc $0");
    exit;

}

__END__

=head1 NAME

deduplicate :  Lite script to deduplicate files

=head1 SYNOPSIS

B<deduplicate> [OPTIONS] [B<-d>] SOURCE [B<-o>] DESTINATION

=head1 DESCRIPTION

This script walks through the filesystem and calculates SHA1SUM for each file.

It offers many output formats and is supported on GNU/Linux OS and MS Windows.

=head2 OPTIONS

B<-d>, B<--dir>  F<directory>

    Input directory : relative and absolute paths are supported

B<-o>, B<--out> name (default is (C<deduplicated>))

    Name for output directory and output files


B<-m>, B<--make> [l]inks [c]opies

    Makes links (shortcuts) to the unique files in the ouput directory (lighter) or copies them (heavier)

B<--only> extension I<OR> extensionB<,>extension[,...]

    Deduplicates only files with selected extension(s).
    Multiple extensions available : comma-separated

B<--no> extension I<OR> extensionB<,>extension[,...]

    Deduplicates all files unless those with selected extension(s).
    Multiple extensions available : comma-separated

B<-f>, B<--format> json xml xls I<OR> json,xml[,...]

    Output formats for list of deduplicated files
    Available formats are : json, xml, xls (MS Excel)
    Multiple extensions available : comma-separated

B<-p>, B<--pretty>

   Prettier render for output (indentation for json and xml files)

=head1 Perl Modules

=head2 Required

This script needs the following Perl modules to run

=over

=item B<Getopt::Long>       by Johan Vromans

=item B<Log::Log4perl>      by Michael Schilli

=item B<File::Find::Rule>   by Richard Clamp

=item B<Digest::SHA1>       by Gisle Aas

=item B<File::Slurp>        by Uri Guttman

=back

=head2 Optional

=over 

=item B<JSON::XS>                 I<[if]> --format json

=item B<XML::Writer>              I<[if]> --format xml

=item B<Spreadsheet::WriteExcel>  I<[if]> --format xls

=item B<Win32::Shortcut>          I<[if]> running under B<Windows> and --make [l]inks

=item B<File::Copy>               I<[if]> --make [c]opies

=back

=head1 License

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 Author

Sebastien Declercq <declercq_sebastien@yahoo.fr>

=cut
