#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional.
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# =========================
package TWiki::Plugins::BugzillaLinkPlugin;    # change the package name!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  $bugUrl $milestoneBugListUrl $milestoneBugListText $bugText $bugImgUrl
);

$VERSION = '$Rev$';
$RELEASE = '1.300';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between BugzillaLinkPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin preferences

    $bugUrl = &TWiki::Func::getPreferencesValue("BUGZILLALINKPLUGIN_BUGURL")
      || "http://localhost/bugzilla/show_bug.cgi?id=";
    $bugImgUrl =
      &TWiki::Func::getPreferencesValue("BUGZILLALINKPLUGIN_BUGIMGURL")
      || "%SYSTEMWEB%/BugzillaLinkPlugin/bug.gif";
    $bugListUrl =
      &TWiki::Func::getPreferencesValue("BUGZILLALINKPLUGIN_BUGLISTURL")
      || "http://localhost/bugzilla/buglist.cgi?";

    $bugText = &TWiki::Func::getPreferencesValue("BUGZILLALINKPLUGIN_BUGTEXT")
      || "Bug #";
    $milestoneBugListText = &TWiki::Func::getPreferencesValue(
        "BUGZILLALINKPLUGIN_MILESTONEBUGLISTTEXT")
      || "Buglist for Milestone ";
    $keywordsBugListText =
      &TWiki::Func::getPreferencesValue("BUGZILLALINKPLUGIN_KEYWORDBUGLISTTEXT")
      || "Buglist for keyword(s) ";
    $myBugListText =
      &TWiki::Func::getPreferencesValue("BUGZILLALINKPLUGIN_MYBUGLISTTEXT")
      || "Buglist for user ";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("BUGZILLAPLUGIN_DEBUG");

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::BugzillaLinkPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug(
        "- BugzillaLinkePlugin::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%
    $_[0] =~ s/%BUG\{([0-9]+)\}%/&BugzillaShowBug($1)/geo;
    $_[0] =~ s/%BUGLISTMS\{(.+)\}%/&BugzillaShowMilestoneBugList($1)/geo;
    $_[0] =~ s/%BUGLISTKEY\{(.+)\}%/&BugzillaShowKeywordsBugList($1)/geo;
    $_[0] =~ s/%MYBUGS\{(.+)\}%/&BugzillaShowMyBugList($1)/geo;
}

sub BugzillaShowBug {
    my ($bugID) = @_;
    ## display a bug img and the bugzilla url
    $bugID =~ s/\s*(\S*)\s*/$1/;
    return "$bugImgUrl [[$bugUrl$bugID][$bugText$bugID]]";
}

sub BugzillaShowMilestoneBugList {
    my ($mID) = @_;
    ## display a bug img and a bugzilla milesteone bug list
    $mID =~ s/\s*(\S*)\s*/$1/;
    return
        "$bugImgUrl [[$bugListUrl"
      . "target_milestone="
      . $mID
      . "b&target_milestone=$mID][$milestoneBugListText $mID]]";
}

sub BugzillaShowKeywordsBugList {
    my ($keyWords) = @_;

    # Determine if AND-type or OR-type search
    my $type = "allwords";
    $keyWords =~ s/\s*(\S*)\s*/$1/;
    $keyWordsUse = $keyWords;
    if ( $_[0] =~ m/\w+,\w+/ ) {
        $type = "anywords";
        $keyWordsUse =~ s/,/+/;
    }
    return "$bugImgUrl [[$bugListUrl"
      . "keywords_type=$type&keywords=$keyWordsUse][$keywordsBugListText \"$keyWords\"]]";
}

sub BugzillaShowMyBugList {
    my ($mID) = @_;
    ## display a bug img and a bugzilla milesteone bug list
    return "$bugImgUrl [[$bugListUrl"
      . "bug_status=NEW&bug_status=ASSIGNED&bug_status=REOPENED&email1=$mID&emailtype1=exact&emailassigned_to1=1&emailreporter1=1][$myBugListText $mID]]";
}
1;
