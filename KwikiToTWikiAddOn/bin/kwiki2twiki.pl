#!/usr/bin/perl -w
#
# Kwiki to Twiki text converter
#
# Copyright (c) 2003 Fred Morris, m3047 at inwa d0t net
#
# Acknowledgements:
#    Thanks to http://www.graysoft.com/ for giving me
#    permission to distribute this.
#
# Adapted from:
#
# Dolphin to TWiki text converter
#
# Copyright (C) 2001 Peter Thoeny, peter@thoeny.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#

use lib ('.');
use lib ('../lib');

# these variables will be set by TWiki.cfg:
$revCiDateCmd    = "";
$defaultUserName = "";

# read the configuration part
do "TWiki.cfg";

# Not quite, appears some things have changed in Twiki.cfg since
# Thoeny wrote the original proggie. -- FWM

%settingsHash = @storeSettings;
$revCiDateCmd = $settingsHash{ciDateCmd};

# On with the show..

$inDir  = "";
$outDir = "";

if (@ARGV) {
    $inDir  = $ARGV[0] if $ARGV[0];
    $outDir = $ARGV[1] if $ARGV[1];
    $inDir  = "" unless -d $inDir;
    $outDir = "" unless -d $outDir;
}

&main();

sub main {
    print
"Kwiki to TWiki text converter. Copyright (C) 2003, Fred Morris, m3047 at inwa d0t net\n";
    print
"                               Copyright (C) 2001, Peter Thoeny, http://TWiki.org/\n";
    if ( !$inDir || !$outDir ) {
        print "example% kwiki2twiki fromDir toDir\n";
        print "fromDir:   Directory containing Kwiki text files\n";
        print
"toDir:     Directory where converted .txt and .txt,v files are stored\n";
        print
"Attention: toDir is assumed to be empty. Existing files will be overwritten!\n";
        return;
    }
    if ( $inDir eq $outDir ) {
        print "Error: toDir and fromDir must be different!\n";
        return;
    }

    opendir( DIR, "$inDir" ) or die "could not open $inDir";
    my @inList = grep /^\w/, readdir DIR;
    closedir DIR;
    my $text = "";
    my $time = 0;
    foreach (@inList) {
        print "- $_: read";
        $text = readFile("$inDir/$_");
        print ", convert";
        ( $text, $time ) = convertText($text);

        $outf = "$outDir/$_" . '.txt';

        print ", save";
        saveFile( $outf, $text );
        print ", archive";
        ciFile( $outf, $time );
        print "\n";
    }
}

# =========================
sub convertText {
    my ($theText) = @_;
    my $text =
        '%META:TOPICINFO{author="'
      . $defaultUserName
      . '" date="'
      . time
      . '" format="1.0" version="1.1"}%' . "\n";
    my $time     = 0;
    my $verbatim = 0;
    $theText =~ s/\r//gos;
    foreach ( split( /\n/, $theText ) ) {

        # in a verbatim block
        if ($verbatim) {

            if (m/^ /o) {

                $text .= "$_\n";
                next;
            }
            else {

                $text .= "</verbatim>\n";
                $verbatim = 0;
            }
        }

        # start a verbatim block
        if (m/^ /o) {

            $text .= "<verbatim>\n$_\n";
            $verbatim = 1;

            next;
        }

        # = Head 		--> ---+ Head
        if (m/^(=+)\s+(.*)/o) {

            my $indent = $1;
            my $header = $2;

            $indent =~ s/=/+/go;
            $header =~ s/=+$//o;
            $_ = "---$indent $header";
        }

        # [=code]		--> =code=
        s/\[=(.*?)]/=$1=/go;

        # [Name URL]		--> [[URL][Name]]
        s/\[\s*(.*)\s+(http.*)\s*]/[[$2][$1]]/go;

        # /*bolditalic*/ 	--> __bolditalic__
        s/(^|\s)\/\*(\S.*?\S)\*\/(\W|$)/$1__$2__$3/go;

        # /italic/ 		--> _italic_
        s/(^|\s)\/(\S.*?\S)\/(\W|$)/$1_$2_$3/go;

        # &			--> &amp;
        s/&/&amp;/go;

        # <			--> &lt;
        s/</&lt;/gi;

        # >			--> &gt;
        s/>/&gt;/gi;

        # !WikiWord		--> <nop>WikiWord
        s/!([A-Z]\S+)/<nop>$1/go;

        # * list		-->   * list
        if (m/^([*]+)\s*(.*)/go) {

            my $indent = $1;
            my $item   = $2;

            $indent =~ s/./\t/go;

            $_ = $indent . '* ' . $item;
        }

        # 0 list		-->   1 list
        if (m/^([0-9]+)\s*(.*)/go) {

            my $indent = $1;
            my $item   = $2;

            $indent =~ s/./\t/go;

            $_ = $indent . '1 ' . $item;
        }

        $text .= "$_\n";
    }

    $text =~ s/\n\n+/\n\n/gos;
    return ( $text, $time );
}

# =========================
sub readFile {
    my ($theName) = @_;
    my $data = "";
    undef $/;    # set to read to EOF
    open( IN_FILE, "<$theName" ) || return "";
    $data = <IN_FILE>;
    $/    = "\n";
    close(IN_FILE);
    return $data;
}

# =========================
sub saveFile {
    my ( $theName, $theText ) = @_;
    open( FILE, ">$theName" ) or warn "Can't create file $theName";
    print FILE $theText;
    close(FILE);
}

# =========================
sub ciFile {
    my ( $theName, $theTime ) = @_;
    my @arr = gmtime($theTime);

    # format to RCS date "2000/12/31/23:59:59"
    my $date = sprintf(
        "%.4u/%.2u/%.2u/%.2u:%.2u:%.2u",
        $arr[5] + 1900,
        $arr[4] + 1,
        $arr[3], $arr[2], $arr[1], $arr[0]
    );
    my $cmd = $revCiDateCmd;
    $cmd =~ s/%USERNAME%/$defaultUserName/;
    $cmd =~ s/%FILENAME%/$theName/;
    $cmd =~ s/%DATE%/$date/;

    #   print "\n   $cmd\n";
    #   my $rcsError = `$cmd`;
    my $rcsError = `$cmd 2>&1 1>/dev/null`;
    if ($rcsError) {
        print " $rcsError";

        #        print " $rcsError\n";
    }
}
