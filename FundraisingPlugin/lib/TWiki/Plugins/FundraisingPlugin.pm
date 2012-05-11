# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
# $Revision$
#
# =========================
#
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   earlyInitPlugin         ( )                                     1.020
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   beforeCommonTagsHandler ( $text, $topic, $web )                 1.024
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   afterCommonTagsHandler  ( $text, $topic, $web )                 1.024
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   afterSaveHandler        ( $text, $topic, $web, $errors )        1.020
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional.
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# =========================
package TWiki::Plugins::FundraisingPlugin
  ;    # change the package name and $pluginName!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $pluginName
  $debug $twikiWebname
  $fundraisingEndDate $fundraisingGoal $fundraisingPledged $fundraisingDonateTopic
);

use Time::Local;

$VERSION    = '0.2.1';
$pluginName = 'FundraisingPlugin';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    # Get plugin preferences
    $fundraisingEndDate =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_ENDDATE") || "";
    $fundraisingGoal = TWiki::Func::getPreferencesValue("\U$pluginName\E_GOAL")
      || "0";
    $fundraisingPledged =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_PLEDGED") || "0";
    $fundraisingPreMsg =
         TWiki::Func::getPreferencesValue("\U$pluginName\E_PREMSG")
      || TWiki::Func::getWikiToolName() . " needs money";
    $fundraisingToGoMsg =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_TOGOMSG")
      || '$TOGO to go';
    $fundraisingPledgedMsg =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_PLEDGEDMSG")
      || "$fundraisingPledged";
    $fundraisingPostMsg =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_POSTMSG")
      || "before $fundraisingEndDate.";

    # Parse configuration variables that need parsing, do any calculus needed
    if ( "$fundraisingEndDate" =~ /^(\d+)-(\d+)-(\d+)$/ ) {
        $theYear  = $1;
        $theMonth = $2;
        $theDay   = $3;
    }
    $fundraisingToGo = $fundraisingGoal - $fundraisingPledged;
    $fundraisingToGoMsg =~ s/TOGO/$fundraisingToGo/;

    # Check configuration variables consistency and plugin activation
    $fundraisingActivated = 1
      unless ( ( timelocal( 0, 0, 0, $theDay, $theMonth, $theYear ) < time() )
        or ( $fundraisingToGo <= 0 ) );

    # Plugin correctly initialized?
    if ($debug) {
        if ( $fundraisingActivated == 1 ) {
            TWiki::Func::writeDebug(
"- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK"
            );
        }
        else {
            TWiki::Func::writeDebug(
"- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) will display nothing"
            );
        }
    }
    return 1;
}

# =========================
sub handleFundraisingMessage {
    my $message = "";

    if ($fundraisingActivated) {

        my $pledgedPercentage = $fundraisingPledged * 100 / $fundraisingGoal;
        my $toGoPercentage    = 100 - $pledgedPercentage;

        $message = qq{
<div class="fundraisingBanner" align="center" style="margin: 1em; font-size: 100%;">
  <div style="text-align: center">
    <div style="width: 100%; margin: 0 auto;">
      <div style="font-size: 90%">
        $fundraisingPreMsg
      </div>
      <div style="width: 100%; border: 1px solid gray; background-color: #ff5050; margin: .2em auto .2em">
        <div style="width: $pledgedPercentage%; float: left; background-color: #90ee90;">
          <p style="margin: 0;">
            &#160; <small>$fundraisingPledgedMsg</small>
          </p>
        </div>
        <div style="width: $toGoPercentage%; float: right; margin-left: -1px">
          <p style="margin: 0;">
            <strong><small>$fundraisingToGoMsg</small></strong>
          </p>
        </div>
        <div style="clear:both">
        </div>
      </div>
      <div style="font-size: 90%">
        $fundraisingPostMsg
      </div>
    </div>
  </div>
</div>
};
    }

    return $message;

}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
    $_[0] =~ s/%FUNDRAISINGMESSAGE%/&handleFundraisingMessage()/ge;
}

# =========================

1;
