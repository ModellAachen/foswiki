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
# GNU Gener al Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# =========================
#
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
package TWiki::Plugins::XmlXslPlugin;

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
            "Version mismatch between XmlXslPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin preferences, the variable defined by:
    $exampleCfgVar = &TWiki::Func::getPreferencesValue("XMLXSLPLUGIN_EXAMPLE")
      || "default";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("XMLXSLPLUGIN_DEBUG") || 1;

# Plugin correctly initialized
# writeDebug( "- TWiki::Plugins::XmlXslPlugin::initPlugin( $web.$topic ) is OK" );
    return 1;
}

sub writeDebug {
    &TWiki::Func::writeDebug(@_) if $debug;
}

# =========================
sub endRenderingHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    #  writeDebug( "- XmlXslPlugin::endRenderingHandler( $web.$topic )" );
    # in here because we don't want our output HTML escaped.
    return unless ( $_[0] =~ /%XMLXSLTRANSFORM/os );

    my $xmlstring = &getScriptGenericText();
    my $ctr       = 0;
    $_[0] =~
      s/%XMLXSLTRANSFORM{(.*)}%/&applyXmlToXsl($1, $ctr++, $xmlstring)/geo;

    $_[0] = $xmlstring . "</SCRIPT>" . $_[0];

    # This handler is called by getRenderedVersion just after the line loop
}

# =========================
sub applyXmlToXsl {

    #my ($theArgs) = @_;
    my $theArgs = $_[0];
    my $ctr     = $_[1];

    my $xmlsource = &TWiki::Func::extractNameValuePair( $theArgs, "xml" );
    my $xslsource = &TWiki::Func::extractNameValuePair( $theArgs, "xsl" );
    my $csssource = &TWiki::Func::extractNameValuePair( $theArgs, "css" ) || "";
    my $id        = &TWiki::Func::extractNameValuePair( $theArgs, "id" )
      || "id$ctr";    # must always start with a letter
    writeDebug(
        "apply: xmlsource='$xmlsource'\nxslsource='$xslsource'\nid='$id'\n");

    my $scriptfilename = 'script.txt';
    my $script         = "";
    my $xmldataisland  = "";
    my $xsldataisland  = "";

    if ( $csssource =~ /(^http|.css)/ ) {
        $cssisland = "<style type=\"text/css\" media=\"all\">
	\@import url($csssource);
</style>";
    }
    else {

        #get the web name and the topic name
        my ( $xmlWebName, $xmlTopicName ) = getWebTopic($xmlsource);

        #check if the topic exists
        my $xmlTopicFile =
          &TWiki::Func::topicExists( $xmlWebName, $xmlTopicName );
        if ($xmlTopicFile) {

            #the topic does exist so read from the file
            my ( $xmlTopicMeta, $xmlTopicText ) =
              &TWiki::Func::readTopic( $xmlWebName, $xmlTopicName );
            $cssisland = "<style type=\"text/css\" media=\"all\">
<!--
$xmlTopicText
-->
</style>";
        }
        else {

            #the topic does not exist so put in anything
            $cssisland = "";
        }
    }
    if ( $xmlsource =~ /(^http|.xml|.xsl)/ ) {
        $xmldataisland =
          "<!--Remote XML source-->\n<XML id=\"$id\" src=\"$xmlsource\"></XML>";
    }
    else {

        #get the web name and the topic name
        my ( $xmlWebName, $xmlTopicName ) = getWebTopic($xmlsource);

        #check if the topic exists
        my $xmlTopicFile =
          &TWiki::Func::topicExists( $xmlWebName, $xmlTopicName );
        if ($xmlTopicFile) {

            #the topic does exist so read from the file
            my ( $xmlTopicMeta, $xmlTopicText ) =
              &TWiki::Func::readTopic( $xmlWebName, $xmlTopicName );
            $xmldataisland = "<XML id=\"$id\">$xmlTopicText</XML>";
        }
        else {

            #the topic does not exist so put in anything
            $xmldataisland =
"<font size='+2'>The XML you specified, $xmlsource, does not exist </font>";
        }
    }
    if ( $xslsource =~ /(^http|.xml|.xsl)/ ) {
        $xsldataisland = "<XML id=\"style$id\" src=\"$xslsource\"></XML>";
    }
    else {

        #get the web name and the topic name
        my ( $xslWebName, $xslTopicName ) = getWebTopic($xslsource);

        #check if the topic exists
        my $xslTopicFile =
          &TWiki::Func::topicExists( $xslWebName, $xslTopicName );
        if ($xslTopicFile) {

            #the topic does exist so read from the file
            my ( $xslTopicMeta, $xslTopicText ) =
              &TWiki::Func::readTopic( $xslWebName, $xslTopicName );
            $xsldataisland = "<XML id=\"style$id\">$xslTopicText</XML>";
        }
        else {

            #the topic does not exist so put in just the XML
            $xsldataisland =
"<font size='+2'>The XSL you specified, $xslsource, does not exist </font>";
        }
    }

    #get the script
    $script = getScriptText($id);

    #create division
    $division = "<DIV id=\"showResult$id\"></DIV>";

    $_[2] .=
      "\n<!--XMLASXSLSCRIPT START-->\n$script\n<!--XMLASXSLSCRIPT END-->\n";
    return
"\n<!--XMLASXSL START-->\n<!--CSS START-->\n$cssisland\n<!--CSS END-->\n<!--XMLDATAISLAND START-->\n$xmldataisland\n<!--XMLDATAISLAND END-->\n<!--XSLDATAISLAND START-->$xsldataisland\n<!--XSLDATAISLAND END-->\n<!--DIVISION START-->$division\n<!--DIVISION END-->\n<!--XMLASXSL END-->\n";
}
##subroutine to open a sample file and return contents as string
sub openfile {
    open( STUFF, $_[0] ) or die "Cannot open $stuff for read :$!";
    my $tempstring = "";
    while (<STUFF>) {
        $tempstring = $tempstring . $_;
    }
    close STUFF;
    return $tempstring;
}

