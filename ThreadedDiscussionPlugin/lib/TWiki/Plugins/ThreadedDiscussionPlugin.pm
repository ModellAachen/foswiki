# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
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
# =========================
package TWiki::Plugins::ThreadedDiscussionPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $translationToken $debug
  @tree $pos $pretxt $sectxt $postxt
  $threadcolor $iconSp $height $width $showLead $iconlocation $renderAsList
);

use CGI;
use TWiki::Contrib::EditContrib;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'ThreadedDiscussionPlugin';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    $listNr = 0 if ( !defined $listNr );

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub startRenderingHandler {
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug("- ${pluginName}::startRenderingHandler( $_[1] )")
      if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # Render here, not in commonTagsHandler so that lists produced by
    # Plugins, TOC and SEARCH can be rendered
    $_[0] =~
s/%DISCUSSION{(.*?)}%(([\n\r]+[^\t]{1}[^\n\r]*)*?)(([\n\r]+\t[^\n\r]*)+)/&handleRenderList($1, $2, $4, $_[1])/ges;
    $_[0] =~
s/%DISCUSSION{(.*?)}%([^\n\r]*?)([\n\r])/&handleRenderEmptyList($1, $2, $3)/ges;
    $_[0] =~ s/%DISCUSSIONDELETE%//ges;
}

# =========================
sub handleRenderEmptyList {
    my ( $theAttr, $thePre, $theTail ) = @_;

    my $focus = &TWiki::Func::extractNameValuePair( $theAttr, "focus" );
    my $depth = &TWiki::Func::extractNameValuePair( $theAttr, "depth" );
    my $int   = &TWiki::Prefs::formatAsFlag(
        TWiki::Func::extractNameValuePair( $theAttr, "interactive" ) )
      || "";

    $listNr++;

    return $thePre . &handleLine( $listNr, 0, 0 ) . $theTail;
}

sub handleRenderList {
    my ( $theAttr, $thePre, $theList, $theWeb ) = @_;

    my $focus = &TWiki::Func::extractNameValuePair( $theAttr, "focus" );
    my $depth = &TWiki::Func::extractNameValuePair( $theAttr, "depth" );
    my $int =
      &TWiki::Prefs::formatAsFlag(
        &TWiki::Func::extractNameValuePair( $theAttr, "interactive" ) )
      || "";
    my $noIcons = &TWiki::Prefs::formatAsFlag(
        TWiki::Func::extractNameValuePair( $theAttr, "noicons" ) )
      || "";
    $renderAsList =
         &TWiki::Func::extractNameValuePair($theAttr)
      || &TWiki::Func::getPreferencesValue("\U$pluginName\E_STYLE")
      || "list";
    $renderAsList = ( $renderAsList =~ /list/i ? 1 : 0 );

    return $thePre
      . renderThreadedDiscussion( $focus, $depth, $int, $theList, $theWeb,
        $noIcons );
}

