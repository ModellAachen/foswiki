#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
# Copyright (C) 2004 Rafael Alvarez, soronthar@yahoo.com
#
# Authors (in alphabetical order)
#   Andrea Bacchetta
#   Richard Bennett
#   Anthon Pang
#   Andrea Sterbini
#   Martin Watt
#   Thomas Eschner
#   Rafael Alvarez (RAF)
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
# TODO: Count the stories by status
package TWiki::Plugins::XpTrackerPlugin::ShowIterationTerse;

use HTTP::Date;
use TWiki::Func;
use TWiki::Plugins::XpTrackerPlugin;
use TWiki::Plugins::XpTrackerPlugin::Common;
use TWiki::Plugins::XpTrackerPlugin::HtmlUtil;

#(RAF)
#If this module is load using the "use" directive before the plugin is
#initialized, $debug will be 0
#(CC) this will not work in Dakar; TWiki::Func methods cannot be called before initPlugin.
my $debug;

#my $debug = &TWiki::Func::getPreferencesFlag( "XPTRACKERPLUGIN_DEBUG" );
#&TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::ShowIterationTerse is loaded" ) if $debug;

sub xpShowIterationTerse {
    my ( $iterationName, $web ) = @_;

    # append "create new story" form

    my $list = &TWiki::Plugins::XpTrackerPlugin::HtmlUtil::emmitTwikiHeader( 3,
        "Iteration summary" );
    $list .= TWiki::Plugins::XpTrackerPlugin::xpCreateHtmlForm( "NewnameStory",
        "XpStoryTemplate", "Create new story in this iteration" );
    $list .=
"<script src=\"%PUBURLPATH%/%SYSTEMWEB%/XpTrackerPlugin/sorttable.js\">\n";
    $list .=
"<table class=\"sortable\" border=\"1\" id=\"SHOWITERATIONTERSE_$iterationName_$web\">";
    $list .= "<tr bgcolor=\"#CCCCCC\">";
    $list .= "<th align=\"left\">Story</th>";
    $list .= "<th>FEA</th><th>Estimate</th>";
    $list .= "<th>Spent</th><th>ToDo</th>";
    $list .= "<th>Progress</th><th>Done</th>";
    $list .= "<th>Overrun</th>";
    $list .= "<th>Completion</th>";
    $list .= "<th>Developer</th>";
    $list .= "<th>Reviewer</th>";
    $list .= "</tr>";

    my @stories = TWiki::Plugins::XpTrackerPlugin::Common::loadStories( $web,
        $iterationName );
    my ( $totalSpent, $totalEtc, $totalEst ) = ( 0, 0, 0 );

    # Show them
    foreach my $story ( sort { $a->cmp($b) } @stories ) {

        # Show story line
        $list .= "<tr bgcolor=" . $story->color . ">";
        $list .=
          "<td> " . $story->name . "<br> " . $story->storySummary . "</td>";
        $list .= "<td align=\"center\"> " . $story->FEA . " </td>";
        $list .=
          "<td align=\"center\"><b>" . $story->storyCalcEst . "</b></td>";
        $list .= "<td align=\"center\"><b>" . $story->storySpent . "</b></td>";
        $list .= "<td align=\"center\"><b>" . $story->storyEtc . "</b></td>";
        $list .= "<td>"
          . TWiki::Plugins::XpTrackerPlugin::HtmlUtil::gaugeLite( $story->done )
          . "</td>";
        $list .= "<td align=right>" . $story->done . "%</td>";
        $list .= "<td align=right>" . $story->overrun . "%</td>";
        $list .= "<td>" . $story->storyStatS . "</td>";
        $list .= "<td align=\"center\"> " . $story->all . " </td>";
        $list .= "<td align=\"center\"> " . $story->allReviewer . " </td>";
        $list .= "</tr>";

        # Add to totals
        $totalSpent += $story->storySpent;
        $totalEtc   += $story->storyEtc;
        $totalEst   += $story->storyCalcEst;

    }

    # Do iteration totals
    my ( $totDone, $cfTotEst ) =
      TWiki::Plugins::XpTrackerPlugin::Status::calculateStats( $totalEst,
        $totalSpent, $totalEtc );
    my $gaugeTxt =
      TWiki::Plugins::XpTrackerPlugin::HtmlUtil::gaugeLite($totDone);

    $list .= "<tr bgcolor=\"#CCCCCC\">";
    $list .= "<td><b>Team totals</b></td>";
    $list .= "<td>&nbsp;</td>";
    $list .= "<td align=\"center\"><b>" . $totalEst . "</b></td>";
    $list .= "<td align=\"center\"><b>" . $totalSpent . "</b></td>";
    $list .= "<td align=\"center\"><b>" . $totalEtc . "</b></td>";
    $list .= "<td>" . $gaugeTxt . "</td>";
    $list .= "<td align=right>" . $totDone . "%</td>";
    $list .= "<td align=right>" . $cfTotEst . "%</td>";
    $list .= "<td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>";
    $list .= "</table>";

# dump summary information into a comment for extraction by xpShowTeamIterations
    $list .=
        "\n<!--SUMMARY |  "
      . $totalEst . "  |  "
      . $totalSpent . "  |  "
      . $totalEtc . "  |  "
      . $gaugeTxt . "  |  "
      . $totDone
      . "%  |  "
      . $cfTotEst
      . "%  | END -->\n";

    # append "create new story" form
    $list .= TWiki::Plugins::XpTrackerPlugin::xpCreateHtmlForm( "NewnameStory",
        "XpStoryTemplate", "Create new story in this iteration" );

    return $list;
}

1;
