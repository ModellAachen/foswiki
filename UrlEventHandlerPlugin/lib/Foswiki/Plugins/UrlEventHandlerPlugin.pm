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
# Author: EugenMayer

# =========================
package Foswiki::Plugins::UrlEventHandlerPlugin;

# =========================
use strict;
use warnings;
use Error qw(:try);
use Switch;

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
$RELEASE = '0.1';

# Short description of this plugin
# One line description, is shown in the %FoswikiWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION =
'Lets you react on url parameters and e.g. show a message for the user or redirect him somewhere, show a dialog etc.';

# Name of this Plugin, only used in this module
$pluginName = 'UrlEventHandlerPlugin';

# =========================

my $jqPluginName = 'JQueryCompatibilityModePlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;
    my $pluginPubHome = Foswiki::Func::getPubUrlPath() . "/System/$pluginName";

    my $query = Foswiki::Func::getCgiQuery();

    # the CGI object is not set, we cant do anything.
    return 1 if ( !defined $query );
    my $params = {};
    $params->{type}        = $query->param("ueh_type")        || "";
    $params->{errorCode}   = $query->param("ueh_errorcode")   || "";
    $params->{confirmCode} = $query->param("ueh_confirmcode") || "";
    $params->{messageCode} = $query->param("ueh_messagecode") || "";
    $params->{messageCode} = $query->param("ueh_messagecode") || "";
    $params->{dialogCode}  = $query->param("ueh_dialogcode")  || "";

    # if type is not set or all codes are missing
    if (
        $params->{type} eq ""
        || (  $params->{errorCode}
            . $params->{confirmCode}
            . $params->{messageCode}
            . $params->{dialogCode} eq "" )
        || ( $params->{type} eq "dialog" && $params->{dialogCode} eq "" )
      )
    {

        #nothing to do for us
        return 1;
    }

    switch ( $params->{type} ) {
        case 'alert' {
            _alertHandler($params);
        }
        case 'mdialog' {

            # TODO: not implemented yet
            #_messageDialogHandler($params);
        }
        case 'autodialog' {
            _dialogHandler($params);
        }
    }

    return 1;
}

sub _alertHandler {

    # TODO: if js is not enabled, add a div in the upper
    my $hashParams = shift;
    my $message =
      Foswiki::Func::loadTemplate( "ueh_alert", Foswiki::Func::getSkin() );
    $message = Foswiki::Func::expandCommonVariables($message);

    # remove all newlines, because alert cant handle them
    $message =~ s/\n//g;
    $message =~ s/\r//g;
    my $output =
"<script type='text/javascript'>\$j(document).ready( function () { alert('$message'); });</script>";
    Foswiki::Func::addToHEAD( $jqPluginName . "_alertmessage", $output );
}

sub _messageDialogHandler {
    my $hashParams = shift;
    my $dialogContent =
      Foswiki::Func::loadTemplate( "ueh_mdialog", Foswiki::Func::getSkin() );
    my $dialog = "$dialogContent";

#my $output = "<script type='text/javascript'>$alert</script>";
#Foswiki::Func::addToHEAD($jqPluginName."_alertmessage",$output, "JQueryCompatibilityModePlugin_jqui.dialog");
}

sub _dialogHandler {
    my $hashParams = shift;
    my $fetchurl =
      Foswiki::Func::loadTemplate( "ueh_autodialog", Foswiki::Func::getSkin() );
    $fetchurl = Foswiki::Func::expandCommonVariables($fetchurl);
    $fetchurl =~ s/\n//g;
    $fetchurl =~ s/\r//g;
    my $output =
"<script type='text/javascript'>\$j(document).ready( function () { show_dialog('#defaultDialog','$fetchurl','Dialog',true,600,600); });</script>";
    Foswiki::Func::addToHEAD( $jqPluginName . "_autodialog",
        $output, $jqPluginName . "_foswiki.dialogAPI" );
}
