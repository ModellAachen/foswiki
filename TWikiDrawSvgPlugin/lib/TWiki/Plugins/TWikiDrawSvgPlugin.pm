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
package TWiki::Plugins::TWikiDrawSvgPlugin;    # change the package name!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
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
            "Version mismatch between TWikiDrawSvgPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("TWIKIDRAWSVGPLUGIN_DEBUG");

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::TWikiDrawSvgPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

sub handleDrawing {
    my ($attributes) = @_;
    my $nameVal = TWiki::Func::extractNameValuePair($attributes);
    if ( !$nameVal ) {
        $nameVal = "untitled";
    }
    $nameVal =~ s/[^A-Za-z0-9_\.\-]//go;    # delete special characters

    TWiki::Plugins::TWikiDrawSvgPlugin::activateWebStart( $web, $topic,
        "twikidrawsvg", $nameVal );

    return
        "<SCRIPT LANGUAGE=\"Javascript\">\n"
      . "var javawsInstalled = 0;\n"
      . "isIE = \"false\";\n"
      . "if (navigator.mimeTypes){"
      . "if (navigator.mimeTypes.length) {\n"
      . "x = navigator.mimeTypes['application/x-java-jnlp-file'];\n"
      . "if (x) javawsInstalled = 1;\n"
      . "}} else {\n"
      . "isIE = \"true\";\n" . "}\n"
      . "insertLink(\"http://www.google.com\",\"pouet\");\n"
      . "function insertLink(url, name) {\n"
      . "if (javawsInstalled) {\n"
      . "document.write(\"<a href=\\\""
      . TWiki::Func::getUrlHost
      . "/twiki/pub" . "/"
      . $web . "/"
      . $topic . "/draw"
      . $nameVal . ".jnlp" . "\\\" "
      . "><img src=\\\"%ATTACHURLPATH%/$nameVal.gif\\\"></a><br>\");\n"
      . "} else {\n"
      . "document.write(\"<a href=\\\""
      . TWiki::Func::getUrlHost
      . "/twiki/pub" . "/"
      . $web . "/"
      . $topic . "/draw"
      . $nameVal . ".jnlp" . "\\\" "
      . "><img src=\\\"%ATTACHURLPATH%/$nameVal.gif\\\"></a><br>\");\n"
      . "document.write(\"Need to install Java Web Start to edit <a href=\\\"http://www.java.sun.com/products/javawebstart/\\\">(download)</a>\");\n"
      . "}\n" . "}\n"
      . "</SCRIPT>";

#  return "<a href=\"".
#      TWiki::Func::getUrlHost."/twiki/pub"."/".$web."/".$topic."/draw".$nameVal.".jnlp"."\" ".
#	"onMouseOver=\"".
#	       "window.status='Edit drawing [$nameVal] using ".
#	  "TWiki Draw Svg (requires a Java Web Start)';" .
#	  "return true;\"".
#	"onMouseOut=\"".
#	  "window.status='';".
#	  "return true;\">".
#	"<img src=\"%ATTACHURLPATH%/$nameVal.gif\" ".
#	  "alt=\"Edit drawing '$nameVal' ".
#	    "(requires a Java Web Start)\"></a>";

    #   return "<a href=\"".
    #      TWiki::Func::getOopsUrl($web, $topic, "twikidraw", $nameVal)."\" ".
    "onMouseOver=\""
      . "window.status='Edit drawing [$nameVal] using "
      . "TWiki Draw applet (requires a Java 1.1 enabled browser)';"
      . "return true;\""
      . "onMouseOut=\""
      . "window.status='';"
      . "return true;\">"
      . "<img src=\"%ATTACHURLPATH%/$nameVal.gif\" "
      . "alt=\"Edit drawing '$nameVal' "
      . "(requires a Java enabled browser)\"></a>";
}

sub activateWebStart {
    my ( $theWeb, $theTopic, $tmplName, $param ) = @_;

    if ( !$tmplName ) {
        $tmplName = "oops";
    }
    my $tmplData = TWiki::Func::readTemplate($tmplName);
    if ( !$tmplData ) {
        TWiki::Func::writeHeader($query);
        print "<html><body>\n"
          . "<h1>TWiki Installation Error</h1>\n"
          . "Template file $tmplName.tmpl not found or template directory \n"
          . "$TWiki::templateDir not found.<p />\n"
          . "Check the \$templateDir variable in TWiki.cfg.\n"
          . "</body></html>\n";
        return;
    }

    $tmplData =~ s/%PARAM1%/$param/go;
    $tmplData =~ s/%PARAM2%/$param/go;
    $tmplData =~ s/%PARAM3%/$param/go;
    $tmplData =~ s/%PARAM4%/$param/go;

    $tmplData = TWiki::Func::expandCommonVariables( $tmplData, $topic );

    print STDERR TWiki::Func::getPubDir
      . "/$theWeb/$theTopic/draw$param.jnlp" . "\n";
    open( newJnlp,
        ">" . TWiki::Func::getPubDir . "/$theWeb/$theTopic/draw$param.jnlp" );
    print newJnlp $tmplData;
    close(newJnlp);
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug(
        "- TWikiDrawSvgPlugin::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/geo;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/geo;
    $_[0] =~ s/%DRAWINGSVG{(.*?)}%/&handleDrawing($1)/geo;
    $_[0] =~ s/%DRAWINGSVG%/&handleDrawing("untitled")/geo;
}

1;

