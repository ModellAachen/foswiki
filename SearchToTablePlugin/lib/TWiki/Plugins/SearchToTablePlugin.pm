#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
# =========================
#
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional.
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# =========================
package TWiki::Plugins::SearchToTablePlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  $exampleCfgVar
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between EmptyPlugin and Plugins.pm");
        return 0;
    }

 # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $searchVar = &TWiki::Func::getPreferencesValue("KENSPLUGIN_SEARCH")
      || "default";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("KENSPLUGIN_DEBUG");

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::SearchToTablePlugin::initPlugin( $web.$topic ) is OK"
    ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug(
        "- SearchToTablePlugin::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/geo;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/geo;

    $_[0] =~ s/%SearchToTable{(.*?)}%/&handleSearchToTable($1)/geo;

}

# =========================
sub handleSearchToTable {

    my ($args) = @_;
    my ( %fldChecks, $fld );
    my $textVal = "";
    my $nextVal = 0;

    my $theSearchVal = &TWiki::Func::extractNameValuePair( $args, "search" );
    my $displayList  = &TWiki::Func::extractNameValuePair( $args, "display" );
    my $titles       = &TWiki::Func::extractNameValuePair( $args, "titles" );
    my $fieldSearch =
      &TWiki::Func::extractNameValuePair( $args, "fieldSearch" );
    my $nextValueFld = &TWiki::Func::extractNameValuePair( $args, "nextValue" );

    my $thisWebName = $TWiki::webName;

    my (@dspFields);

    $displayList = "topic,revUser,revDate,firstLine" if ( !$displayList );
    $displayList =~ s/ //g;
    $titles      =~ s/ //g;

    # if titles were supplied use them, use use the field names
    if ($titles) {
        (@dspFields) = split( /\,/, $titles );
    }
    else {
        (@dspFields) = split( /\,/, $displayList );
    }

    # make the header line for the table
    foreach $fld (@dspFields) {
        $textVal .= "|*" . $fld . "*";
    }
    $textVal .= "|\n";

    # need field names in the dspFields array
    (@dspFields) = split( /\,/, $displayList );

    # create an array of field search values
    my (@checks) = split( /\,/, $fieldSearch );
    foreach $fld (@checks) {
        my ( $name, $value ) = split( /\:/, $fld );
        $fldChecks{$name} = $value;
    }

    &TWiki::Func::writeDebug(
"- SearchToTablePlugin::handleSearchToTable( $theSearchVal $thisWebName )"
    ) if $debug;

    $cmd =
      "$TWiki::egrepCmd -l $TWiki::cmdQuote$theSearchVal$TWiki::cmdQuote *.txt";

    my $sDir      = TWiki::Func::getDataDir() . "/$thisWebName";
    my @topicList = "";
    if ($theSearchVal) {

        # do grep search
        chdir("$sDir");
        $cmd =~ /(.*)/;
        $cmd     = $1;       # untaint variable (NOTE: Needs a better check!)
        $tempVal = `$cmd`;

        @topicList = split( /\n/, $tempVal );

        # cut .txt extension
        my @tmpList = map { /(.*)\.txt$/; $_ = $1; } @topicList;
        @topicList = ();
        my $lastTopic = "";
        foreach (@tmpList) {
            $tempVal = $_;

            # make topic unique
            if ( $tempVal ne $lastTopic ) {
                push @topicList, $tempVal;
            }
        }
    }

    # build the hashes for date and author
    foreach (@topicList) {
        my $tempVal = $_;

        # FIXME should be able to get data from topic
        my ( $meta, $text ) = &TWiki::Func::readTopic( $thisWebName, $tempVal );
        my ( $revdate, $revuser, $revnum ) =
          &TWiki::Store::getRevisionInfoFromMeta( $thisWebName, $tempVal, $meta,
            1 );
        $revuser = &TWiki::userToWikiName($revuser);
        $allowView =
          &TWiki::Access::checkAccessPermission( "view", $TWiki::wikiUserName,
            $text, $tempVal, $thisWebName );

        # If field checks were passed in see if this topic matches the
        # requested field values
        if ($allowView) {
            foreach $name ( keys(%fldChecks) ) {
                if (   $name eq "revUser"
                    || $name eq "revDate"
                    || $name eq "revNumber" )
                {
                    if (
                        ( $name eq "revUser" && $fldChecks{$name} != $revuser )
                        || (   $name eq "revDate"
                            && $fldChecks{$name} != $revdate )
                        || (   $name eq "revNumber"
                            && $fldChecks{$name} != $revnum )
                      )
                    {
                        $allowView = 0;
                    }
                }
                else {
                    %fieldData = $meta->findOne( "FIELD", $name );
                    if (  !%fieldData
                        || $fieldData{"value"} != $fldChecks{$name} )
                    {
                        $allowView = 0;
                    }
                }

            }
        }

        if ($allowView) {

            my $data = "";

            foreach $fld (@dspFields) {

                if ( $fld eq "revUser" ) {
                    $data = $revuser;
                }
                elsif ( $fld eq "revDate" ) {
                    $data = $revdate;
                }
                elsif ( $fld eq "revNumber" ) {
                    $data = $revnum;
                }
                elsif ( $fld eq "topic" ) {
                    $data = $tempVal;
                }
                elsif ( $fld eq "firstLine" ) {
                    $data = &_getFirstLine($text);
                }
                else {
                    my %fieldData = $meta->findOne( "FIELD", $fld );
                    if (%fieldData) {
                        $data = $fieldData{"value"};
                    }
                    else { $data = " "; }
                }

                $textVal .= "|" . $data;
            }

            $textVal .= "|\n";

            if ($nextValueFld) {
                my %fieldData = $meta->findOne( "FIELD", $nextValueFld );
                if (%fieldData) {
                    my $tmpVal = $fieldData{"value"};
                    if ( $tmpVal > $nextVal ) {
                        $nextVal = $tmpVal;
                    }
                }
            }
        }

    }

    if ($nextValueFld) {
        $nextVal++;
        $textVal .=
          "\nNext value for " . $nextValueFld . " is " . $nextVal . "\n";
    }

    return $textVal;

}

sub _getFirstLine {

    my ($text) = @_;

    my ($rtn) = "";

    @lines = split( /\n/, $text );

    foreach $ln (@lines) {
        &TWiki::Func::writeDebug("- foreach( $ln )") if $debug;

        if (   ( $ln =~ /^\<\!\-\-/ )
            || ( $ln =~ /^\-\-\-\+/ )
            || ( $ln =~ /^\s*$/ ) )
        {
        }
        else {
            return $ln;
            &TWiki::Func::writeDebug("- else( $rtn )") if $debug;
            last;
        }
    }

    return $rtn;

}

1;
