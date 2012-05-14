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
#   Rafael Alvarez
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
package TWiki::Plugins::XpTrackerPlugin::ShowIteration;

use HTTP::Date;
use TWiki::Func;
use TWiki::Plugins::XpTrackerPlugin;
use TWiki::Plugins::XpTrackerPlugin::Common;
use TWiki::Plugins::XpTrackerPlugin::Status;

#(CC) this will not work in Dakar; TWiki::Func methods cannot be called before initPlugin.
my $debug;

#my $debug = &TWiki::Func::getPreferencesFlag( "XPTRACKERPLUGIN_DEBUG" );

sub xpShowIteration {
    my ( $iterationName, $web ) = @_;

    my $list = "<h3>Iteration " . $iterationName . " details</h3>";
    $list .= "<table border=\"1\">";
    $list .= "<tr bgcolor=\"#CCCCCC\">";
    $list .= "<th align=\"left\">Story<br>&nbsp; Tasks </th>";
    $list .= "<th>Estimate</th>";
    $list .= "<th>Who</th>";
    $list .= "<th>Spent</th>";
    $list .= "<th>To do</th>";
    $list .= "<th>Status</th></tr>";

    my @stories = TWiki::Plugins::XpTrackerPlugin::Common::loadStories( $web,
        $iterationName );
    my ( $totalSpent, $totalEtc, $totalEst ) = ( 0, 0, 0 );

    # Show them
    foreach my $story ( sort { $a->cmp($b) } @stories ) {
        $list .= "<tr bgcolor=" . $story->color . ">";
        $list .= "<td> " . $story->name . " </td>";
        $list .=
          "<td align=\"center\"><b>" . $story->storyCalcEst . "</b></td>";
        $list .= "<td> " . $story->storyLead . " </td>";
        $list .= "<td align=\"center\"><b>" . $story->storySpent . "</b></td>";
        $list .= "<td align=\"center\"><b>" . $story->storyEtc . "</b></td>";
        $list .=
          "<td nowrap>" . $story->storyStatS . " (" . $story->done . "%)</td>";
        $list .= "</tr>";

        my @tasks = $story->tasks;

        # Show each task
        foreach my $task (@tasks) {
            my ( $taskBG, $statusString ) =
              TWiki::Plugins::XpTrackerPlugin::Status::getStatus( $task->spent,
                $task->etc, $story->storyComplete );

            $list .= "<tr bgcolor=\"" . $taskBG . "\">";
            $list .= "<td>&nbsp;&nbsp;&nbsp;&nbsp;" . $task->name . "</td>";
            $list .= "<td align=\"center\">" . $task->est . "</td>";
            $list .= "<td> " . $task->who . " </td>";
            $list .= "<td align=\"center\">" . $task->spent . "</td>";
            $list .= "<td align=\"center\">" . $task->etc . "</td>";
            $list .= "<td nowrap>" . $statusString . "</td>";
            $list .= "</tr>";
        }

        # Add a spacer
        $list .= "<tr><td colspan=\"6\">&nbsp;</td></tr>";

        # Add to totals
        $totalSpent += $story->storySpent;
        $totalEtc   += $story->storyEtc;
        $totalEst   += $story->storyCalcEst;

    }

    # Do iteration totals

    $list .= "<tr bgcolor=\"#CCCCCC\">";
    $list .= "<td><b>Team totals</b></td>";
    $list .= "<td align=\"center\"><b>" . $totalEst . "</b></td>";
    $list .= "<td>&nbsp;</td>";
    $list .= "<td align=\"center\"><b>" . $totalSpent . "</b></td>";
    $list .= "<td align=\"center\"><b>" . $totalEtc . "</b></td>";
    $list .= "<td>&nbsp;</td>";
    $list .= "</tr>";
    $list .= "</table>";
    return $list;
}

&TWiki::Func::writeDebug(
    "- TWiki::Plugins::XpTrackerPlugin::ShowIteration is loaded")
  if $debug;

1;