sub renderThreadedDiscussion {
    my ( $theFocus, $theDepth, $interactive, $theText, $theWeb, $noIcons ) = @_;

    my $text = "";
    $listNr++;

    # Get preference values related to formatting
    my $attachUrl = TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath();
    $attachUrl .= "/$installWeb/DocumentGraphics";
    $threadcolor =
      ( &TWiki::Func::getPreferencesValue("\U$pluginName\E_THREADCOLOR")
          || "#FFFFFF" )
      unless $threadcolor;
    $iconlocation =
      ( &TWiki::Func::getPreferencesValue("\U$pluginName\E_ICONTOPIC")
          || "$attachUrl" )
      unless $iconlocation;
    $iconSp = &TWiki::Func::getPreferencesValue("\U$pluginName\E_SPACEICON")
      || "";
    ( $showLead, $width, $height, $iconSp ) = split( /, */, $iconSp );
    $iconSp = "$attachUrl/empty.gif" unless $iconSp;
    $iconSp = &handleTagsForIcons( $iconlocation . "/" . $iconSp );
    $width  = 16 unless ($width);
    $height = 16 unless ($height);
    $iconSp = fixImageTag( $iconSp, $width, $height );

    $editLabel = &TWiki::Func::getPreferencesValue("\U$pluginName\E_EDITLABEL")
      || "Edit";
    $editLabel = &handleTagsForIcons($editLabel);
    $commentLabel =
      &TWiki::Func::getPreferencesValue("\U$pluginName\E_COMMENTLABEL")
      || "Comment";
    $commentLabel = &handleTagsForIcons($commentLabel);

    if ($interactive) {
        $theFocus = &TWiki::Contrib::EditContrib::handleUrlParam("qfocus")
          if ( &TWiki::Contrib::EditContrib::handleUrlParam("nr") == $listNr );
        $theDepth = &TWiki::Contrib::EditContrib::handleUrlParam("qdepth")
          if ( &TWiki::Contrib::EditContrib::handleUrlParam("nr") == $listNr );

    }

    my ( $maxlvl, $result ) =
      &renderIconList( $theFocus, $theDepth, $theText, $noIcons );

#$result =~ s/%LINE{\s*([0-9]+)\s*,\s*([0-9]+)\s*,\s*([0-9]+)\s*}%/&handleLine($1, $2, $3)/ges;
    if ($interactive) {
        my $query = &TWiki::Func::getCgiQuery();

        $text = "<form action=\""
          . &TWiki::Func::getScriptUrl( $theWeb, $topic, "view" ) . "\">";
        $text .= "<input type=\"hidden\" name=\"nr\" value=\"$listNr\" />";
        $text .=
"<input type=\"submit\" value=\"Focus\" /><input type=\"text\" name=\"qfocus\" value=\""
          . $query->param("qfocus")
          . "\" size=\"20\" />";
        if ($maxlvl) {
            $text .= "&nbsp; Limit depth&nbsp; ";
            $text .=
                "<select name=\"qdepth\" size=\"1\"> <option>"
              . $query->param("qdepth")
              . "</option> <option></option>";
            for ( my $i = 1 ; $i <= $maxlvl ; $i++ ) {
                $text .= " <option>$i</option>";
            }
            $text .= " </select>";
        }
        $text .= "</form>";
    }

    return $result . $text;
}

sub handleLine {
    my ( $listNr, $lineNr, $level ) = @_;

    # Add edit links
    my $title = "";
    my $text  = "";

    # edit = /TWiki/DocumentGraphics/pencil.gif
    # comment = /TWiki/DocumentGraphics/note.gif
    my $eurl = TWiki::Func::getScriptUrlPath() . "/editthread/$web/$topic";
    $text .=
        "&nbsp; <a href=\"$eurl\?t="
      . time()
      . "&nr=$listNr&sec=$lineNr&level=$level#SECEDITBOX\"><small>$editLabel</small></a>";
    $text .= "&nbsp;";
    $text .=
        "<a href=\"$eurl\?t="
      . time()
      . "&nr=$listNr&sec=$lineNr&level=$level&comment=1#SECEDITBOX\"><small>$commentLabel</small></a>";
    return $text;

}

sub handleTagsForIcons {
    my ( $theParams, $topic ) = @_;

    $topic = "DocumentGraphics" unless $topic;
    my $attachUrl = TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath();

    $theParams =~ s/%PUBURL%/$attachUrl/go;
    $attachUrl .= "/$installWeb/$topic";
    $theParams =~ s/%ATTACHURL%/$attachUrl/go;
    $theParams =~ s/%WEB%/$installWeb/go;
    $theParams =~ s/%MAINWEB%/TWiki::Func::getMainWebname()/geo;
    $theParams =~ s/%SYSTEMWEB%/TWiki::Func::getTwikiWebname()/geo;

    return $theParams;
}

