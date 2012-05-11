# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Rudi Bierach, rbierach@yahoo.com
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
# Converts table cells into text edit boxes for easier editing of tables
#
package TWiki::Plugins::EditInTablePlugin
  ;    # change the package name and $pluginName!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $exampleCfgVar $query $saved
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'EditInTablePlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $query = &TWiki::Func::getCgiQuery();
    if ( !$query ) {
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    #	$debug = 1;

    # record if we have saved this session yet
    # stops the topic being saved 3 times under the tiger skin
    $saved = 0;

# Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
#    $exampleCfgVar = &TWiki::Func::getPreferencesValue( "EDITINTABLEPLUGIN_EXAMPLE" ) || "default";

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
# if user has clicked the save table button then save the new table entries
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;

    # if we have already saved the data then don't do it again
    if ($saved) {
        return;
    }

    # if edittable is enabled
    # and we are saving then save
    if ( $query->param("edittable") ) {
        if ( $query->param("edittableSave") ) {

            $saved = 1;

            #			my $name = "";
            #			foreach $name ($query->param)
            #			{
            #				TWiki::Func::writeDebug( "*** $name" ) if $debug;
            #			}

            #			my $inTable = 0;

            # text to save is accumilated into result
            my $result = "";

            my ( $theWeb, $theTopic ) = ( $_[2], $_[1] );
            my ( $meta, $text ) = &TWiki::Func::readTopic( $theWeb, $theTopic );

            my $tableRowNumber = 0;
            foreach $line ( split( /\n/, $text ) ) {

                # for each line that matches a table row | 1 | ... 2 |
                if ( $line =~ /^(\s*)\|.*\|\s*$/ ) {

                    #					if (!$inTable)
                    #					{
                    #					}
                    #					$inTable = 1;

                    # for each table row in the topic
                    # if a cgi parameter exists for that row and col then
                    # replace existing row with cgi parameters
                    my $tableColNumber = 0;
                    if (
                        $query->param(
                                "tableItem_"
                              . $tableRowNumber . "_"
                              . $tableColNumber
                        ) ne ""
                      )
                    {
                        my $item      = " ";
                        my $firstItem = 1;
                        $result .= "|";
                        my $i = 0;
                        my $numOfCols =
                          $query->param( "tableCols_" . $tableRowNumber );
                        for ( ; $i < $numOfCols ; $i++ ) {
                            $item =
                              $query->param( "tableItem_"
                                  . $tableRowNumber . "_"
                                  . $tableColNumber );
                            if ( $item eq "" ) {

#								TWiki::Func::writeDebug( "not defined [$tableRowNumber, $tableColNumber]" ) if $debug;
                                $item = " ";    # make sure cell is rendered
                            }

#							TWiki::Func::writeDebug( "[$tableRowNumber, $tableColNumber] = $item" ) if $debug;
                            $result .= "$item" . "|";
                            $tableColNumber++;
                        }
                        $result .= "\n";
                    }
                    else {
                        $result .= "$line\n";
                    }

                    $tableRowNumber++;
                }
                else {

                    #					if ($inTable)
                    #					{
                    #					}
                    #					$inTable = 0;
                    $result .= "$line\n";
                }
            }

    # save the new table changes
    # ... making sure we handle errors and locking and redirecting to the view
    # TODO: these lines could be refactored into a common method in &TWiki::Func
    #			TWiki::Func::writeDebug( "result [$result]" ) if $debug;
            my $error =
              &TWiki::Store::saveTopic( $theWeb, $theTopic, $result, $meta );
            &TWiki::Func::setTopicEditLock( $theWeb, $theTopic, "on" );
            my $url = &TWiki::Func::getViewUrl( $theWeb, $theTopic );
            if ($error) {
                $url =
                  &TWiki::Func::getOopsUrl( $theWeb, $theTopic, "oopssaveerr",
                    $error );
            }
            &TWiki::Func::redirectCgiQuery( $query, $url );
        }
    }
}

sub encodeChars {
    my ($in) = @_;
    my $ret = "";

    my $a;

    foreach $a ( split( //, $in ) ) {
        my $code = ord($a);
        $ret .= "&#$code;";
    }

    return $ret;
}

# =========================
# find all tables and convert the fields to text edit boxes
sub startRenderingHandler {
### my ( $text, $web, $meta ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug("- ${pluginName}::startRenderingHandler( $_[1] )")
      if $debug;

    # only show text edit boxes if edittable is turned on
    if ( $query->param("edittable") ) {

        # temp copy of text is accumilated
        my $text;

        my $line           = "";
        my $tableRowNumber = 0;
        my $inTable        = 0;
        foreach $line ( split( /\n/, $_[0] ) ) {

            # for each line that matches a table row | 1 | ... 2 |
            if ( $line =~ /^(\s*)\|.*\|\s*$/ ) {

                if ( !$inTable ) {

      # start a new form for the save table button at the beginning of the table
                    my $formUrl = &TWiki::Func::getViewUrl( $web, $topic );
                    $text .= "<form method=\"post\" action=\"$formUrl\">\n";
                    $text .=
"<input type=\"hidden\" name=\"edittable\" value=\"1\">\n";
                }

                $inTable = 1;

                # strip whitespace from the front and back
                $line =~ s/^\s+//;
                $line =~ s/\s+$//;

                # for each item on this row
                #	put item into a text edit
                #	name of text edit is tableItem_[row]_[col]
                my @contents       = split( /\|/, $line );
                my $firstItem      = 1;
                my $tableColNumber = 0;
                foreach $item (@contents) {
                    if ( !$firstItem ) {
                        my $encodedItem = encodeChars($item);
                        $text .= "|";
                        $text .=
"<input type=\"text\" value=\'$encodedItem\' name=\"tableItem_"
                          . $tableRowNumber . "_"
                          . $tableColNumber . "\">";
                        $tableColNumber++;
                    }
                    else {
                        $firstItem = 0;
                    }
                }
                $text .=
                    "<input type=\"hidden\" name=\"tableCols_"
                  . $tableRowNumber
                  . "\" value=\"$tableColNumber\">";
                $text .= "|\n";
                $tableRowNumber++;
            }
            else {
                if ($inTable) {

           # end of the table so output the Save Table button and close the form
                    $text .=
"<input type=\"hidden\" name=\"edittableSave\" value=\"1\">\n";
                    $text .= "<input type=\"submit\" value=\" Save Table \">\n";
                    $text .= "</form>\n";
                }
                $inTable = 0;
                $text .= "$line\n";
            }
        }

        TWiki::Func::writeDebug("view [$text]") if $debug;
        $_[0] = $text;
    }
}

# =========================

1;
