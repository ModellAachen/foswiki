#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2001 Dresdner Kleinwort Wasserstein
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
# This is the plugin is required by the Tiger skin

# =========================
package TWiki::Plugins::TigerSkinPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  $renderingWeb $isGuest $revsToShow $skin
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

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between TigerSkinPlugin and Plugins.pm");
        return 0;
    }

    $renderingWeb = $web;

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("TIGERSKINPLUGIN_DEBUG");

    $revsToShow =
      &TWiki::Func::getPreferencesValue("TIGERSKINPLUGIN_NUMREVISIONS") || 5;

    $isGuest = &TWiki::Func::isGuest();

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::TigerSkinPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

sub notHandle {
    my $skin = &TWiki::Func::getSkin();
    return ( $skin ne "tiger" && $skin ne "cat" );
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug(
        "- TigerSkinPlugin::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    return if ( notHandle() );

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    $_[0] =~ s/%LOGO%/&getIcon( $web, $topic, "tiger" )/geo;
    $_[0] =~ s/%TIGERLOGON%/&dispUser()/geo;
    $_[0] =~ s/%LEFTMENU%/&getMenu()/geo;
    $_[0] =~ s/%SHOWALL%/&showMenu("all")/geo;
    $_[0] =~ s/%SHOWVIEW%/&showMenu("view")/geo;
}

# =========================
sub dispUser    # conditional on presence of SessionPlugin
{
    my $dispUser = "";
    if (
        &TWiki::Func::topicExists( &TWiki::Func::getTwikiWebname(),
            "SessionPlugin" )
        && $isGuest
      )
    {
        $dispUser = "%SESSIONLOGON%";
    }
    else {
        my $wikiName = &TWiki::Func::getWikiName();
        my $mainWeb  = &TWiki::Func::getMainWebname();
        $dispUser =
            "<A class=logon href=\""
          . &TWiki::Func::getScriptUrl( $mainWeb, $wikiName, "view" )
          . "\">$wikiName</a>";
    }

    return $dispUser;
}

# =================================
sub showMenu {
    my ($scope) = @_;

    my $res = "on";
    if ( $scope eq "view" ) {
        $res = "none";
    }

# Only do check if there are permission set on this Web or if user logged on already
    my $perm = TWiki::Func::permissionsSet($web);
    if ( $perm || !$isGuest ) {
        my $auth = TWiki::Func::checkAccessPermission( "change",
            &TWiki::Func::getWikiUserName, "", $topic, $web );

        if ( !$auth ) {
            if ( $scope eq "all" ) {
                $res = "none";
            }
            else {
                $res = "on";
            }
        }
    }

    return $res;
}

# ===============================
sub getMenu {
    my ( $menu, $meta );

    if ( TWiki::Func::topicExists( $web, "WebMenu" ) ) {
        ( $meta, $menu ) = &TWiki::Func::readTopic( $web, "WebMenu" );
    }
    else {
        my $twikiWebname = &TWiki::Func::getTwikiWebname();
        ( $meta, $menu ) = &TWiki::Func::readTopic( $twikiWebname, "WebMenu" );
    }

    my $res = "<ul>\n";

    my $thisWeb      = "";
    my $defaultItems = "";

    $menu =~ s/\r\n/\n/go;
    $menu =~ s/^\s*#.*$//gom;
    if ( $menu =~ s/\*\sSET DEFAULTITEMS\s=\s(.*)$//om ) {
        $defaultItems = $1;
        $defaultItems =~ s/,/\n/go;
        $menu         =~ s/%DEFAULTITEMS%/$defaultItems/gom;
    }

    my $firstOuter      = "on";
    my $firstWeb        = "on";
    my $outerVisibility = "clsItemsHideOuter";
    my @webList         = ();
    foreach ( split /\n/, $menu ) {
        if (/%OUTER{([^}]*)}%/o) {
            my $args    = $1;
            my $name    = TWiki::Func::extractNameValuePair( $args, "name" );
            my $linkWeb = TWiki::Func::extractNameValuePair( $args, "linkweb" );
            my $linkTopic =
              TWiki::Func::extractNameValuePair( $args, "linktopic" );
            my $linkUrl = TWiki::Func::getViewUrl( $linkWeb, $linkTopic );
            my $webList = TWiki::Func::extractNameValuePair( $args, "weblist" );
            if ( $webList =~ /\b$web\b/ ) {
                $outerVisibility = "clsItemsShowOuter";
            }
            else {
                $outerVisibility = "clsItemsHideOuter";
            }
            if ( !$firstOuter ) {
                $res .= "</ul></ul></ul>\n";
            }
            $firstOuter = "";
            $firstWeb   = "on";
            $res .= "<ul>\n";
            $res .=
"  <li class=\"clsShowHideOuter\"><A class=clsHeadingOuter href=\"$linkUrl\">$name</A></li>\n";
        }
        elsif (/%WEB{([^}]*)}%/o) {
            my $args   = $1;
            my $name   = TWiki::Func::extractNameValuePair( $args, "name" );
            my $home   = TWiki::Func::extractNameValuePair( $args, "home" );
            my $expand = TWiki::Func::extractNameValuePair( $args, "expand" );
            $home =~ /([^.]+)\.([^.]+)/o;
            my $startTopic = "WebHome";
            if ($2) {
                $thisWeb    = $1;
                $startTopic = $2;
            }
            else {
                $thisWeb = $home;
            }
            if ( !$firstWeb ) {
                $res .= "    </ul></ul>\n";
            }
            $firstWeb = "";
            my $visibility = "clsItemsHide";
            if ( $thisWeb eq $web || $expand eq "always" ) {
                $visibility = "clsItemsShow";
            }
            my $webType = "clsShowHide";
            if ( $expand eq "never" ) {
                $visibility = "clsItemsHide";
                $webType    = "clsNoExpand";
            }
            $res .= "    <ul class=\"$outerVisibility\">\n";
            $res .=
"      <li class=\"$webType\"><a class=\"clsHeading\" href=\"%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/$thisWeb/$startTopic\">$name</a></li>\n";
            $res .= "        <ul class=\"$visibility\">\n";
        }
        elsif (/%ITEM{([^}]*)}%/o) {
            my $args  = $1;
            my $name  = TWiki::Func::extractNameValuePair( $args, "name" );
            my $topic = TWiki::Func::extractNameValuePair( $args, "topic" );
            if ( !$topic ) {
                $topic = $name;
            }
            $res .=
"          <li><a class=clsItem href=\"%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/$thisWeb/$topic\">$name</A></li>\n";
        }
    }

    $res .= "</ul></ul></ul>\n";

    return $res;
}

