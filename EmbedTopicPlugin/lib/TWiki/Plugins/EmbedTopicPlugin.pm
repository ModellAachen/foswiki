# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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

# =========================
# EmbedTopicPlugin 1.051
# David Bourget (moi@dbourget.com)
#
# Supports viewing/editing of embeded topics in one page. Unlimited nesting of topics. Visit twiki.org
# for latest version and documentation.
#
# =========================
#

=todo

- Test handling of metadata
- Test more thoroughly security
- Check other TODO notes inside code

=cut

package TWiki::Plugins::EmbedTopicPlugin;

use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $bgcolor $hdcolor
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'EmbedTopicPlugin';    # Name of this Plugin

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG") || 0;

 # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $bgcolor = TWiki::Func::getPluginPreferencesValue("BGCOLOR") || "#222288";
    $hdcolor = TWiki::Func::getPluginPreferencesValue("HDCOLOR") || "#DDDDDD";

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

###
# Handler functions
###

# Called by commonTagsHandler
# expandView ( qualified name of topic to expand, web of container )
sub expandView {

    my $qn = shift;
    my $t  = $qn;  # embedded topic
    my $w  = $web; # web of embedded topic is the same as container's by default

    #TODO: adapt to real name conventions
    #Extract web name if any
    if ( $qn =~ /(\w+)\.(\w+)/ ) {
        $w = $1;
        $t = $2;
    }

    #Check regress
    if ( $w eq $web and $t eq $topic ) {
        return
          "\nRegress stopped. $w.$t was going to be embedded in itself here.\n";
    }

    #Check the topic exists
    if ( !TWiki::Func::topicExists( $w, $t ) ) {
        return "";    #Empty if topic doesn't exist
    }

    my $r = TWiki::Func::readTopicText( $w, $t, "", 0 );

    #TODO: check exceptions

    # Do like the external view module
    $r = TWiki::Func::expandCommonVariables( $r, $t, $w );
    $r = TWiki::Func::renderText( $r, $w );

    #Metadata is discarded. No metadata displayed or edited in embeded topics.
    $r =~ s/%META[:\w]*{[^}]*}%//ig;

    my $spacerimg =
      TWiki::Func::getPubUrlPath() . "/$installWeb/$pluginName/spacer.gif";
    $r =
"<table width='100%' border='0' cellpadding='0' cellspacing='0'><tr><td width='1' bgcolor='$bgcolor'><img src='$spacerimg' width='1'></td><td width='100%'><table cellspacing='0' border='0' width='100%'><tr><td bgcolor='$bgcolor'><a style='color:$hdcolor;font-size:9px;text-decoration:none;' href='%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/$w/$t'>$qn</a></td></tr><tr><td><table border=0 cellpadding=2><td>$r</td></table></td></tr></table></td></tr></table>";

    return $r;
}

# Called by beforeEditHandler: open the embeded topics for editing
sub expandBeforeEdit {

    my $qn = shift;
    my $t  = $qn;
    my $w  = $web;

    #TODO: adapt to real name conventions
    #Extract web name if any

    if ( $qn =~ /(\w+)\.(\w+)/ ) {
        $w = $1;
        $t = $2;
    }

    #Check regress
    if ( $w eq $web and $t eq $topic ) {
        return
          "\nRegress stopped. $w.$t was going to be embedded in itself here.\n";
    }

    #TODO: create a lock (perhaps?)

    # If does not exist, empty topic
    if ( !TWiki::Func::topicExists( $w, $t ) ) {
        return "%BeginTopic{$qn}%%End{$qn}%";
    }

    my $r = TWiki::Func::readTopicText( $w, $t, "", 0 );

    #TODO: check error

    TWiki::Func::writeDebug(
        "- ${pluginName}::expandBeforeEdit retrieved: '$r')")
      if $debug;

#Metadata is discarded. No metadata displayed or edited in embeded topics. (old metadata re-inserted)
    $r =~ s/%META[:\w]*{[^}]*}%//ig;

    #Remove the extra newlines that are mysteriously added
    $r =~ s/[\n\r]$//s;

    #$r =~ s/^[\n\r]//s;

    TWiki::Func::writeDebug("- ${pluginName}::expandBeforeEdit cleaned: '$r')")
      if $debug;

    # Recursive call on the content of $r
    $r =~ s/%T{(.+?)}/&expandBeforeEdit($1)/ige;
    $r =~ s/%EmbedTopic{(.+?)}%/&expandBeforeEdit($1)/ige;

    $r = "%BeginTopic{$qn}%$r%End{$qn}%";
    return $r;
}

