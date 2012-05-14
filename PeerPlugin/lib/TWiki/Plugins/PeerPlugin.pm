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
# For increased performance, DISABLE (or comment) handlers you don't need.

# =========================

package TWiki::Plugins::PeerPlugin;    # change the package name!!!

# =========================
use vars qw( $web $topic $user $installWeb $VERSION $RELEASE
  $myConfigVar %wikiToUserList $mainWebname
  $linkIcon $ratingSuffix
  $listIconPrefix $listIconHeight $listIconWidth
  $ratingIconPrefix $ratingIconHeight $ratingIconWidth);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# =========================
use TWiki::Plugins::PeerPlugin::Review;

# =========================

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # Get preferences
    $linkIcon = &TWiki::Func::getPreferencesValue("PEERPLUGIN_LINKICON") || "";
    $ratingSuffix = &TWiki::Func::getPreferencesValue("PEERPLUGIN_RATINGSUFFIX")
      || "";
    $listIconPrefix =
      &TWiki::Func::getPreferencesValue("PEERPLUGIN_LISTICONPREFIX") || "";
    $listIconHeight =
      &TWiki::Func::getPreferencesValue("PEERPLUGIN_LISTICONHEIGHT") || "13";
    $listIconWidth =
      &TWiki::Func::getPreferencesValue("PEERPLUGIN_LISTICONWIDTH") || "75";
    $ratingIconPrefix =
      &TWiki::Func::getPreferencesValue("PEERPLUGIN_RATINGICONPREFIX") || "";
    $ratingIconHeight =
      &TWiki::Func::getPreferencesValue("PEERPLUGIN_RATINGICONHEIGHT") || "13";
    $ratingIconWidth =
      &TWiki::Func::getPreferencesValue("PEERPLUGIN_RATINGICONWIDTH") || "75";

    return 1;
}

# peer review subroutines

# ==========================
sub prTestVal    #check input values in range 1-5
{
    my $prVal = shift;
    if ( $prVal >= 1 && $prVal <= 5 ) {
        return 0;
    }
    else {
        return 1;
    }
}

# ==========================
sub prTestTopic    #check if topic is an internal wiki page
{
    my $prTopic = shift;
    if ( $prTopic =~ /$TWiki::urlHost/ ) {
        return 1;
    }
    else {
        return 0;
    }
}

# ==========================
sub prDispPrTopicRev #format db revision (INT) to wiki rev 1.INT if internal wiki topic
{
    my $prTopic = shift;
    my $prRev   = shift;
    my $format  = shift;

    my ( $webName, $topicName ) = "";

    if ( &prTestTopic($prTopic) ) {
        if ( ( $prTopic =~ /.*\/(.*)\/(.*)/ ) ) {
            $webName   = $1;
            $topicName = $2;
        }
        if ( $format eq 'topicview' ) {
            return "$webName.$topicName revision 1.$prRev";
        }
        elsif ( $format eq 'userview' ) {
            return
              "[[$webName.$topicName][$webName.$topicName]] revision 1.$prRev";
        }
    }
    else {
        return "$prTopic";
    }
}

# ==========================
sub prDispPrDateTime    #format db datetime for wiki
{
    my $epSecs = shift;
    return ( &TWiki::formatTime($epSecs) );    #FIXME - do something!
}

# ===========================
sub prTitleColor                               #set color of title bar
{
    my $prRev = shift;
    if ( &prTestRev($prRev) eq "latest" ) {
        return ("%WEBBGCOLOR%");
    }
    else {
        return ("#cccccc");
    }
}

# ===========================
sub prTextColor                                #set class of body text
{
    my $prRev = shift;
    if ( &prTestRev($prRev) eq "latest" ) {
        return ("#000000");
    }
    else {
        return ("#999999");
    }
}

# ===========================
sub prTestRev    #test if review rev matches latest topic rev
{
    my $prRev = shift;

    #&TWiki::Func::writeDebug( "PeerPlugin: page rev is $TWiki::revision" );
    if ( $prRev == TWiki::Func::getCgiQuery()->param('prrevinfo') ) {
        return ("latest");
    }
    else {
        return ("oldngrey");
    }
}