# =========================
# get the web an topic name from fully qualified topic name
# This needs to be added to TWiki::Func
# =========================
sub getWebTopic {
    return &TWiki::Func::normalizeWebTopicName( $web, @_ );
}

sub getScriptGenericText {
    my ($sourceId) = @_;
    $sourceId = $sourceId || "";
    my $script = <<'END';
<SCRIPT event="onload" for="window"> // used to be  , but this causes problems if two invocations on the same page.
// Parse error formatting function
function reportParseError%SOURCE%(error)
{
	var s = "";
	for (var i=1; i<error.linepos; i++) {
    		s += " ";
  	}
  	r = "<font face=Verdana size=2><font size=4>XML Error loading '" + 
      	error.url + "'</font>" +
      	"<P><B>" + error.reason + 
      	"</B></P></font>";
  	if (error.line > 0)
    		r += "<font size=3><XMP>" +
    	"at line " + error.line + ", character " + error.linepos +
    	"\n" + error.srcText +
    	"\n" + s + "^" +
    	"</XMP></font>";
  	return r;
}

// Runtime error formatting function
function reportRuntimeError%SOURCE%(exception)
{
  	return "<font face=Verdana size=2><font size=4>XSL Runtime Error</font>" +
      	"<P><B>" + exception.description + "</B></P></font>";
}
END
    $script =~ s/%SOURCE%/$sourceId/g;
    return $script;
}

sub getScriptText {
    my ($sourceId) = @_;
    my $script = <<'END';

if (%SOURCE%.parseError.errorCode != 0)
	result = reportParseError%SOURCE%(%SOURCE%.parseError);
else {
      	if (style%SOURCE%.parseError.errorCode != 0)
        	result = reportParseError%SOURCE%(style%SOURCE%.parseError);
     	else {
        	try {
          		result = %SOURCE%.transformNode(style%SOURCE%.XMLDocument);
        	}catch (exception) {
          		result = reportRuntimeError%SOURCE%(exception);
        	}
      	}
}
// insert the results into the page
showResult%SOURCE%.innerHTML = result;
END
    $script =~ s/%SOURCE%/$sourceId/g;
    return $script;
}
1;