# Called before saving: saves the embeded topics separately
sub saveEmbed {
    my $qn = shift;
    my $r  = shift;

    #Set default web to current wiki's
    my $w            = $web;
    my $autoinsert_w = $w;
    my $autoinsert_t = "";

    # Extract auto-insert part
    if ( $qn =~ /(.+)::(.+)/ ) {
        $qn           = $2;
        $autoinsert_t = $1;

        # Extract web if any
        if ( $autoinsert_t =~ /(\w+)\.(\w+)/ ) {
            $autoinsert_w = $1;
            $autoinsert_t = $2;
        }
    }

    #Extract web name if any
    if ( $qn =~ /(\w+)\.(\w+)/ ) {
        $w = $1;
        $t = $2;
    }
    else {
        $t = $qn;
    }

    my $toRet = "%EmbedTopic{$qn}%";

    # Save embeded topic
    if ( TWiki::Func::topicExists( $w, $t ) ) {
        my $oopsUrl = TWiki::Func::setTopicEditLock( $w, $t, 1 );
        if ($oopsUrl) {
            TWiki::Func::redirectCgiQuery( $query, $oopsUrl )
              ;    # assuming valid query
            return $toRet;
        }
    }

    if ( $r eq "" ) { $r = " "; }

    $oopsUrl = TWiki::Func::saveTopicText( $w, $t, $r );

    # TODO check exceptions

    TWiki::Func::writeDebug("- ${pluginName}::saveEmbed saved $w.$t:\n$r")
      if $debug;

    if ( TWiki::Func::topicExists( $w, $t ) ) {
        $oopsUrl = TWiki::Func::setTopicEditLock( $w, $t, 0 );
        if ($oopsUrl) {
            TWiki::Func::redirectCgiQuery( $query, $oopsUrl );
            return $toRet;
        }
    }

    # Finish if no autoinsert
    return $toRet unless ($autoinsert_t);

    # If autoinsert exists, append to the end; if not, create and insert.
    if ( !TWiki::Func::topicExists( $autoinsert_w, $autoinsert_t ) ) {
        $oopsUrl =
          TWiki::Func::saveTopicText( $autoinsert_w, $autoinsert_t, $toRet );

        # TODO check exceptions
    }
    else {

        $oopsUrl =
          TWiki::Func::setTopicEditLock( $autoinsert_w, $autoinsert_t, 1 );
        if ($oopsUrl) {
            TWiki::Func::redirectCgiQuery( $query, $oopsUrl )
              ;    # assuming valid query
            return $toRet;
        }

        # Append embed tag
        my $auto =
          TWiki::Func::readTopicText( $autoinsert_w, $autoinsert_t, "", 0 );
        $auto = $auto . "\n\n $toRet";
        $oopsUrl =
          TWiki::Func::saveTopicText( $autoinsert_w, $autoinsert_t, $auto );

        # TODO check exceptions

        $oopsUrl =
          TWiki::Func::setTopicEditLock( $autoinsert_w, $autoinsert_t, 0 );
        if ($oopsUrl) {
            TWiki::Func::redirectCgiQuery( $query, $oopsUrl );
            return $toRet;
        }

    }

    return $toRet;
}

sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    $_[0] =~ s/%T{(.+?)}/&expandView($1,$_[2])/ige;
    $_[0] =~ s/%EmbedTopic{(.+?)}%/&expandView($1)/ige;

}

# =========================
sub beforeEditHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::beforeEditHandler( $_[2].$_[1] )")
      if $debug;

# This handler is called by the edit script just before presenting the edit text
# in the edit box. Use it to process the text before editing.
    $_[0] =~ s/%T{(.+?)}/&expandBeforeEdit($1)/ige;
    $_[0] =~ s/%EmbedTopic{(.+?)}%/&expandBeforeEdit($1)/ige;
}

sub beforeSaveHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )")
      if $debug;

# This handler is called by TWiki::Store::saveTopic just before the save action.
    $_[0] =~ s/%BeginTopic{(.+?)}%(.*?)%End{\1}%/&saveEmbed($1,$2,$_[2])/igse;
    $_[0] =~ s/%B{(.+?)}(.*?)%E{\1}/&saveEmbed($1,$2)/igse;
}

1;