# ============================
sub prLink {
    my ( $revdate, $revuser, $maxrev ) =
      &TWiki::Store::getRevisionNumber( $web, $topic );
    my $link = "";

    my $linkImg = "";
    if ($linkIcon) {
        $linkImg =
qq{<IMG align=absMiddle border=0 height=16 src=$linkIcon width=16 alt="review this topic">};
    }

    if ( &prTestUserTopic() ) {
        $link = qq{<span class=greyButton>Review $linkImg </span>};
    }
    else {
        $link =
qq{<a class=menuButton href="%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/%SYSTEMWEB%/PeerPluginView?prurl=%SCRIPTURL%/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%&prweb=%WEB%&prtopic=%TOPIC%&prrevinfo=$maxrev">Review $linkImg </a>};
    }
    return ($link);
}

# ============================
sub prObject {
    my $prTopic = TWiki::Func::getCgiQuery()->param('prtopic');
    my $prUrl   = TWiki::Func::getCgiQuery()->param('prurl');

    my $opText = "";

    if ( !$prTopic ) {
        $opText = $prUrl;
    }
    else {
        my $prWeb     = TWiki::Func::getCgiQuery()->param('prweb');
        my $prRevInfo = TWiki::Func::getCgiQuery()->param('prrevinfo');
        $opText = "[[$prUrl][$prTopic]]";
    }
    return ($opText);
}

# ============================
sub prFormUrl {
    return "%SCRIPTURL%/view%SCRIPTSUFFIX%/%SYSTEMWEB%/PeerPluginView";
}

# =========================
sub prDoForm {
    my $dbh = shift;

    my $prUrl   = TWiki::Func::getCgiQuery()->param('prurl');
    my $prWeb   = TWiki::Func::getCgiQuery()->param('prweb');
    my $prTopic = TWiki::Func::getCgiQuery()->param('prtopic');

    # add new review (if form filled)
    if ( TWiki::Func::getCgiQuery()->param('praction') eq "add" ) {

        #grab params from form
        my $fmQuality = TWiki::Func::getCgiQuery()->param('quality');
        my $fmRelevance = TWiki::Func::getCgiQuery()->param('relevance') || 0;
        my $fmCompleteness = TWiki::Func::getCgiQuery()->param('completeness')
          || 0;
        my $fmTimeliness = TWiki::Func::getCgiQuery()->param('timeliness') || 0;
        my $fmComment = TWiki::Func::getCgiQuery()->param('comment');

# check access permission - FIXME if we want to manage access permission on the PeerReviewView page - need one for each web
        my $changeAccessOK =
          &TWiki::Access::checkAccessPermission( "CHANGE",
            &TWiki::userToWikiName($user),
            $_[0], $topic, $web );
        if ( !$changeAccessOK ) {
            $opText .=
"<P><FONT color=red>You do not have permission to add reviews.</FONT></P>";

            # check param values
        }
        elsif ( &prTestVal($fmQuality) ) {
            $opText .=
"<P><FONT color=red>Please select a quality rating in the range 1-5.</FONT></P>";
        }
        elsif ( &prTestVal($fmRelevance) ) {
            $opText .=
"<P><FONT color=red>Please select a relevance rating in the range 1-5.</FONT></P>";

#FIXME - control these fields/values through config vars???
#} elsif( &prTestVal( $fmCompleteness ) ) {
#    $opText .= "<P><FONT color=red>Please select a completeness rating in the range 1-5.</FONT></P>";
#} elsif( &prTestVal( $fmQuality ) ) {
#    $opText .= "<P><FONT color=red>Please select a timeliness rating in the range 1-5.</FONT></P>";
        }
        elsif ( !$fmComment ) {
            $opText .=
"<P><FONT color=red>Please enter some text in the comment field.</FONT></P>";
        }
        else {
            my @rvItems = ();

            push( @rvItems, $user );
            push( @rvItems, $prUrl );
            push( @rvItems,
                TWiki::Func::getCgiQuery()->param('prrevinfo') || 0 );
            push( @rvItems, 1 );                #FIXME - Hardwire notify for now
            push( @rvItems, $fmQuality );
            push( @rvItems, $fmRelevance );
            push( @rvItems, $fmCompleteness );
            push( @rvItems, $fmTimeliness );
            push( @rvItems, $fmComment );

            my $error = &Review::rvAdd( $dbh, @rvItems );

            if ( !$error ) {
                $opText .=
"<P><FONT color=red>Thank you for adding a review. To edit your comments just submit a new review - only the most recent will be displayed.</FONT></P>";
            }
            else {
                $opText .= "<P><FONT color=red>$error</FONT></P>";
            }

            #&TWiki::Func::writeDebug( "PeerPlugin: Add rvItems is @rvItems" );
        }
    }
    return $opText;
}

