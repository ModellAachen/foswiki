#  *****************************************************************************
#
#   TypographyPlugin.pm
#   Improve typography of TML
#
#   Copyright (C) 2002, Eric Scouten
#   Started Sat, 07 Dec 2002
#   Copyright (c) 2009, Will Norris
#
#  *****************************************************************************
#
#   This program is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public License
#   as published by the Free Software Foundation; either version 2
#   of the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details, published at
#   http://www.gnu.org/copyleft/gpl.html
#
#  *****************************************************************************

package Foswiki::Plugins::TypographyPlugin;

use vars
  qw($web $topic $user $installWeb $VERSION $RELEASE $debug $doOldInclude $renderingWeb);

# This should always be $Rev$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# ******************************************************************************

sub initPlugin {

    ( $topic, $web, $user, $installWeb ) = @_;

    # Check for Plugins.pm versions.

    if ( $Foswiki::Plugins::VERSION < 1 ) {
        &Foswiki::Func::writeWarning(
            "Version mismatch between TypographyPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag.

    $debug = &Foswiki::Func::getPreferencesFlag("TYPOGRAPHYPLUGIN_DEBUG");

    # Plugin correctly initialized.

    &Foswiki::Func::writeDebug(
        "- Foswiki::Plugins::TypographyPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;

}

# ******************************************************************************

sub startRenderingHandler {

### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &Foswiki::Func::writeDebug(
        "- TypographyPlugin::startRenderingHandler( $_[1].$topic )")
      if $debug;

    my $userAgent = $ENV{'HTTP_USER_AGENT'} || "";

    # Render special character sequences.
    if ( $_[0] !~ /chgUpper/ )
    {    # Ugly hack to prevent UserRegistration page from breaking.
        $_[0] =~ s((?<=[^\w\-])\-\-\-(?=[^\w\-\+]))(&#8212;)go;         # emdash
        $_[0] =~ s((?<=[^\w\-])\-\-(?=[^\w\-\+]))(&#8211;)go;           # endash
        $_[0] =~ s((?<=\s)(&quot;|\")(?![^<]+>)(?![^<{]*}))(&#8220;)go; # ``
        $_[0] =~ s((&quot;|\")(?![^<]*>)(?![^<{]*}))(&#8221;)go;        # ''
        $_[0] =~ s((?<=\s)(&apos;|\')(?![^<]+>)(?![^<{]*}))(&#8216;)go; # `
        $_[0] =~ s((&apos;|\')(?![^<]+>)(?![^<{]*}))(&#8217;)go;        # '
    }
}

# ******************************************************************************

sub endRenderingHandler {

### my ($text) = @_;   # do not uncomment, use $_[0] instead

    &Foswiki::Func::writeDebug(
        "- TypographyPlugin::endRenderingHandler( $_[0] )")
      if $debug;

    # Patch out <expand> tags.

    $_[0] =~ s(\<expand\>(.*?)\</expand\>)(&renderExpandSection($1))geo;

}

# ******************************************************************************

sub renderExpandSection {

    my ($renderSection) = @_;

    &Foswiki::Func::writeDebug(
        "- TypographyPlugin::renderExpandSection( $renderSection )")
      if $debug;

    $renderSection =~
s(\b([A-Z]+[a-z]+[A-Z0-9]+[a-zA-Z0-9]*)\b(?![^<]+>)(?![^<{]*}))(&expandWikiWord($1))geo;

    return $renderSection;

}

# ******************************************************************************

sub expandWikiWord {

    my ($wikiWord) = @_;

    &Foswiki::Func::writeDebug(
        "- TypographyPlugin::expandWikiWord( $wikiWord )")
      if $debug;

    # Insert spaces between each part of WikiWord.

    $wikiWord =~ s(([a-z])([A-Z0-9]))($1 $2)go;
    $wikiWord =~ s(([0-9])([A-Z]))($1 $2)go;
    $wikiWord =~ s(([A-Z]{2})([A-Z][a-z]{2}))($1 $2)go;

    # Convert a few known words to lower case (proper English titling).

    $wikiWord =~ s(\bA(?=[A-Z]))(A )go;
    $wikiWord =~ s((.+)\bA\b)($1a)go;
    $wikiWord =~ s((.+)\bAnd\b)($1and)go;
    $wikiWord =~ s((.+)\bFrom\b)($1from)go;
    $wikiWord =~ s((.+)\bIn\b)($1in)go;
    $wikiWord =~ s((.+)\bOf\b)($1of)go;
    $wikiWord =~ s((.+)\bTo\b)($1to)go;
    $wikiWord =~ s((.+)\bThe\b)($1the)go;
    $wikiWord =~ s((.+)\bWith\b)($1with)go;

    # Expand a few known words with appropriate punctuation.
    $wikiWord =~ s(\bCouldnt\b)(Couldn&#8217;t)go;
    $wikiWord =~ s(\bYouve\b)(You&#8217;ve)go;

    &Foswiki::Func::writeDebug("-      expanded to $wikiWord") if $debug;

    return $wikiWord;

}

# ******************************************************************************

1;