# =========================
sub renderIconList {
    my ( $theFocus, $theDepth, $theText, $noIcons ) = @_;
    my @tree = ();
    $treeref = \@tree;
    my $maxlvl = &analyzeList( $theFocus, $theDepth, $theText, $treeref );
    my $text = "";

    if ($renderAsList) {
        my $start = 0;
        $start = 1 unless ($showLead);
        for ( my $i = 0 ; $i < scalar(@tree) ; $i++ ) {
            my $level = $tree[$i]->{'level'};
            for ( my $l = $start ; $l < $level ; $l++ ) {
                $text .= "\t";
            }
            $text .= "* ";
            if ( $tree[$i]->{'text'} =~ /^\s*(<b>)?\s*icon:([^\s]+)\s*(.*)/ ) {

                # specific icon
                $tree[$i]->{'text'} = $3;
                $tree[$i]->{'text'} = "$1 $3" if ($1);
                my $icon = &handleTagsForIcons("$iconlocation/$2.gif");
                $icon = fixImageTag( $icon, $width, $height );
                $text .= "$icon&nbsp;";
                $text .= "$tree[$i]->{'text'}";
            }
            else {
                $text .= "$tree[$i]->{'text'}";
            }
            my $idx = $tree[$i]->{'idx'};

            #$text .= "%LINE{$listNr, $idx, $level}%";
            $text .= &handleLine( $listNr, $idx, $level ) unless $noIcons;
            $text .= "\n";
        }
    }
    else {
        my $start = 0;
        $start = 1 unless ($showLead);
        for ( my $i = 0 ; $i < scalar(@tree) ; $i++ ) {
            $text .=
              '<table border="0" cellspacing="0" cellpadding="0"><tr>' . "\n";
            my $level = $tree[$i]->{'level'};
            for ( my $l = $start ; $l < $level ; $l++ ) {
                $text .=
                  "<td style=\"border-left: $threadcolor\">$iconSp</td>\n";
            }
            if ( $tree[$i]->{'text'} =~ /^\s*(<b>)?\s*icon:([^\s]+)\s*(.*)/ ) {

                # specific icon
                $tree[$i]->{'text'} = $3;
                $tree[$i]->{'text'} = "$1 $3" if ($1);
                my $icon = &handleTagsForIcons("$iconlocation/$2.gif");
                $icon = fixImageTag( $icon, $width, $height );
                $text .= "<td valign=\"top\">$icon&nbsp; </td>\n";
                $text .= "<td valign=\"top\">$tree[$i]->{'text'}";
            }
            else {
                $text .= "<td valign=\"top\">$tree[$i]->{'text'}";
            }
            my $idx = $tree[$i]->{'idx'};

            #$text .= "%LINE{$listNr, $idx, $level}%";
            $text .= &handleLine( $listNr, $idx, $level ) unless $noIcons;
            $text .= '</td></tr></table>' . "\n";

        }
    }

    return ( $maxlevel, $text );
}

# =========================
sub analyzeList {
    my ( $theFocus, $theDepth, $theText, $tree ) = @_;

    # note that $tree is a reference to @tree

    $theText =~ s/^[\n\r]*//os;
    my $level      = 0;
    my $type       = "";
    my $text       = "";
    my $focusIndex = -1;
    my $idx        = 0;
    my $maxlvl     = 0;
    foreach ( split( /[\n\r]+/, $theText ) ) {
        m/^(\t+)(.) *(.*)/;
        $level    = length($1);
        $maxlevel = $level if ( $level > $maxlevel );
        $type     = $2;
        $text     = $3;
        if ( ($theFocus) && ( $focusIndex < 0 ) && ( $text =~ /$theFocus/ ) ) {
            $focusIndex = scalar( @{$tree} );
        }
        push(
            @{$tree},
            { level => $level, type => $type, text => $text, idx => $idx }
        );
        $idx++;
    }

    # reduce tree to relatives around focus
    if ( $focusIndex >= 0 ) {

        # splice tree into before, current node and after parts
        my @after = splice( @{$tree}, $focusIndex + 1 );
        my $nref = pop( @{$tree} );

        # highlight node with focus and remove links
        $text = $nref->{'text'};
        $text =~
          s/^([^\-]*)\[\[.*?\]\[(.*?)\]\]/$1$2/o;    # remove [[...][...]] link
        $text =~ s/^([^\-]*)\[\[(.*?)\]\]/$1$2/o;    # remove [[...]] link
        $text = "<b> $text </b>";                    # bold focus text
        $nref->{'text'} = $text;

        # remove uncles and siblings below current node
        $level = $nref->{'level'};
        for ( my $i = 0 ; $i < scalar(@after) ; $i++ ) {
            if (
                ( $after[$i]->{'level'} < $level )
                || (   $after[$i]->{'level'} <= $level
                    && $after[$i]->{'type'} ne " " )
              )
            {
                splice( @after, $i );
                last;
            }
        }

        # remove uncles and siblings above current node
        my @before = ();
        for ( my $i = scalar( @{$tree} ) - 1 ; $i >= 0 ; $i-- ) {

            if ( $tree->[$i]->{'level'} < $level ) {
                push( @before, $tree->[$i] );
                $level = $tree->[$i]->{'level'};
            }
        }
        @{$tree} = reverse(@before);
        $focusIndex = scalar( @{$tree} );
        push( @{$tree}, $nref );
        push( @{$tree}, @after );
    }

    # limit depth of tree
    my $depth = $theDepth;
    unless ( $depth =~ s/.*?([0-9]+).*/$1/o ) {
        $depth = 0;
    }
    if ($theFocus) {
        if ( $theDepth eq "" ) {
            $depth = $focusIndex + 3;
        }
        else {
            $depth += $focusIndex + 1;
        }
    }
    if ( $depth > 0 ) {
        my @tmp = ();
        foreach my $ref ( @{$tree} ) {
            push( @tmp, $ref ) if ( $ref->{'level'} <= $depth );
        }
        @{$tree} = @tmp;
    }
    return $maxlvl;
}