# =========================
sub prList {
    my $dbh        = shift;
    my $attributes = shift;
    my $prUrl      = "";

    # get list format from TWiki var attributes
    my $format = TWiki::Func::extractNameValuePair( $attributes, "format" );
    if ( $format eq "topicview" || $format eq "userview" ) {
        $prUrl = TWiki::Func::getCgiQuery()->param('prurl');
    }
    else {
        $prUrl = TWiki::Func::extractNameValuePair( $attributes, "topic" );
    }

    if ( !$prUrl ) {
        return "No review list available.";
    }

    my $prWeb   = TWiki::Func::getCgiQuery()->param('prweb');
    my $prTopic = TWiki::Func::getCgiQuery()->param('prtopic');

    # load table template
    my $tbTemp = &TWiki::Func::readTemplate("peerview");
    my $tbText = "";
    my $opText = "";

    # get a list of refs to reviews
    my @rvList = ();
    if ( $format eq "topicview" ) {
        @rvList = &Review::rvList( $dbh, $format, "Topic" => $prUrl );
    }
    elsif ( $format eq "userview" ) {
        @rvList =
          &Review::rvList( $dbh, $format,
            "Reviewer" => &TWiki::wikiToUserName($prTopic) );
    }

    #&TWiki::Func::writeDebug( "PeerPlugin: rvList is @rvList" );

    #FIXME - add error handling
    foreach my $rv (@rvList) {
        $tbText = $tbTemp;

        $tbText =~ s/%PRREVIEWER%/&TWiki::userToWikiName( $rv->reviewer() )/geo;
        $tbText =~
s/%PRTOPICREV%/&prDispPrTopicRev( $rv->topic(), $rv->topicRev(), $format )/geo;
        $tbText =~ s/%PRDATETIME%/&prDispPrDateTime( $rv->epSecs( $dbh ) )/geo;
        $tbText =~ s/%PRTITLECOLOR%/&prTitleColor( $rv ->topicRev )/geo;
        $tbText =~ s/%PRTEXTCOLOR%/&prTextColor( $rv->topicRev )/geo;
        $tbText =~ s/%PRQUALITY%/{$rv->quality()}/geo;
        $tbText =~ s/%PRRELEVANCE%/{$rv->relevance()}/geo;
        $tbText =~ s/%PRCOMMENT%/{$rv->comment()}/geo;
        $tpText =~ s/%LISTICONPREFIX%/$listIconPrefix/geo;
        $tpText =~ s/%LISTICONHEIGHT%/$listIconHeight/geo;
        $tpText =~ s/%LISTICONWIDTH%/$listIconWidth/geo;

        $opText .= $tbText;
    }

    if ( !$opText ) {
        $opText = "No reviews have been written for this topic yet...";
    }
    return $opText;
}

