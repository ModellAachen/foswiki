#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2005 Alex alex-kane@users.sourceforge.net
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
# This is a PatentLinkPlugin TWiki plugin.
# See %SYSTEMWEB%.PatentLinkPlugin for details.
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
package TWiki::Plugins::PatentLinkPlugin;    # change the package name!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  $patentUrl01 $patentUrl02 $patentUrl03 $patentApplicationUrl01 $patentApplicationUrl02 $patentApplicationUrl03 $patentText $patentApplicationText $patentImgUrl $patentApplicationImgUrl
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::PatentLinkPlugin::initPlugin is OK")
      if $debug;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between PatentLinkPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin preferences, the variable defined by:
    # Patent URL pref's see "http://patft.uspto.gov/netahtml/srchnum.htm";
    $patentUrl01 =
"http://patft.uspto.gov/netacgi/nph-Parser?Sect1=PTO1&Sect2=HITOFF&d=PALL&p=1&u=/netahtml/srchnum.htm&r=1&f=G&l=50&s1=";

# $patentUrl01 = &TWiki::Func::getPreferencesValue( "PATENTLINKPLUGIN_PATENTURL01" )  || "http://patft.uspto.gov/netacgi/nph-Parser?Sect1=PTO1&Sect2=HITOFF&d=PALL&p=1&u=/netahtml/srchnum.htm&r=1&f=G&l=50&s1=";
    $patentUrl02 = ".WKU.&OS=PN/";

# $patentUrl02 = &TWiki::Func::getPreferencesValue( "PATENTLINKPLUGIN_PATENTURL02" )  || ".WKU.&OS=PN/";
    $patentUrl03 = "&RS=PN/";

# $patentUrl03 = &TWiki::Func::getPreferencesValue( "PATENTLINKPLUGIN_PATENTURL03" )  || "&RS=PN/";
# Patent Application URL pref's see "http://appft1.uspto.gov/netahtml/PTO/srchnum.html";
    $patentApplicationUrl01 =
"http://appft1.uspto.gov/netacgi/nph-Parser?Sect1=PTO1&Sect2=HITOFF&d=PG01&p=1&u=%2Fnetahtml%2FPTO%2Fsrchnum.html&r=1&f=G&l=50&s1=%22";

# &TWiki::Func::getPreferencesValue( "PATENTLINKPLUGIN_PATENTAPPURL01" )  || "http://appft1.uspto.gov/netacgi/nph-Parser?TERM1=";
    $patentApplicationUrl02 = "%22.PGNR.&OS=DN/";

# &TWiki::Func::getPreferencesValue( "PATENTLINKPLUGIN_PATENTAPPURL02" )  || "&Sect1=PTO1&Sect2=HITOFF&d=PG01&p=1&u=%2Fnetahtml%2FPTO%2Fsrchnum.html&r=0&f=S&l=50";
    $patentApplicationUrl03 = "&RS=DN/";

#    $milestoneBugListUrl = &TWiki::Func::getPreferencesValue( "PATENTLINKPLUGIN_MILESTONEBUGLISTURL" )  || "http://localhost/bugzilla/buglist.cgi?";
    $patentImgUrl =
      &TWiki::Func::getPreferencesValue("PATENTLINKPLUGIN_PATENTIMGURL")
      || "%S%";
    $patentApplicationImgUrl =
      &TWiki::Func::getPreferencesValue("PATENTLINKPLUGIN_PATENTAPPIMGURL")
      || "%I%";
    $patentText =
      &TWiki::Func::getPreferencesValue("PATENTLINKPLUGIN_PATENTTEXT")
      || "Patent #";
    $patentApplicationText =
      &TWiki::Func::getPreferencesValue("PATENTLINKPLUGIN_PATENTAPPTEXT")
      || "Patent Application #";

#    $milestoneBugListText = &TWiki::Func::getPreferencesValue( "PATENTLINKPLUGIN_MILESTONEBUGLISTEXT" ) || "Buglist for Milestone ";
#     $myBugListText = &TWiki::Func::getPreferencesValue( "PATENTLINKPLUGIN_MYBUGLISTEXT" ) || "Buglist for ";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("PATENTLINKPLUGIN_DEBUG");

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::PatentLinkPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug(
        "- PatentLinkPlugin::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%
    $_[0] =~ s/%PATENT\{(.+)\}%/&PatentShowLink($1)/geo;
    $_[0] =~ s/%PATENTAPP\{([0-9]+)\}%/&PatentApplicationShowLink($1)/geo;

    #    $_[0] =~ s/%BUGLIST\{(.+)\}%/&BugzillaShowMilestoneBugList($1)/geo;
    #    $_[0] =~ s/%MYBUGS\{(.+)\}%/&BugzillaShowMyBugList($1)/geo;
}

sub PatentShowLink {
    my ($patentID) = @_;
    ## display a patent img and the US Patents and Tradmarks Office url
    # id is a comma-separated number. E.g., 6,887,385
    $bugID =~ s/\s*(\S*)\s*/$1/;
    return
"$patentImgUrl [[$patentUrl01$patentID$patentUrl02$patentID$patentUrl03$patentID][$patentText$patentID]]";
}

sub PatentApplicationShowLink {
    my ($patentAppID) = @_;
    ## display a patent application img and the US Patents and Tradmarks Office url
    $bugID =~ s/\s*(\S*)\s*/$1/;
    return
"$patentApplicationImgUrl [[$patentApplicationUrl01$patentAppID$patentApplicationUrl02$patentAppID$patentApplicationUrl03$patentAppID][$patentApplicationText$patentAppID]]";
}

# sub BugzillaShowMilestoneBugList{
#    my ($mID) = @_;
#    ## display a bug img and a bugzilla milesteone bug list
#    $mID =~ s/\s*(\S*)\s*/$1/;
#    return "$bugImgUrl [[$milestoneBugListUrl"."target_milestone=".$mID."b&target_milestone=$mID][$milestoneBugListText $mID]]";
# }

# sub BugzillaShowMyBugList{
#    my ($mID) = @_;
#    ## display a bug img and a bugzilla milesteone bug list
#    return "$bugImgUrl [[$milestoneBugListUrl"."bug_status=NEW&bug_status=ASSIGNED&bug_status=REOPENED&email1=$mID&emailtype1=exact&emailassigned_to1=1&emailreporter1=1][$myBugListText $mID]]";
#  }
1;
