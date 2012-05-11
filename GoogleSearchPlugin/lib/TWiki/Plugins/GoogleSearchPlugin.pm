# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional.
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# =========================

package TWiki::Plugins::GoogleSearchPlugin;

# =========================
#This is plugin specific variable
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug $name

);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$debug = 1;

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between GooglePlugin and Plugins.pm");
        return 0;
    }

    #Getting the value of debug variable from the plugin configuration topic.
    $debug = &TWiki::Func::getPreferencesFlag("GOOGLESEARCHPLUGIN_DEBUG");

    #Writing to debug.txt if debug variable is set to 1
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins:GoogleSearchPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

# =========================
sub commonTagsHandler {

#regular expressions to replace the plugin call with the output of the corresponding functions.

    $_[0] =~ s/%GOOGLE_SEARCH_PLUGIN%/_handleTopic(  )/geo;
    $_[0] =~ s/%GOOGLE_SEARCH_PLUGIN{(.*?)}%/_handleKeyword( $1) /geo

}

#-------------------------------------------------------------------------------------------------
sub _handleTopic( ) {

    #Following line extract the name of the topic
    #$topic = $TWiki::topicName;

    $query = $topic;

    #Following code find parts of topic name to give them to google search
    $query =~ s/([A-Z])/+$1/g;
    $query =~ s/^\+//;

    $name = $query;
    $name =~ s/\+/ /g;

    #Followin line of code displays link on the page to Google Search
    return
"<html><a href=\"http://www.google.co.in/search?q=$query\" target=\"_blank\">Search for $name  </a><br></html>";
}

sub _handleKeyword( ) {

    my ($attributes) = @_;

    #Extraxct value of topic specified
    $topic = scalar &TWiki::Func::extractNameValuePair( $attributes, "topic" );

    $query = $topic;

    #Following code find parts of topic name to give them to google search
    $query =~ s/([A-Z])/+$1/g;
    $query =~ s/^\+//;
    $name = $query;
    $name =~ s/\+/ /g;

    #Followin line of code displays link on the page to Google Search
    return
"<html> <a href=\"http://www.google.co.in/search?q=$query\" target=\"_blank\">Search for $name  </a><br></html>";
}

1;
