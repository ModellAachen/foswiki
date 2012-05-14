# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004-2006 Peter Thoeny, peter@thoeny.org
#
# For licensing info read LICENSE file in the distribution root.
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
# As per the GPL, removal of this notice is prohibited.

package Foswiki::Plugins::GlobalReplacePlugin;

use strict;

our $VERSION = '$Rev$';
our $RELEASE = $VERSION;
our $SHORTDESCRIPTION =
  "Global search and replace functionality across all topics in a web";
our $NO_PREFS_IN_TOPIC = 1;

our $debug = 0;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    Foswiki::Func::registerTagHandler( 'GLOBALREPLACE', \&handleGlobalReplace );

    return 1;
}

# =========================
sub handleGlobalReplace {
    my ( $session, $params, $topic, $web ) = @_;

    # parameter func can be: search, replace
    my $func = $params->{func}
      || return "%RED%Invalid page access.%ENDCOLOR% Please go to "
      . "GlobalSearchAndReplace to start your operation.";
    my $param = $params->{param} || "";    # topic name
    my $replaceSearchString = handleDecode( $params->{rSearchString} ) || "";
    my $replaceString       = handleDecode( $params->{rString} )       || "";
    my $caseSensitive       = $params->{caseSensitive}                 || "yes";

    #saved for Rob Hoffman's regular expression flag
    #$token = quotemeta( $token ) unless( $theRegex );

    my $text      = "";
    my $aWeb      = "";
    my $aTopic    = "";
    my $topicText = "";

    # Only certain people can commit a global search and replace
    # untaint $user to get rid of the Insecure Dependency

    my $access = Foswiki::Func::isGroupMember( $Foswiki::cfg{SuperAdminGroup} );

    if ( $func =~ /check/i ) {
        return "installed";

    }
    elsif ( $func =~ /search/i && $param =~ /(.*)\.(.*)/ ) {
        $aWeb   = $1 || '';
        $aTopic = $2 || '';
        return "| [[$param][$aTopic]] | %RED% No =Replace Search String= "
          . " entered. %ENDCOLOR% ||\n"
          unless ($replaceSearchString);

        my $before = "";
        my $after  = "";

        return
          "| [[$param][$aTopic]] | %RED% Topic does not exist %ENDCOLOR% ||\n"
          unless ( Foswiki::Func::topicExists( $aWeb, $aTopic ) );
        $topicText = Foswiki::Func::readTopicText( $aWeb, $aTopic );

        my $count = 0;
        my $hit;
        my $replace;
        my $position = 0;
        my $lasPos   = 0;
        my $first    = "";
        my $second   = "";
        my $third    = "";
        my $fourth   = "";

        # save a copy so that the capture can be reset for each match
        my $orgReplaceString = $replaceString;
        my $lastPos;

        while (1) {

            # reseting variables that allow the user to capture
            $first         = "";
            $second        = "";
            $third         = "";
            $fourth        = "";
            $replaceString = $orgReplaceString;

            # Make sure to grab a little before and after the hit
            # Try to grab the whole word instead of breaking it.

            if ( $caseSensitive =~ /yes/i ) {
                last
                  unless $topicText =~
m/((?:^|\s|[a-zA-Z0-9\.]*).{0,40}?)($replaceSearchString)(.{0,40}[a-zA-Z0-9\.]*)/gs;
                $before = $1;
                $hit    = $2;
                $first  = $3 || "";
                $second = $4 || "";
                $third  = $5 || "";
                $fourth = $6 || "";
                $after  = $+;
            }
            else {
                last
                  unless $topicText =~
m/((?:^|\s|[a-zA-Z0-9\.]*).{0,40}?)($replaceSearchString)(.{0,40}[a-zA-Z0-9\.]*)/gis;
                $before = $1;
                $hit    = $2;
                $first  = $3 || "";
                $second = $4 || "";
                $third  = $5 || "";
                $fourth = $6 || "";
                $after  = $+;
            }

            $replaceString =~ s/\$1/$first/gos;
            $replaceString =~ s/\$2/$second/gos;
            $replaceString =~ s/\$3/$third/gos;
            $replaceString =~ s/\$4/$fourth/gos;
            $replaceString =~ s/\$topic/$topic/gos;

    # reposition cursor in case there is a hit in the after
    # In resulting hits in after, will not have much in the leading before text.
            $lastPos = $position;
            $position = ( pos $topicText ) - ( length $after );

            last if ( $lastPos == $position );

            pos $topicText = $position;

          # Encode with %(H|R)COLOR% Tags to highlight the hits and replace text
            $hit     = "$before%HCOLOR%$hit%ENDCOLOR%$after";
            $hit     = escapeSpecialChars($hit);
            $replace = "$before%RCOLOR%$replaceString%ENDCOLOR%$after";
            $replace = escapeSpecialChars($replace);

            $text .=
                "|  <input type=\"checkbox\" name=\"SEARCH_" . "$aWeb" . "_"
              . $aTopic . "_"
              . ++$count . "\">";
            $text .= "  | <tt>$hit</tt> " . " | <tt>$replace</tt> |\n";

        }

        my $temp = "";
        $temp = "<font size=\"-1\">- $count hits</font>" if ( $count > 1 );

        my ( $lock, $tmp1, $tmp2 ) =
          &Foswiki::Func::checkTopicEditLock( $aWeb, $aTopic );
        $tmp1 = "";
        $tmp2 = "";    # suppress warnings
        if ($lock) {
            $lock = "%RED%(LOCKED)%ENDCOLOR%";
        }
        else {
            $lock = "";
        }

        $text = "| [[$param][$aTopic]] $temp $lock |||\n" . $text if ($text);

    }
    elsif ( $func =~ /replace/i ) {

        return
            "You are currently logged in as "
          . Foswiki::Func::userToWikiName( $session->{user} )
          . ". %RED%Only Members of the Main."
          . $Foswiki::cfg{SuperAdminGroup}
          . " may save the changes "
          . "of a Global Search And Replace. %ENDCOLOR%"
          unless ($access);

        return "%RED% No =Replace Search String= "
          . " entered %ENDCOLOR% Back to GlobalSearchAndReplace.\n"
          unless ($replaceSearchString);

        # reactivation tabs, carriage returns and newlines
        # for some reason, somewhere in the processing it became a string rather
        # what the \t, \n, \r should represent
        $replaceString =~ s/\\t/chr(9)/eg;     # tab
        $replaceString =~ s/\\n/chr(10)/eg;    # new line
        $replaceString =~ s/\\r/chr(13)/eg;    # carriage return

        # getting checkbox parameters
        my $cgi = &Foswiki::Func::getCgiQuery();
        if ( !$cgi ) {
            return "";
        }

        # parsing checkbox parameters
        my @topicList = map { s/^SEARCH_//o; $_ }
          grep { /^SEARCH/ } $cgi->param;

        # maintaining a list of unique topic names
        my %topicHash = map { m/(.*?)_(.*)_.*/; "$1.$2" => 1 } @topicList;

        my $count    = 0;   # counter for the number of replacements possible
        my $replaced = 0;   # counter for the number of actual replacements done
        my $displayTopicText = "";
        foreach my $key ( sort keys %topicHash ) {
            $key =~ /(.*)\.(.*)/;
            $aWeb   = $1;
            $aTopic = $2;

            $topicText = &Foswiki::Func::readTopicText( $aWeb, $aTopic );

            # reset counters
            $count    = 1;
            $replaced = 0;
            if ( $caseSensitive =~ /yes/i ) {
                $topicText =~ s/($replaceSearchString)/
                  doReplace( $1, $2, $3, $4, $5,
                             $replaceString,
                             \$count, \@topicList,
                             $aTopic, \$replaced )/geos;

            }
            else {
                $topicText =~ s/($replaceSearchString)/
                  doReplace( $1, $2, $3, $4, $5,
                             $replaceString,
                             \$count, \@topicList,
                             $aTopic, \$replaced )/igeos;
            }
            $displayTopicText = escapeSpecialChars($topicText);
            $text .= "| [[$key][$aTopic]] | $replaced";
            $text .= "<br />DEBUG MESSAGE:<br /><tt>$displayTopicText</tt>"
              if $debug;
            $text .= " |\n";

            # Save changes to text here
            &Foswiki::Func::writeDebug("GlobalReplacePlugin::saving")
              if ($debug);
            Foswiki::Func::saveTopicText( $aWeb, $aTopic, $topicText );
        }
        if ($text) {
            $text = "| *Topic* | *Number of Replacements* |\n" . $text;
        }
        else {
            $text = "No Replacements done. Back to GlobalSearchAndReplace, "
              . "GlobalReplacePlugin";
        }
    }

    return $text;
}

# =========================
sub doReplace {
    my (
        $hit,     $first, $second,    $third, $fourth,
        $replace, $count, $topicList, $topic, $replaced
    ) = @_;

    my ($flag) = grep { /.*\_$topic\_$$count/ } @$topicList;
    &Foswiki::Func::writeDebug(
            "- GlobalReplacePlugin::doReplace($hit, $replace, " 
          . $$count
          . ", $topic, $flag, )" )
      if $debug;
    $first  = "" unless ($first);
    $second = "" unless ($second);
    $third  = "" unless ($third);
    $fourth = "" unless ($fourth);

    $replace =~ s/\$1/$first/gos;
    $replace =~ s/\$2/$second/gos;
    $replace =~ s/\$3/$third/gos;
    $replace =~ s/\$4/$fourth/gos;
    $replace =~ s/\$topic/$topic/gos;

    ++$$count;
    if ($flag) {
        ++$$replaced;
        return $replace;
    }
    else {
        return $hit;
    }

    # should not get to here

    return $hit;
}

# =========================
sub escapeSpecialChars {
    my ($string) = @_;

    $string =~ s/\&/&amp;/go;
    $string =~ s/\</&lt;/go;
    $string =~ s/\>/&gt;/go;
    $string =~ s/\=/&#61;/go;
    $string =~ s/\_/&#95;/go;

    # Highlight the hit and replace strings w/ color
    $string =~ s/\%HCOLOR\%/<font color=\"#FF0000\"><b>/go;
    $string =~ s/\%RCOLOR\%/<font color=\"#FF6600\"><b>/go;
    $string =~ s/\%ENDCOLOR\%/<\/b><\/font>/go;
    $string =~ s/\%/&#37;/go;
    $string =~ s/\*/&#42;/go;
    $string =~ s/\:/&#58;/go;
    $string =~ s/\\/&#92;/go;
    $string =~ s/\[/&#91;/go;
    $string =~ s/\]/&#93;/go;
    $string =~ s/\|/&#124;/go;
    $string =~ s/([\s\(])([A-Z])/$1<nop>$2/go;    # defuse WikiWord links
    $string =~ s/\t/        /go;
    $string =~ s/  /&nbsp; /go;
    $string =~ s/[\n\r]+/<br \/>/gos;

    return $string;
}

# =========================
sub handleDecode {
    my ($theStr) = @_;
    $theStr ||= '';

    # entity decode - Cairo: &#34;, Dakar: &#034;
    $theStr =~ s/\&\#34;/\"/g;
    $theStr =~ s/\&\#034;/\"/g;
    $theStr =~ s/\&\#37;/\%/g;
    $theStr =~ s/\&\#037;/\%/g;
    $theStr =~ s/\&\#38;/\&/g;
    $theStr =~ s/\&\#038;/\&/g;
    $theStr =~ s/\&\#39;/\'/g;
    $theStr =~ s/\&\#039;/\'/g;
    $theStr =~ s/\&\#42;/\*/g;
    $theStr =~ s/\&\#042;/\*/g;
    $theStr =~ s/\&\#60;/\</g;
    $theStr =~ s/\&\#060;/\</g;
    $theStr =~ s/\&\#61;/\=/g;
    $theStr =~ s/\&\#061;/\=/g;
    $theStr =~ s/\&\#62;/\>/g;
    $theStr =~ s/\&\#062;/\>/g;
    $theStr =~ s/\&\#91;/\[/g;
    $theStr =~ s/\&\#091;/\[/g;
    $theStr =~ s/\&\#93;/\]/g;
    $theStr =~ s/\&\#093;/\]/g;
    $theStr =~ s/\&\#95;/\_/g;
    $theStr =~ s/\&\#095;/\_/g;
    $theStr =~ s/\&\#124;/\|/g;

    return $theStr;
}

1;
