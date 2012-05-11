# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2004-2006 Thomas Weigert, weigert@comcast.net
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
# Enhancements/Bugs
# 1.Need to give same flexibilities as in EditTablerowPlugin in terms of config
# Do we need to differentiate between changerows and addrows? Also, if no
# adding of rows is allowed, there should also be no copy/delete button?
# 2. No handling of footer yet
# 3. Need to differntiate between update and add
# 4. When changerows=off, should not delete or copy rows.

# =========================
package TWiki::Plugins::EditHiddenTablePlugin;

use strict;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug $pluginName
  $prefsInitialized $prefCHANGEROWS $prefEDITBUTTON $prefEDITLINK
);

$VERSION          = '$Rev: 0$';
$RELEASE          = 'Dakar';
$pluginName       = 'EditHiddenTablePlugin';    # Name of this Plugin
$prefsInitialized = 0;

use TWiki::Form;

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning(
            "This version of $pluginName works only with TWiki 4 and greater.");
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    $prefsInitialized = 0;

    # TW: disabled until migrated
    #    TWiki::Func::registerTagHandler( 'METATABLESEARCH', \&searchWeb,
    #                                     'context-free' );
    TWiki::Func::registerTagHandler( 'EDITHIDDENTABLE', \&handler,
        'context-free' );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug("- ${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

sub handler {

    unless ($prefsInitialized) {
        my $cgi = TWiki::Func::getCgiQuery();
        return unless $cgi;

        $prefCHANGEROWS = &TWiki::Func::getPreferencesValue("CHANGEROWS")
          || &TWiki::Func::getPreferencesValue(
            "EDITMETATABLEROWPLUGIN_CHANGEROWS")
          || 'on';
        $prefEDITBUTTON = &TWiki::Func::getPreferencesValue("EDITBUTTON")
          || &TWiki::Func::getPreferencesValue(
            "EDITMETATABLEROWPLUGIN_EDITBUTTON")
          || 'Edit table';
        $prefEDITLINK = &TWiki::Func::getPreferencesValue("EDITLINK")
          || &TWiki::Func::getPreferencesValue(
            "EDITMETATABLEROWPLUGIN_EDITLINK")
          || '';

        $TWiki::Plugins::EditHiddenTablePlugin::prefsInitialized = 1;
    }

    # on-demand inclusion
    eval 'use TWiki::Plugins::EditHiddenTablePlugin::Edit';
    die $@ if $@;
    TWiki::Plugins::EditHiddenTablePlugin::Edit::handleEditTableTag(@_);
}

sub searchWeb {

    # on-demand inclusion
    eval 'use TWiki::Plugins::EditHiddenTablePlugin::Search';
    die $@ if $@;
    TWiki::Plugins::EditHiddenTablePlugin::Search::handleTableSearchWeb(@_);
}

1;
