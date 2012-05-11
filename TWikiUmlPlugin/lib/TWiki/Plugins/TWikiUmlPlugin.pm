# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007 Carlos Manzanares, carlos.manzanares@gmail.com
#
# For licensing info read LICENSE file in the TWiki root.
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

package TWiki::Plugins::TWikiUmlPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName );

use Error qw(:try);

# This should always be $Rev: 9813$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 9813$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '1.0';

# Name of this Plugin, only used in this module
$pluginName = 'TWikiUmlPlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between TWikiDrawPlugin and Plugins.pm");
        return 0;
    }

    TWiki::Func::registerTagHandler( 'UML', \&handleUml );

    TWiki::Func::registerRESTHandler( 'save', \&restSave );

    return 1;
}

sub commonTagsHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    # add dojo javascript initialization
    if ( $_[0] =~ m/<head>/ && $_[0] !~ m/$pluginName JSInit/ ) {
        $_[0] =~ s/<head>/&getJSInit()/oe;
    }

    # smell: IE and dojo does not seem to like the DOCTYPE defined by TWiki
    $_[0] =~ s/<!DOCTYPE.*?>//o;
}

sub getJSInit() {
    return
        '<head><!-- '
      . $pluginName
      . ' JSInit --><script language="JavaScript" type="text/javascript">djConfig = { isDebug: false };</script><script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/TWikiUmlPlugin/dojo/dojo.js"></script>';
}

sub handleUml {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    # $session  - a reference to the TWiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the variable

    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'

    my $nameVal = $params->{_DEFAULT};
    if ( !$nameVal ) {
        $nameVal = "untitled";
    }
    $nameVal =~ s/[^A-Za-z0-9_\.\-]//go;    # delete special characters
    $nameVal = "TWikiUmlPlugin_" . $nameVal;

    my $width = $params->{width};
    if ( !$width ) {
        $width = 800;
    }
    my $height = $params->{height};
    if ( !$height ) {
        $height = 400;
    }

    my $toolbar = $nameVal . "Toolbar";
    my $editor  = $nameVal . "Editor";
    my $content = $nameVal . "Content";

    my $wikiName = TWiki::Func::getWikiName();
    my $isGuest = $wikiName eq
      "WikiGuest";    # TWiki::Func::isGuest() does not seem to work...
    my $isChangeAllowed = !$isGuest
      && TWiki::Func::checkAccessPermission( 'CHANGE', $wikiName, undef,
        $theTopic, $theWeb, undef );

    my $retVal = "";

    my $display;
    if ($isChangeAllowed) {
        $display = 'block';
    }
    else {
        $display = 'none';
    }

    $retVal .= "<div id='$toolbar' style='width: $width"
      . "px; display: $display;'></div>";
    $retVal .=
        "<div id='$editor' style='width: $width"
      . "px; height: $height"
      . "px;'></div>";

    my $headVal = "";
    $headVal .= "<script type='text/javascript'>\n";

    $headVal .= "dojo.require('diagram.editor');\n";
    $headVal .= "dojo.require('diagram.uml');\n";
    $headVal .= "dojo.require('dojo.debug.console')\n";

    $headVal .= "function init() {\n";
    $headVal .= "  var hrefTranslate = function(href) {\n";
    $headVal .= "    var currentHRef = location.href;\n";
    $headVal .= "    var i = currentHRef.lastIndexOf( '/' );\n";
    $headVal .= "    return currentHRef.substring(0, i + 1) + href;\n";
    $headVal .= "  };\n";

    $headVal .= "  var editorContainer = dojo.byId('$editor');\n";
    $headVal .=
"  var editor = new diagram.Editor(editorContainer, false, hrefTranslate);\n";

    if ($isChangeAllowed) {
        $headVal .= "  var toolbarContainer = dojo.byId('$toolbar');\n";
        $headVal .=
"  var toolbar = new diagram.uml.Toolbar(toolbarContainer, editor);\n";
    }

    my $fileName = getFileName($nameVal);

    if ( TWiki::Func::attachmentExists( $theWeb, $theTopic, $fileName ) ) {
        $headVal .= "  var xmiHandler = new diagram.xmi.Handler();\n";
        $headVal .=
          "  xmiHandler.xmiFileImport('%ATTACHURLPATH%/$fileName', editor);\n";
    }

    if ($isChangeAllowed) {
        $headVal .= "  var wikiUrl = '%PUBURL%';\n";
        $headVal .=
          "  wikiUrl = wikiUrl.substr(0, wikiUrl.lastIndexOf('/pub'));\n";
        $headVal .= "  wikiUrl += '/bin/rest/$pluginName/save';\n";
        $headVal .= "  var topicName = '%TOPIC%';\n";
        $headVal .= "  toolbar.xmiExport = function() {\n";
        $headVal .=
          "    var doc = new diagram.xmi.Handler().xmiExport(this.editor);\n";
        $headVal .= "    var kw = {\n";
        $headVal .= "      url:     wikiUrl,\n";
        $headVal .= "      load:    function(type, data, evt) {\n";
        $headVal .= "                 dojo.debug(data);\n";
        $headVal .= "               },\n";
        $headVal .= "      method:  'POST',\n";
        $headVal .=
"      content: {xmi: doc, web: '%WEB%', topicName: topicName, fileName: '$nameVal'}\n";
        $headVal .= "    };\n";
        $headVal .= "    dojo.io.bind(kw);\n";
        $headVal .= "  };\n";
    }

    $headVal .= "}\n";

    $headVal .= "dojo.addOnLoad(init);\n</script>\n";

    TWiki::Func::addToHEAD( "UmlPlugin::$nameVal", $headVal );

    return $retVal;
}

sub getFileName {
    my ($name) = @_;

    my $ret = sanitize($name);

    return $ret . ".xml";
}

sub sanitize {
    my ($value) = @_;

    my $ret = $value;
    $ret =~ /\.*([ \w_.\-]+)$/go;
    $value = $1;

    # Remove problematic chars
    $value =~ s/$TWiki::cfg{NameFilter}//goi;

    # Strip dots and slashes at start
    # untaint at the same time
    $value =~ s/^([\.\/\\]*)*(.*?)$/$2/go;

    return $value;
}

sub restSave {

    #my ($session) = @_;

    my $wikiName = TWiki::Func::getWikiName();

    my $xmi      = $_[0]->{cgiQuery}->{xmi}[0];
    my $web      = $_[0]->{cgiQuery}->{web}[0];
    my $topic    = $_[0]->{cgiQuery}->{topicName}[0];
    my $fileName = $_[0]->{cgiQuery}->{fileName}[0];

    $web      = sanitize($web);
    $topic    = sanitize($topic);
    $fileName = getFileName($fileName);

    my $workArea = TWiki::Func::getWorkArea($pluginName);

    # Temp file in workarea - Filename + 9 digits to avoid race condition
    my $tempName = $workArea . '/' . $fileName . int( rand(1000000000) );

    # Saving temporary file
    TWiki::Func::saveFile( $tempName, $xmi );

    my @stats    = stat $tempName;
    my $fileSize = $stats[7];
    my $fileDate = $stats[9];

    TWiki::Func::saveAttachment(
        $web, $topic,
        $fileName,
        {
            file     => $tempName,
            filedate => $fileDate,
            filesize => $fileSize,
            filepath => $fileName,
            hide     => 1
        }
    );

    # Delete temporary file
    unlink($tempName) if ( $tempName && -e $tempName );

    return "Attachment $fileName saved";
}

1;