# =========================
sub fixImageTag {
    my ( $theIcon, $theWidth, $theHeight ) = @_;

    if ( $theIcon =~ /\.(png|gif|jpeg|jpg)/i && $theIcon !~ /<img/i ) {
        $theIcon =
            "<img src=\"$theIcon\" width=\"$theWidth\" height=\"$theHeight\""
          . " alt=\"\" border=\"0\" />";
    }
    return $theIcon;
}

# =========================
sub handleAnalyzeList {
    my ( $theAttr, $thePre, $theList, $theNr, $query ) = @_;

    # $_[5] passes the new section, if updated by reference

    $pos++;
    if ( $pos == $theNr ) {

        my @tree = ();
        $treeref = \@tree;
        my $commentlvl  = 0;
        my $commenttype = "";
        analyzeList( "", 0, $theList, $treeref );

        # Now identify $sectxt, $pretxt, and $postxt
        my $sec = $query->param('sec')   || 0;
        my $lvl = $query->param('level') || 0;
        my $text = "";
        for ( my $i = 0 ; $i < scalar(@tree) ; $i++ ) {
            my $level  = $tree[$i]->{'level'};
            my $leader = "\n";
            for ( my $l = 0 ; $l < $level ; $l++ ) {
                $leader .= "\t";
            }
            my $type .= $tree[$i]->{'type'} . " ";
            if ($commentlvl) {
                if ( $commentlvl > $level ) {
                    my $commentleader = "\n";
                    for ( my $l = 0 ; $l < $commentlvl ; $l++ ) {
                        $commentleader .= "\t";
                    }
                    $pretxt .= $commentleader . $commenttype . " ";
                    $sectxt = "";
                    $postxt .= "$leader$type" . $tree[$i]->{'text'};

                    #$_[4]->param( -name=>"sec", $i + 1 );
                    $_[5] = $i;
                    $commentlvl = 0;
                }
                else {
                    $pretxt .= "$leader$type" . $tree[$i]->{'text'};
                }
            }
            elsif ( $i < $sec ) {
                $pretxt .= "$leader$type" . $tree[$i]->{'text'};
            }
            elsif ( $i > $sec ) {
                $postxt .= "$leader$type" . $tree[$i]->{'text'};
            }
            else {
                if ( $query->param('comment') || 0 ) {

                    # Need to find the last child and add there...
                    $commentlvl  = $level + 1;
                    $commenttype = $tree[$i]->{'type'};
                    $pretxt .= "$leader$type" . $tree[$i]->{'text'};
                }
                else {
                    $pretxt .= "$leader$type";
                    $sectxt = $tree[$i]->{'text'};
                }
            }
        }
        if ($commentlvl) {

            # Add comment to end
            my $commentleader = "\n";
            for ( my $l = 0 ; $l < $commentlvl ; $l++ ) {
                $commentleader .= "\t";
            }
            $pretxt .= $commentleader . $commenttype . " ";
            $sectxt = "";

            #$query->param( -name=>"sec", scalar( @tree ) );
            $_[5] = scalar(@tree);
            $commentlvl = 0;
        }

        return
            "%DISCUSSION{$theAttr}%" 
          . $thePre
          . "${translationToken}_section_$translationToken"
          . $theList
          . "${translationToken}_section_$translationToken";
    }
    else {

        return "%DISCUSSION{$theAttr}%" . $thePre . $theList;
    }
}

sub handleAnalyzeEmptyList {
    my ( $theAttr, $theText, $thePre, $theNr, $query ) = @_;

    $pos++;
    if ( $pos == $theNr ) {

        return
"%DISCUSSION{$theAttr}%\n\t\* ${translationToken}_section_$translationToken${translationToken}_section_$translationToken$thePre";

    }
    else {
        return "%DISCUSSION{$theAttr}%" . $theText . $thePre;
    }
}

1;
