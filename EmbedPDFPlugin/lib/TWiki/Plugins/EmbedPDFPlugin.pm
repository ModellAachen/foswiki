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
package TWiki::Plugins::EmbedPDFPlugin
  ;    # change the package name and $pluginName!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $linkText $prerendered
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'EmbedPDFPlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    # Get plugin preferences, the variable defined by:      * Set LINKTEXT = ...
    $linkText = TWiki::Func::getPreferencesValue("EMBEDPDFPLUGIN_LINKTEXT");

    # Get plugin preferences, the variable defined by:   * Set PRERENDERED = ...
    $prerendered =
      TWiki::Func::getPreferencesValue("EMBEDPDFPLUGIN_PRERENDERED");

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    $_[0] =~ s+%EMBEDPDF{\s*(.*?)\s*}%+&handleEmbedPDF($1, $_[1], $_[2])+ge;
    $_[0] =~
s+%EMBEDPDFSIZE{\s*([A-Za-z0-9_-]*?)\s*}%+&handleEmbedPDFSize($1, $_[1], $_[2])+ge;
}

sub handleEmbedPDF {
    my ( $thePDFFile, $theTopic, $theWeb ) = @_;

    if ( $prerendered
        && -r TWiki::Func::getPubDir()
        . "/$theWeb/$theTopic/$thePDFFile.$prerendered" )
    {
        $result = "<img src=\"%ATTACHURL%/$thePDFFile.$prerendered\">";
    }
    else {
        $result =
"<embed src=\"%ATTACHURL%/$thePDFFile.pdf\" %EMBEDPDFSIZE{$thePDFFile}% />";
    }

    $result =
"<table><tbody><tr><td align=\"center\">$result</td></tr><tr><td align=\"center\"><a href=\"%ATTACHURL%/$thePDFFile.pdf\">$linkText</a></td></tr></tbody></table>"
      if $linkText;
    return $result;
}

# =========================

sub handleEmbedPDFSize {
    my ( $thePDFFile, $theTopic, $theWeb ) = @_;

    $pdf =
      TWiki::Func::readFile(
        TWiki::Func::getPubDir() . "/$theWeb/$theTopic/$thePDFFile.pdf" );
    if ( $pdf =~ /MediaBox\s*\[\s*([0-9]+\s+){2}([0-9]+)\s+([0-9]+)\s*\]/ ) {
        $width  = $2;
        $height = $3;
        $query  = TWiki::Func::getCgiQuery();
        if ( $query && $query->user_agent("MSIE") ) {
            $width += 60;
            if ( $width < 360 ) {
                $width = 360;
            }
            $height += 110;
        }
        return "width=\"$width\" height=\"$height\"";
    }
    return "note=\"size unknown\"";
}

1;
