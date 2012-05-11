# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 Peter Thoeny, peter@thoeny.org
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::StopWikiWordLinkPlugin;

use strict;

use vars qw( $VERSION $RELEASE $debug $pluginName $stopWordsRE );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Name of this Plugin, only used in this module
$pluginName = 'StopWikiWordLinkPlugin';

#===========================================================================
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # get debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    # Get plugin preferences variable:
    my $stopWords =
         TWiki::Func::getPreferencesValue("STOPWIKIWORDLINK")
      || TWiki::Func::getPreferencesValue("\U$pluginName\E_STOPWIKIWORDLINK")
      || 'UndefinedStopWikiWordLink';

    # build regex:
    $stopWords =~ s/\, */\|/go;
    $stopWords =~ s/^ *//o;
    $stopWords =~ s/ *$//o;
    $stopWords =~ s/[^A-Za-z0-9\|]//go;
    $stopWordsRE =
      "(^|[\( \n\r\t\|])($stopWords)";   # WikiWord preceeded by space or parens
    TWiki::Func::writeDebug("- $pluginName stopWordsRE: $stopWordsRE")
      if $debug;

    # Plugin correctly initialized
    return 1;
}

#===========================================================================
sub preRenderingHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    #my( $text, $pMap ) = @_;

    $_[0] =~ s/$stopWordsRE/$1<nop>$2/g;
}

1;
