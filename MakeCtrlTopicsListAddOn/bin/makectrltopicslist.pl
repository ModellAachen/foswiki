#!/usr/bin/perl
# Scans a TWiki web for topics under approval control and writes report to a TWiki page.
# By Detlef Marxsen, TD&DS GmbH, Hamburg, Germany
# StartCenter: Show=0
#
# History:
# 1.01:
# Extended with second table for new topics. Added more sum info. Some formatting optimizations.
# 1.02:
# Corrected handling of topic names containing a dash. Relevance check string must be at the beginning of the line now.

use English;
use strict;

$OUTPUT_AUTOFLUSH = 1;

use vars qw($delim $reporttopicfile $version $webdir @settings %colours);

local $version = "1.02";    # Enter program version here!

local $delim;            # Path delimiter
local $reporttopicfile;  # File name of topic which contains the report
local $webdir;           # Directory of the web which shall be scanned
local @settings;         # List of setting lines (to be restored)
local %colours;          # Hash which tells the colour coding of certain strings

if ( scalar(@ARGV) < 1 ) {
    print("Mandatory parameter is missing!\n");
    exit;
}
else {
    $reporttopicfile = @ARGV[0];
    if ( $reporttopicfile =~ /\// ) {
        $delim = "/";    # This is the delimiter used by the OS
    }
    else {
        $delim = "\134";    #  This is the delimiter used by the OS
    }
    $webdir = $reporttopicfile;
    $webdir =~ s/(.*)\W\w*/$1/;    # Cut off extension
    $webdir =~
      s/(.*)\W\w*/$1/;    # Cut off remainder of topic file name to get web path
    &getsettings;
    &scandir;
    exit;
}

sub getsettings           # Get the settings
{
    my $colour;           # Colour name
    my $oneline;          # One line of the file
    my $onestatus;        # One status as mentioned in the topic
    my @status;           # Assigned status list

    open( TOPICFILE, "$reporttopicfile" )
      || die("Error: Couldn't open the report topic file for reading.");
    while ( defined( $oneline = <TOPICFILE> ) ) {
        chomp($oneline);
        if ( $oneline =~ /^\s+\*\sSet\s%CTR_(.*)/ ) {
            push( @settings, $oneline );
            $oneline = $1;
            $colour  = $oneline;
            $colour  =~ s/^(.*?)%.*/$1/;
            $oneline =~ s/.*?=(.*)/$1/;
            $oneline =~ s/\s//g;
            (@status) = split( ",", $oneline );
            foreach $onestatus (@status) {
                $colours{$onestatus} =
                  $colour;    # Assign colour to status in hash
            }
        }
    }
    close(TOPICFILE);
}