# ============================
sub prRating {
    my $dbh     = shift;
    my $format  = "";
    my $prUrl   = "";
    my $prWeb   = "";
    my $prTopic = "";
    my $prUser  = "";
    my $rating  = 0;

    # handle url according to normal view or review
    if ( TWiki::Func::getCgiQuery()->param('prurl') ) {
        $prUrl = TWiki::Func::getCgiQuery()->param('prurl');
    }
    else {
        $prUrl =
            TWiki::Func::getCgiQuery()->url()
          . TWiki::Func::getCgiQuery()->path_info();
    }

    # test if url internal to wiki - then extract object web & topic
    if ( &prTestTopic($prUrl) && $prUrl =~ /.*\/(.*)\/(.*)/ ) {
        $prWeb   = $1;
        $prTopic = $2;
    }

    # find out if this is a personal topic
    if ( $prWeb eq $TWiki::mainWebname
        && exists( $TWiki::wikiToUserList{$prTopic} ) )
    {
        $format = "usertherm";
        $prUser = &TWiki::wikiToUserName($prTopic);
    }
    else {
        $format = "topictherm";
    }

    if ( $format eq "topictherm" ) {
        $rating = &Review::rvRating( $dbh, $format, "Topic" => $prUrl ) || 0;
    }
    elsif ( $format eq "usertherm" ) {
        $rating = &Review::rvRating( $dbh, $format, "Reviewer" => $prUser )
          || 0;
    }

    my $opText = "";
    if ( &prTestUserTopic() ) {
        $zero = "0";
        $opText =
qq{&nbsp;<img src="$ratingIconPrefix$zero.gif" width="$ratingIconWidth" height="$ratingIconHeight" border="0" alt="personal topic - review disabled">&nbsp;$ratingSuffix};
    }
    else {
        $opText =
qq{&nbsp;<img src="$ratingIconPrefix$rating.gif" width="$ratingIconWidth" height="$ratingIconHeight" border="0" alt="quality=$rating">&nbsp;$ratingSuffix};
    }

    return ($opText);
}

# =========================
sub prTestUserTopic

  # find out if this is a personal topic or the Wiki.PeerPluginUser topic
{
    if ( $web eq $TWiki::mainWebname
        && exists( $TWiki::wikiToUserList{$topic} ) )
    {
        return 1;
    }
    elsif ( $topic eq "PeerPluginUser" )    { return 1; }
    elsif ( $topic eq "PeerPluginForm" )    { return 1; }
    elsif ( $topic eq "PeerPluginView" )    { return 1; }
    elsif ( $topic eq "PeerPluginExtForm" ) { return 1; }
    elsif ( $topic eq "PeerPluginExtView" ) { return 1; }
    else                                    { return; }
}

# ============================
sub prDispStatsItem {

    # test if url internal to wiki - then extract object web & topic
    my $item   = shift;
    my $opText = "";

    if ( &prTestTopic($item) && $item =~ /.*\/(.*)\/(.*)/ ) {
        $prWeb   = $1;
        $prTopic = $2;
        $opText .= "[[$prWeb.$prTopic][$prWeb.$prTopic]] <br> ";
    }
    else {
        $opText .=
"[[%SCRIPTURL%/view%SCRIPTSUFFIX%/%SYSTEMWEB%/PeerPluginExtView?prurl=$item][Wiki:$item]] <br> ";
    }

    return $opText;
}

# ============================
sub prStats {
    my $dbh        = shift;
    my $attributes = shift;
    my $item       = "";
    my $opText     = "";
    my $prWeb      = "";
    my $prTopic    = "";

    my $atUrl = TWiki::Func::extractNameValuePair( $attributes, "web" );
    my $limit = TWiki::Func::extractNameValuePair( $attributes, "limit" ) || 10;

    if ( $atUrl ne "all" ) {
        $opText .= "Sorry - only stats for \"all\" webs supported.";

#FIXME - convert web list to params pair list for rvStats - I guess this would be an url mask that drives a db "like"
        return;
    }

#FIXME - may be better formed by using references - ie making the stats list be an object

    $opText .=
"| *Topic <br> Reviews:* | *Best <br> Rated <br> Topics:* | *Most <br> Reviewed <br> Topics:* | *Most <br> Active <br> Reviewers:* |\n";

    my ($rvCount) = &Review::rvStats( $dbh, 'count' );
    $opText .= "|  $rvCount |  ";

    my (@rvBestTen) = &Review::rvStats( $dbh, 'bestten', $limit );
    while (@rvBestTen) {
        $item = shift(@rvBestTen);
        $opText .= "$item ";
        $item = shift(@rvBestTen);
        $opText .= &prDispStatsItem($item);
    }
    $opText .= "|  ";

    my (@rvMostTen) = &Review::rvStats( $dbh, 'mostten', $limit );
    while (@rvMostTen) {
        $item = shift(@rvMostTen);
        $opText .= "$item ";
        $item = shift(@rvMostTen);
        $opText .= &prDispStatsItem($item);
    }
    $opText .= "|  ";

    my (@rvUserTen) = &Review::rvStats( $dbh, 'userten', $limit );
    while (@rvUserTen) {
        $item = shift(@rvUserTen);
        $opText .= "$item ";
        $item = shift(@rvUserTen);
        $item = &TWiki::userToWikiName($item);
        $opText .= "$item <br> ";
    }

    $opText .= "|";
    return ($opText);
}

