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

package TWiki::Plugins::HideInEditModePlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $pluginName
  $debug $exampleCfgVar
);

$VERSION    = '$Rev$';
$pluginName = 'HideInEditModePlugin';    # Name of this Plugin

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

    $_[0] =~ s/%STARTHIDDEN%(.*?)%ENDHIDDEN%/$1/sg;
}

# =========================
sub beforeEditHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    my $topic = $_[1];
    my $web   = $_[2];

    TWiki::Func::writeDebug("- ${pluginName}::beforeEditHandler( $web.$topic )")
      if $debug;

# This handler is called by the edit script just before presenting the edit text
# in the edit box. Use it to process the text before editing.
# New hook in TWiki::Plugins $VERSION = '1.010'

    my $wikiUser = TWiki::Func::getWikiUserName();
    if (
        !TWiki::Func::checkAccessPermission(
            "HIDDEN", $wikiUser, $_[0], $topic, $web
        )
      )
    {

        # Shouldn't see hidden portion in edit mode
        if ( $_[0] =~ s/%STARTHIDDEN%(.*?)%ENDHIDDEN%//s ) {
            saveHiddenPortion( $topic, $web, $1 );
        }
    }
}

sub saveHiddenPortion {
    my ( $topic, $web, $hide ) = @_;

    my $wikiUser = TWiki::Func::getWikiUserName();
    $hide =~ s/&amp\;/&/go;
    $hide =~ s/&lt\;/</go;
    $hide =~ s/&gt\;/>/go;
    $filename = $wikiUser . '.' . time();
    TWiki::Func::setSessionValue( "hideineditmode", $filename );
    TWiki::Contrib::MoreFuncContrib::saveWorkFile( "HideInEditModePlugin",
        "$filename", $hide );
}

# =========================
sub beforeSaveHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    my $topic = $_[1];
    my $web   = $_[2];

    TWiki::Func::writeDebug("- ${pluginName}::afterEditHandler( $web.$topic )")
      if $debug;

 # This handler is called by the preview script just before presenting the text.
 # New hook in TWiki::Plugins $VERSION = '1.010'
    if ( $filename = TWiki::Func::getSessionValue("hideineditmode") ) {
        TWiki::Func::clearSessionValue("hideineditmode");
        $storage =
          TWiki::Contrib::MoreFuncContrib::readWorkFile( "HideInEditModePlugin",
            "$filename" );
        TWiki::Contrib::MoreFuncContrib::deleteWorkFile( "HideInEditModePlugin",
            "$filename" );

        if ($storage) {
            $_[0] = "$storage\n$_[0]";
        }
    }
}

1;
