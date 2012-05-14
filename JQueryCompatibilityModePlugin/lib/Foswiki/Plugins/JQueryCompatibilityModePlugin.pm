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

# =========================
package Foswiki::Plugins::JQueryCompatibilityModePlugin;

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
$RELEASE = '1.5';

# Short description of this plugin
# One line description, is shown in the %FoswikiWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION =
'Just the same as JqueryPlugin but using the compatibilty mode to provide use with other frameworks';

# Name of this Plugin, only used in this module
$pluginName = 'JQueryCompatibilityModePlugin';

# =========================

my $jqPluginName = $pluginName;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;
    my $pluginPubHome = Foswiki::Func::getPubUrlPath() . "/System/$pluginName";

# introducing a variable which helps the users use the current ScriptURL PubURL and other
# foswiki system variables in his javascripts
    if ( $Foswiki::cfg{Plugins}{JQueryCompatibilityModePlugin}
        {InitializeFoswikiVar} )
    {
        my $foswikiJSvars = "var Foswiki;\nif (!Foswiki) { Foswiki = {};}";
        $foswikiJSvars .=
          "\nFoswiki.systemWeb='" . $Foswiki::cfg{SystemWebName} . "';";
        $foswikiJSvars .=
          "\nFoswiki.userWeb='" . $Foswiki::cfg{UsersWebName} . "';";
        $foswikiJSvars .=
          "\nFoswiki.pubUrlPath='" . Foswiki::Func::getPubUrlPath() . "';";
        $foswikiJSvars .=
          "\nFoswiki.pubDir='" . Foswiki::Func::getPubDir() . "';";
        $foswikiJSvars .=
          "\nFoswiki.scriptSuffix='" . $Foswiki::cfg{ScriptSuffix} . "';";
        $foswikiJSvars .=
          "\nFoswiki.scriptUrlPath='" . $Foswiki::cfg{ScriptUrlPath} . "';";
        $foswikiJSvars .= "\nFoswiki.viewScript='"
          . Foswiki::Func::getScriptUrl( undef, undef, "view" ) . "';";
        $foswikiJSvars .= "\nFoswiki.jquery={};";
        my $output = "<script type='text/javascript'>$foswikiJSvars</script>";
        Foswiki::Func::addToHEAD( $jqPluginName . "_fowikiVars", $output );
    }

    if (
        $Foswiki::cfg{Plugins}{JQueryCompatibilityModePlugin}{AutoIncludeCore} )
    {
        my $output =
"<script language='javascript' type='text/javascript' src='$pluginPubHome/jquery.js'></script>";
        Foswiki::Func::addToHEAD( $jqPluginName . "_jq",
            $output, $jqPluginName . "_fowikiVars" );
        $output =
"<script language='javascript' type='text/javascript' src='$pluginPubHome/jquery_init.js'></script>";
        Foswiki::Func::addToHEAD( $jqPluginName . "_jq_init",
            $output, $jqPluginName . "_jq" );

        $output =
"<script language='javascript' type='text/javascript' src='$pluginPubHome/foswiki_specific/Func.js'></script>";
        Foswiki::Func::addToHEAD( $jqPluginName . "_fos_func",
            $output, $jqPluginName . "_jq_init" );
    }
    _initUITheme();
    addDialogScripts()
      if (
        $Foswiki::cfg{Plugins}{JQueryCompatibilityModePlugin}{DialogInclude} );
    addIncludedPlugins()
      if (
        $Foswiki::cfg{Plugins}{JQueryCompatibilityModePlugin}{IncludePlugins} );
    return 1;
}

sub addDialogScripts() {
    my $pluginPubHome =
      Foswiki::Func::getPubUrlPath() . "/System/$jqPluginName";
    my $output =
"<script language='javascript' type='text/javascript' src='$pluginPubHome/ui/ui.core.js'></script>";
    Foswiki::Func::addToHEAD( $jqPluginName . "_jqui.core",
        $output, $jqPluginName . "_jq_init" );

    $output =
"<script language='javascript' type='text/javascript' src='$pluginPubHome/ui/ui.draggable.js'></script>";
    Foswiki::Func::addToHEAD( $jqPluginName . "_jqui.draggable",
        $output, $jqPluginName . "_jqui.core" );

    $output =
"<script language='javascript' type='text/javascript' src='$pluginPubHome/ui/ui.dialog.js'></script>";
    Foswiki::Func::addToHEAD( $jqPluginName . "_jqui.dialog",
        $output, $jqPluginName . "_jqui.core" );

    $output =
"<script language='javascript' type='text/javascript' src='$pluginPubHome/ui/ui.resizable.js'></script>";
    Foswiki::Func::addToHEAD( $jqPluginName . "_jqui.resiz",
        $output, $jqPluginName . "_jqui.core" );

    if ( $Foswiki::cfg{Plugins}{JQueryCompatibilityModePlugin}
        {DialogDefaultSettingsInclude} )
    {
        $output =
"<script language='javascript' type='text/javascript' src='$pluginPubHome/foswiki_specific/dialogAPI_settings.js'></script>";
        Foswiki::Func::addToHEAD( $jqPluginName . "_foswiki.dialogAPI_settings",
            $output, $jqPluginName . "_jqui.dialog" );
    }

    $output =
"<script language='javascript' type='text/javascript' src='$pluginPubHome/foswiki_specific/dialogAPI.js'></script>";
    Foswiki::Func::addToHEAD(
        $jqPluginName . "_foswiki.dialogAPI",
        $output,
        $jqPluginName
          . "_foswiki.dialogAPI_settings" . ","
          . $pluginName
          . '_uithemename'
    );
}

sub _initUITheme {
    my $pluginPubHome = Foswiki::Func::getPubUrlPath() . "/System/$pluginName";

    my $themeName =
      trim( $Foswiki::cfg{Plugins}{JQueryCompatibilityModePlugin}{UITheme} );
    my $themeDir = $themeName;

    if ( $themeName eq "base" ) {
        $themeName = "";
    }
    my $output =
"<script type='text/javascript'>Foswiki.jquery.themeName='$themeName'</script>";
    Foswiki::Func::addToHEAD( $pluginName . '_uithemename', $output );
    if ( $themeName eq "" ) {
        $themeName = "ui";
        $themeDir  = "base";
    }
    if ( $Foswiki::cfg{Plugins}{JQueryCompatibilityModePlugin}{ThemeInclude} ) {
        $output = '<style type="text/css" media="all">@import '
          . "url('$pluginPubHome/themes/$themeDir/$themeName.all.css');</style>";
        Foswiki::Func::addToHEAD( $pluginName . '_uithemecss', $output );
    }
}

sub addIncludedPlugins() {
    my $pluginPubHome =
      Foswiki::Func::getPubUrlPath() . "/System/$jqPluginName";
    my @files = split ",",
      $Foswiki::cfg{Plugins}{JQueryCompatibilityModePlugin}{AutoIncludeFiles};

    # nothing to do. no files to inlcude
    return if ( @files eq 0 );
    foreach my $file (@files) {
        $file = trim($file);

# let strip the extensios to have a more unique string not being to long ( as addToHEAD does not include otherwise)
        my $id = substr( $file, -19, -7 );
        my $output =
"<script language='javascript' type='text/javascript' src='$pluginPubHome/$file'></script>";
        Foswiki::Func::addToHEAD( $jqPluginName . "_$id",
            $output,
            $jqPluginName . "_jq_init" . "," . $jqPluginName . "_jqui.dialog" );
    }
}

sub trim {
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