# ========================
sub prExtUrl {
    return TWiki::Func::getCgiQuery()->param('prexturl')
      || "http://www.google.com/";
}

# ========================
sub prInclude {
    my $attributes = shift;
    my $item = TWiki::Func::extractNameValuePair( $attributes, "prurl" );

    &TWiki::Func::writeDebug("PeerPlugin: prInclude");

    if ( &prTestTopic($item) && $item =~ /.*\/(.*)\/(.*)/ ) {
        $prWeb   = $1;
        $prTopic = $2;
        my $opText =
          &TWiki::handleIncludeFile( "\"$prWeb.$prTopic\"", $topic, $web );
        return $opText;
    }
    else {
        return "<IFRAME NAME=content width=800 height=800 SRC=$item></IFRAME>";
    }
}

# =========================
sub prUserView {
    my $text =
qq{<a href="%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/%SYSTEMWEB%/PeerPluginUser?};
    $text .=
qq{prurl=%SCRIPTURL%/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%&prweb=%WEB%&prtopic=%TOPIC%&prrevinfo=$maxrev">};
    $text .= qq{ViewMyReviews</a>};
    return $text;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    #    print "PeerreviewPlugin::commonTagsHandler called<br>";

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    #&TWiki::Func::writeDebug( "PeerPlugin: opening DB connection" );
    # open db
    my $dbh = &Review::rvOpen();

    $_[0] =~ s/%PRDOFORM%/&prDoForm( $dbh )/geo;         #Must run before PRLIST
    $_[0] =~ s/<!--%PRLINK%-->/&prLink()/geo;
    $_[0] =~ s/%PRLIST{([^}]*)}%/&prList( $dbh, $1 )/geo;
    $_[0] =~ s/%PROBJECT%/&prObject()/geo;
    $_[0] =~ s/%PRFORMURL%/&prFormUrl()/geo;
    $_[0] =~ s/%PRURL%/TWiki::Func::getCgiQuery()->param( 'prurl' )/geo;
    $_[0] =~ s/%PRWEB%/TWiki::Func::getCgiQuery()->param( 'prweb' )/geo;
    $_[0] =~ s/%PRTOPIC%/TWiki::Func::getCgiQuery()->param( 'prtopic' )/geo;
    $_[0] =~ s/%PRREVINFO%/TWiki::Func::getCgiQuery()->param( 'prrevinfo' )/geo;
    $_[0] =~ s/<!--%PRRATING%-->/&prRating( $dbh )/geo;
    $_[0] =~ s/%PRSTATS{([^}]*)}%/&prStats( $dbh, $1 )/geo;
    $_[0] =~ s/%PREXTURL%/&prExtUrl()/geo;
    $_[0] =~ s/%PRINCLUDE{([^}]*)}%/&prInclude( $1 )/geo;
    $_[0] =~ s/%PRUSERVIEW%/&prUserView/geo;

    # close db
    &Review::rvClose($dbh);
}

# =========================
sub DISABLEstartRenderingHandler {
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    #    print "PeerreviewPlugin::startRenderingHandler called<br>";

    # This handler is called by getRenderedVersion just before the line loop

}

# =========================
sub DISABLEoutsidePREHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    #    print "PeerreviewPlugin::outsidePREHandler called<br>";

    # This handler is called by getRenderedVersion, in loop outside of <PRE> tag
    # This is the place to define customized rendering rules

}

# =========================
sub DISABLEinsidePREHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    #    print "PeerreviewPlugin::insidePREHandler called<br>";

    # This handler is called by getRenderedVersion, in loop inside of <PRE> tag
    # This is the place to define customized rendering rules

}

# =========================
sub DISABLEendRenderingHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    #    print "PeerreviewPlugin::endRenderingHandler called<br>";

    # This handler is called by getRenderedVersion just after the line loop

}

# =========================

1;