# ============================
sub getIcon {
    my ( $web, $topic, $skin ) = @_;

    my $icon = "";

    if ( !$skin ) {
        $skin = "tiger";
    }

    my $file = &TWiki::Func::getPubDir() . "/$web/logo.gif";
    my $url  = &TWiki::Func::getPubUrlPath() . "/$web/logo.gif";
    if ( !-e $file ) {
        $url =
            &TWiki::Func::getPubUrlPath() . "/"
          . &TWiki::Func::getTwikiWebname()
          . "/TigerSkin/logo.gif";
    }

    $icon =
"<a href=\"%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/$web/WebHome\" title=\"$web Web Home\"><IMG height=\"40\" border=0 src=\"$url\"></a>";

    return $icon;
}

# =========================
sub startRenderingHandler {
### my ( $text, $newweb, $meta ) = @_;   # do not uncomment, use $_[0], $_[1] instead

#&TWiki::Func::writeDebug( "- TigerSkinPlugin::startRenderingHandler( $_[1] )" ) if $debug;
# This handler is called by getRenderedVersion just before the line loop
    return if ( notHandle() );

    $_[0] =~ s/%TIGERREVS%/&tigerRevs( $meta )/geo;
}

# =========================
sub tigerRevs {
    my ($meta) = @_;

    my ( $revdate, $revuser, $maxrev ) =
      &TWiki::Func::getRevisionInfo( $web, $topic, $meta, "isoFormat" );

    my $query = &TWiki::Func::getCgiQuery();
    my $rev   = $query->param("rev");

    my $topicExists = &TWiki::Func::topicExists( $web, $topic );
    if ($topicExists) {
        if ($rev) {
            $rev =~ s/1\.//go;    # cut major
            if ( $rev < 1 )       { $rev = 1; }
            if ( $rev > $maxrev ) { $rev = $maxrev; }
        }
        else {
            $rev = $maxrev;
        }

    }
    else {
        $rev = 1;
    }

    my $i         = $maxrev;
    my $j         = $maxrev;
    my $revisions = "";
    my $breakRev  = 0;
    if ( ( $revsToShow > 0 ) && ( $revsToShow < $maxrev ) ) {
        $breakRev = $maxrev - $revsToShow + 1;
    }
    $split   = " </td></tr> <tr class=menuLine><td>";
    $split1  = "</td><td>";
    $anchor  = "<a class=menuItem ";
    $anchor1 = "<a class=menuItemDiff ";
    if ( ($revsToShow) && ( $revsToShow < $maxrev ) ) {
        $breakRev = $maxrev - $revsToShow + 1;
    }
    while ( $i > 0 ) {
        if ( $i eq $rev ) {
            $revisions = "$revisions$split1 r1.$i";
        }
        else {
            $revisions =
"$revisions$split1$anchor title=\"View revision 1.$i\" href=\"%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%?rev=1.$i\">r1.$i</a>";
        }
        if ( $i != 1 ) {
            if ( $i == $breakRev ) {
                $revisions =
"$revisions$split$anchor1 title=\"Diff between specific versions\" href=\"%SCRIPTURLPATH%/oops%SCRIPTSUFFIX%/%WEB%/%TOPIC%?template=oopsrev&amp;param1=1.$maxrev\">&gt;...</a>";
                $i = 1;
            }
            else {
                $j = $i - 1;
                $revisions =
"$revisions$split$anchor1 title=\"Diff between 1.$i & 1.$j\" href=\"%SCRIPTURLPATH%/rdiff%SCRIPTSUFFIX%/%WEB%/%TOPIC%?rev1=1.$i&amp;rev2=1.$j\">&gt;</a>";
            }
        }
        $i--;
    }

    #TWiki::Func::writeDebug( "revisions is $revisions" );

    $revisions =
      &TWiki::Func::expandCommonVariables( $revisions, $topic, $web );

    return $revisions;
}

# =========================

1;