sub scandir                   # Scan the web directory
{
    my $appstat;      # Present status of the topic
    my $author;       # Author of last topic change
    my $colour;       # Colour code to insert
    my $controlled;   # 1 = Topic is under approval control
    my $endcolour;    # Colour end code to insert
    my $fname;        # File name of presently checked topic
    my $oneline;      # One line of the directory / file / list
    my $thisday;      # Human readable date
    my $thishour;     # Human readable date
    my $thisminute;   # Human readable date
    my $thismonth;    # Human readable date
    my $thisyear;     # Human readable date
    my $tobechecked;  # 1 = Topic must be checked for QM relevance
    my @filelist;     # List of topic files
    my @tim;          # Time list
    my @topicctrl;    # Table rows for each topic under control
    my @topictbc;     # Table rows for each topic to be checked for QM relevance

    opendir( DIRFILE, $webdir ) || die( "Fail: Open directory: ", $! );
    rewinddir(DIRFILE);
    while ( defined( $oneline = readdir(DIRFILE) ) ) {
        chomp($oneline);
        next if $oneline eq '.';
        next if $oneline eq '..';
        if ( $oneline =~ /\.txt$/i ) {
            (@filelist) = ( @filelist, "$webdir$delim$oneline" );
        }
    }
    close(DIRFILE);
    (@filelist) = sort(@filelist);
    foreach $fname (@filelist) {
        open( TOPICFILE, "$fname" )
          || die("Error: Couldn't open the topic file for reading.");
        $controlled  = 0;
        $tobechecked = 0;
        $appstat     = 'unknown';
        $author      = 'unknown';
        while ( defined( $oneline = <TOPICFILE> ) ) {
            if ( $oneline =~ /%META:TOPICINFO/ ) {
                chomp($oneline);
                $author = $oneline;
                $author =~ s/.*%META\:TOPICINFO.*author\="(.*?)".*/$1/;
            }
            if ( $oneline =~ /%META:APPROVAL/ ) {
                $controlled = 1;
                chomp($oneline);
                $appstat = $oneline;
                $appstat =~ s/.*%META\:APPROVAL.*state\="(.*?)".*/$1/;
            }
            if ( $oneline =~ /^###MakeCtrlTopicsList:topicmustbechecked/ ) {
                $tobechecked = 1;
            }
        }
        close(TOPICFILE);
        $fname =~ s/(.*)\..*/$1/;         # Cut off extension
        $fname =~ s/.*[\/|\\](.*)/$1/;    # Cut off path
        if ( $controlled == 1 ) {
            $endcolour = '%ENDCOLOR%';
            if ( defined( $colours{$appstat} ) ) {
                $colour = sprintf( "%%%s%%", $colours{$appstat} );
            }
            else {
                $colour = '%GRAY%';
            }
            push(
                @topicctrl,
                sprintf(
                    "|[[%s]]|%s *%s* %s|%s|",
                    $fname, $colour, $appstat, $endcolour, $author
                )
            );
        }
        if ( $tobechecked == 1 ) {
            push( @topictbc, sprintf( "|[[%s]]|%s|", $fname, $author ) );
        }
    }
    (@tim) = localtime($BASETIME);
    $thisminute = @tim[1];
    $thishour   = @tim[2];
    $thisday    = @tim[3];
    $thismonth  = @tim[4] + 1;
    $thisyear   = @tim[5] + 1900;
    open( REPORTFILE, ">$reporttopicfile" )
      || die("Error: Couldn't open the report topic file for writing.");
    print( REPORTFILE
"%META:TOPICINFO{author=\"guest\" date=\"$BASETIME\" format=\"1.0\" version=\"1.7\"}%\n"
    );
    print( REPORTFILE "%META:TOPICPARENT{name=\"WebHome\"}%\n" );
    printf( REPORTFILE "Valid for: %d-%0.2d-%0.2d %0.2d:%0.2d\n\n",
        $thisyear, $thismonth, $thisday, $thishour, $thisminute );
    printf( REPORTFILE "|Total topics in this web|  %d|\n", scalar(@filelist) );
    printf( REPORTFILE "|Topics under approval control|  %d|\n",
        scalar(@topicctrl)
    );
    printf( REPORTFILE "|Topics to be checked for QM relevance|  %d|\n\n",
        scalar(@topictbc)
    );
    print( REPORTFILE "---+Topics under approval control\n\n" );
    print( REPORTFILE "|*Topic*|*Status*|*Last change by*|\n" );

    foreach $oneline (@topicctrl) {
        print( REPORTFILE "$oneline\n" );
    }
    print( REPORTFILE "\n---+Topics to be checked for QM relevance\n\n" );
    print( REPORTFILE "|*Topic*|*Last change by*|\n" );
    foreach $oneline (@topictbc) {
        print( REPORTFILE "$oneline\n" );
    }
    print( REPORTFILE "\n-----\n\nSetup for this page:\n\n" );
    foreach $oneline (@settings)    # Restore setting lines
    {
        printf( REPORTFILE "%s\n\n", $oneline );
    }
    printf( REPORTFILE "Report routine version: %s\n", $version );
    close(REPORTFILE);
}

exit;
