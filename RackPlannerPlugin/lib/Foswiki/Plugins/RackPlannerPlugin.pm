# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
# For licensing info read LICENSE file in the Foswiki root.
package Foswiki::Plugins::RackPlannerPlugin;

use strict;

require Foswiki::Plugins::RackPlannerPlugin::RackPlanner;

use vars
  qw( $VERSION $RELEASE $debug $pluginName $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION );

# This should always be $Rev: 8670$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 8670$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '1.1';

#$REVISION = '1.005'; #dro# fixed links in 'connected to' or 'owner' field bug; added new attribute (clicktooltip...); added documentation
#$REVISION = '1.004'; #dro# fixed replacement in tooltipformat bug; improved tooltipformat; improved HTML rendering performance;  added and fixed documenation;
#$REVISION = '1.003'; #dro# fixed displayowner/displaynotes bug reported by TWiki:Main.PatrickTuite; added horizontal rendering feature requested by TWiki:Main.OlofStockhaus; added new attributes (columnwidth, textdir); fixed HTML validation bug;
#$REVISION = '1.002'; #dro# allowed multiple entries in a single unit; fixed rendering bug reported by TWiki:Main.SteveWray; fixed link color bug reported by TWiki:Main.SteveWray
#$REVISION = '1.001'; #dro# improved some features (added statistics); added attributes (rackstatformat, displayunitcolumn, unitcolumn*); renamed attribute statformat; fixed documentation; fixed tooltip bug; fixed conflict bug;
#$REVISION = '1.000'; #dro# initial version

# Name of this Plugin, only used in this module
$pluginName = 'RackPlannerPlugin';

$SHORTDESCRIPTION =
  "Render a rack overview (e.g. of 19'' computer racks) with HTML tables.";

$NO_PREFS_IN_TOPIC = 1;

$debug = 0;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.021 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    eval { &Foswiki::Plugins::RackPlannerPlugin::RackPlanner::initPlugin; };

    # Plugin correctly initialized
    return 1;
}

sub commonTagsHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    Foswiki::Func::writeDebug(
        "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    eval {
        $_[0] =~
s/%RACKPLANNER%/&Foswiki::Plugins::RackPlannerPlugin::RackPlanner::expand("",$_[0],$_[1],$_[2])/ge;
        $_[0] =~
s/%RACKPLANNER{(.*?)}%/&Foswiki::Plugins::RackPlannerPlugin::RackPlanner::expand($1, $_[0], $_[1], $_[2])/ge;

    };
    &Foswiki::Func::writeWarning($@) if $@;
}

1;
