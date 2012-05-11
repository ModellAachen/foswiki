# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Antonio Terceiro, asaterceiro@inf.ufrgs.br
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
#   earlyInitPlugin         ( )                                     1.020
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   beforeCommonTagsHandler ( $text, $topic, $web )                 1.024
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   afterCommonTagsHandler  ( $text, $topic, $web )                 1.024
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   afterSaveHandler        ( $text, $topic, $web, $errors )        1.020
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
package TWiki::Plugins::SvgPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $defaultSize
);

use Image::LibRSVG;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'SvgPlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.000 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

    # get a default size for pictures
    $defaultSize = TWiki::Func::getPluginPreferencesValue("DEFAULTSIZE");
    if ( not( $defaultSize =~ m/([0-9]+)x([0-9]+)/ ) ) {
        $defaultSize = "320x200";
    }

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

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;

    $_[0] =~ s/%SVG{(.*?)}%/&handleSvg($1,$_[1],$_[2])/ge;

}

sub SvgPluginError {
    my ($arg) = @_;
    return
"<span style='background: #FFFFCC; color: red; text-decoration: underline;'><strong>$pluginName:</strong> $arg</span>";
}

sub handleSvg {
    my ( $args, $topic, $web ) = @_;

    # which drawing would we convert?
    my $drawing;
    if ( $args =~ m/^"([^"]+)"/ ) {
        $drawing = $1;
    }
    else {
        return SvgPluginError("you must specify a drawing to display!");
    }

    #where is the drawing?
    my $where;
    if ( $args =~ m/topic="(([^\.]+)\.)?([^"]+)"/ ) {
        if ($2) {

            # given a complete topic name, i.e. Web.TheTopic
            $where = "$2/$3";
        }
        else {

            # given only a topic name, use current web.
            $where = "$web/$3";
        }
    }
    else {

        # nothing given, use current topic
        $where = "$web/$topic";
    }

    # calculate size of the generated image:
    my ( $width, $height );
    if ( $args =~ m/size="([0-9]+)x([0-9]+)"/ ) {
        $width  = $1;
        $height = $2;
    }
    else {
        $defaultSize =~ m/([0-9]+)x([0-9]+)/;
        $width  = $1;
        $height = $2;
    }

    #get the base name for the generated file:
    my $basename = $drawing;
    $basename =~ s/.svg//;

    # source file
    my $fromFilename = TWiki::Func::getPubDir() . "/$where/$drawing";

    # destination file
    my $picture    = "$basename-$width" . "x$height.png";
    my $toFilename = TWiki::Func::getPubDir() . "/$where/$picture";
    my $pictureUrl =
        TWiki::Func::getUrlHost()
      . TWiki::Func::getPubUrlPath()
      . "/$where/$picture";

    if ( not( -e $fromFilename ) ) {
        return SvgPluginError(
            "can't find drawing !$drawing attched at $where.");
    }

    my $svgAge = ( -M $fromFilename );
    my $pngAge = ( -M $toFilename );

    # (re)generate, if PNG doesn't exist yet or if PNG is older than SVG
    if ( ( not defined $pngAge ) or ( $pngAge > $svgAge ) ) {
        my $rsvg = new Image::LibRSVG();
        $rsvg->convertAtMaxSize( $fromFilename, $toFilename, $width, $height );
    }

    return $pictureUrl;
}

# ==========================
1;
