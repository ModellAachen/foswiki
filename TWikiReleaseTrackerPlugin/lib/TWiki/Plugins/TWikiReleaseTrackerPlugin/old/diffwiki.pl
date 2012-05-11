#! /usr/local/bin/perl -w
use strict;
use CGI qw/:standard/;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
warningsToBrowser(1);

my $scripturl = "http://mrjc.com/cgi-bin/diffwiki.pl";

my $showDetail = 0;
my $wiki1      = "beijingtwiki.mrjc.com";
my $wiki2      = "testwiki.mrjc.com";

chdir("../..") || die $!;
print "Content-type: text/plain\n\n";

my $query = new CGI;
$wiki1 = $query->param('wiki1') || $wiki1;
$wiki2 = $query->param('wiki2') || $wiki2;
my $file1 = $query->param('file1');
my $file2 = $query->param('file2');
$showDetail = $query->param('showDetail') || $showDetail;

if ($file1) {
    showFiles( $file1, $file2 );
}
else {
    showSwitches();
    showDirectories( $wiki1, $wiki2 );
}

#==============================================================
sub showSwitches {
    my $invertDetail = !$showDetail;
    print scriptCallback( "showDetail=$invertDetail",
        "showDetail=$showDetail" );
}

#==============================================================

sub showDirectories {
    my ( $wiki1, $wiki2 ) = @_;
    my $cmd = <<EOS;
    diff -b -q -r -u $wiki1 $wiki2 | grep -v ",v" | egrep -v "\~" | grep -v "Only in" | egrep -v ".changes|.mailnotify|debug.txt|warning.txt|/data/Know|/pub/KNow|/data/Sandbox|/pub/Sandbox/|log.*\.txt"
EOS

    #
    my @lines = `$cmd 2>&1`;
    print "| *$wiki1* | *$wiki2* | \n";
    foreach my $line (@lines) {

        #       print $line."\n";
        $line =~ m!Files (.*) and (.*) differ!;
        my ( $file1, $file2 ) = ( $1, $2 );
        print "| $file1 | $file2 | "
          . scriptCallback( "file1=$file1&file2=$file2", "diff" )
          . "<br>\n";
        diffFiles( $file1, $file2, "-b -c" ) if $showDetail;
    }
}

#==============================================================

sub scriptCallback {
    my ( $params, $label ) = @_;
    return "<A HREF=\"$scripturl?$params\">$label</A>";
}

#==============================================================

sub showFiles {
    my ( $file1, $file2 ) = @_;
    diffFiles( $file1, $file2, "-b --side-by-side --suppress-common-lines" );
    print "\n\n";
    diffFiles( $file1, $file2, "-c " );
}

#==============================================================

sub diffFiles {
    my ( $file1, $file2, $fileDiffParams ) = @_;
    my $cmd = "diff $fileDiffParams $file1 $file2";
    my $ans = $cmd . "\n\n";
    $ans .= `$cmd 2>&1`;
    print "<pre>\n" . escapeHTML($ans) . "</pre>";
}

