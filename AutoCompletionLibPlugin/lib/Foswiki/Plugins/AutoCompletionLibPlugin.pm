# This script Copyright (c) 2008 Impressive.media
# and distributed under the GPL (see below)
#
# Based on parts of GenPDF, which has several sources and authors
# This script uses html2pdf as backend, which is distributed under the LGPL
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

# =========================
package Foswiki::Plugins::AutoCompletionLibPlugin;

# =========================
use strict;
use warnings;
use Error qw(:try);

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package.
use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

# This should always be $Rev: 12445$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 12445$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '0.6';

# Short description of this plugin
# One line description, is shown in the %FoswikiWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION =
'Providing librarys and functionalitys to use easy javascript autocompletion for the user interface';

# Name of this Plugin, only used in this module
$pluginName = 'AutoCompletionLibPlugin';

# =========================
my $jqPluginName = "JQueryCompatibilityModePlugin";

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    return 1
      if ( !$Foswiki::cfg{Plugins}{AutoCompletionLibPlugin}{AutoInclude} );

    my $pluginPubHome = Foswiki::Func::getPubUrlPath() . "/System/$pluginName";
    my $output =
"<script type='text/javascript' src='$pluginPubHome/js/lib/jquery.ajaxQueue.js'></script>";
    Foswiki::Func::addToHEAD( $pluginName . "_jqueryajaxQueuejs",
        $output, $jqPluginName . "_jq_init" );

    $output =
"<script type='text/javascript' src='$pluginPubHome/js/lib/thickbox-compressed.js'></script>";
    Foswiki::Func::addToHEAD( $pluginName . "_thickboxjs",
        $output, $jqPluginName . "_jq_init" );

    $output =
"<script language='javascript' type='text/javascript' src='$pluginPubHome/js/jquery.autocomplete.pack.js'></script>";
    Foswiki::Func::addToHEAD( $pluginName . "_jqueryautocompletejs",
        $output, $jqPluginName . "_jq_init" );

    $output =
"<script type='text/javascript' src='$pluginPubHome/js/lib/jquery.bgiframe.min.js'></script>";
    Foswiki::Func::addToHEAD( $pluginName . "_bgiframejs",
        $output, $jqPluginName . "_jq_init" );

    $output =
"<link media='screen' rel='stylesheet' type='text/css' href='$pluginPubHome/css/jquery.autocomplete.css' />";
    Foswiki::Func::addToHEAD( $pluginName . "_autocompletecss",
        $output, $pluginName . "_jqueryautocompletejs" );

    $output =
"<link media='screen' rel='stylesheet' type='text/css' href='$pluginPubHome/css/thickbox.css' />";
    Foswiki::Func::addToHEAD( $pluginName . "_thickboxcss",
        $output, $pluginName . "_jqueryautocompletejs" );

    return 1;
}
