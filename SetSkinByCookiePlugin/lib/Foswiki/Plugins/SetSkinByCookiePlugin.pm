#!/usr/local/bin/perl -wI.
#
# This script Copyright (c) 2008 Impressive.media
# and distributed under the GPL (see below)
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
# Author: Eugen Mayer

package Foswiki::Plugins::SetSkinByCookiePlugin;

use strict;

use Assert;
use HTTP::Cookies::Find;
use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev: 12445$';

$RELEASE = '0.2';

$SHORTDESCRIPTION  = ' ';
$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'SetSkinByCookiePlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiku::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    _checkCookieAndSetSkin(
        $Foswiki::cfg{Plugins}{SetSkinByCookiePlugin}{CookieName},
        $Foswiki::cfg{Plugins}{SetSkinByCookiePlugin}{Expire}
    );
    return 1;
}

sub _checkCookieAndSetSkin {
    my ( $cookieName, $expire ) = @_;
    my $query = Foswiki::Func::getCgiQuery();
    my $value = "";

    foreach my $name ( $query->cookie() ) {
        if ( $name eq $cookieName ) {
            $value = $query->cookie( '-name' => $name );
        }
    }

    return if ( $value eq "" );

# using > means, you want this skin to  be added to the current skin, but on the left side
# so being more important ( left side )
    if ( $value =~ /^<(.*)$/ ) {
        my $currentSkin = Foswiki::Func::getSkin();

        $value = "$1, $currentSkin" if ( $currentSkin ne "" );
    }

# same as above, but you want to add it as the most unimportant one ( right side )
    if ( $value =~ /^>(.*)$/ ) {
        my $currentSkin = Foswiki::Func::getSkin();

        $value = "$currentSkin, $1" if ( $currentSkin ne "" );
    }

    # if neiher < or > is used, the current Skins get overwritten completely

    Foswiki::Func::setPreferencesValue( "SKIN", $value );
    return;
}
1;
