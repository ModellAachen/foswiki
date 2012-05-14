#
# TWiki WikiClone (see wiki.pm for $wikiversion and other info)
#
# Search engine of TWiki.
#
# Copyright (C) 2000 Peter Thoeny, Peter@Thoeny.com
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
# Notes:
# - Latest version at http://twiki.org/
# - Installation instructions in $dataDir/%SYSTEMWEB%/CompleteDocumentation.txt

package TWiki::Plugins::NavPlugin;

use strict;

use vars qw(
  $topic $web $user $installWeb $VERSION $RELEASE
  $documentName $prevTopic $nextTopic $tocTopic
  $tocNameFlag $debug
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# ========================
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

 # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $debug = &TWiki::Func::getPreferencesFlag("NAVPLUGIN_DEBUG");

    $tocNameFlag = "Index";
    $nextTopic   = "";
    $prevTopic   = "";
    $tocTopic    = "";
    if ( TWiki::Func::topicExists( $web, $topic ) ) {
        $documentName = &getDocName( $topic, $web );
        $tocTopic = $documentName . $tocNameFlag;
        if ( TWiki::Func::topicExists( $web, $tocTopic ) ) {
            &handleNavLinks( $topic, $web, $tocTopic );
        }
        else {
            $tocTopic = "";
        }
    }
    return 1;
}

# =========================
sub commonTagsHandler {
    &TWiki::Func::writeDebug("NavPlugin::commonTagsHandler called") if $debug;
    $_[0] =~ s/%PREVTOPIC%/$prevTopic/geo;
    $_[0] =~ s/%NEXTTOPIC%/$nextTopic/geo;
    $_[0] =~ s/%TOCTOPIC%/$tocTopic/geo;
}

# ========================
sub getDocName {
    my ( $theTopic, $theWeb ) = @_;
    my $theTopicText;
    $theTopicText = &TWiki::Func::readTopicText( $theWeb, $theTopic );
    if ( !$theTopicText ) {

        #was not able to read the topic text - don't know why .... DNE??
        return "";
    }

    # parse the " * Set (DOCNAME)$theAccessType = " in body text
    my $myNameOfVariable;
    foreach ( split( /\n/, $theTopicText ) ) {
        if (/^\s+\*\sSet\s(DOCNAME)\s*\=\s*(.*)/) {
            if ($2) {
                $myNameOfVariable = $1;
                if ( $myNameOfVariable eq "DOCNAME" ) {
                    return &trimBlanks($2);
                }
            }
        }
    }
    return "";
}

sub trimBlanks {
    my @out = @_;
    for (@out) {
        s/^\s+//;
        s/\s+$//;
    }
    return wantarray ? @out : $out[0];
}

# =========================
sub handleNavLinks {
    my ( $theTopic, $theWeb, $theToc ) = @_;
    my $tocData;
    $tocData = &TWiki::Func::readTopicText( $theWeb, $theToc );
    if ( !$tocData ) {

        #was not able to read the topic text - don't know why .... DNE??
        return "";
    }

    # parse the " * Set (DOCNAME)$theAccessType = " in body text
    my $myPrevTopic    = "";
    my $firstIteration = 1;
    my $lastIteration  = 0;
    my $indexData      = 0;
    foreach ( split( /\n/, $tocData ) ) {
        $nextTopic .= "#";    #####
        if ( !$indexData ) {
            if (/<!--IndexStart-->/) {
                $indexData = 1;
            }
        }
        else {
            if (/^\s+\*\s(.*)/) {

                #	if( /^\s+\*\s\W\W([a-zA-Z0-9])\W\W([a-zA-Z0-9])\W\W/ ) {
                my $readLine = &trimBlanks($1);
                $nextTopic .= "fd-$readLine";    ####
                if ($firstIteration) {
                    $nextTopic .= "1st";
                    $firstIteration = 0;
                    $myPrevTopic    = $readLine;
                }
                else {
                    if ($lastIteration) {
                        $nextTopic = $readLine;
                        $prevTopic = $myPrevTopic;
                        return 1;
                    }
                }
                $prevTopic .= "$readLine-vs-$theTopic-";
                if ( $readLine eq $theTopic ) {

                    #topic in TOC matches theTopic.
                    $lastIteration = 1;
                }
                else {
                    $myPrevTopic = $readLine;
                }
            }
            else {
                if ($lastIteration) {
                    $nextTopic = $theTopic;
                    $prevTopic = $myPrevTopic;
                    return 1;
                }
            }

        }
    }
}

#===========================================

1;

# EOF

