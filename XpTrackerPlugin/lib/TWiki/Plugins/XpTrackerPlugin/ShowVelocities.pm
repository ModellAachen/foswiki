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
# 2004-02-21 RafaelAlvarez When the velocity is being calculated in xpShowVelocity, if two developers
#						   are assigned to the same task the estimate, todo, and spent time are
#                          accounted to both.
# =========================
package TWiki::Plugins::XpTrackerPlugin::ShowVelocities;

use HTTP::Date;
use TWiki::Plugins::XpTrackerPlugin;
use TWiki::Plugins::XpTrackerPlugin::Common;
use TWiki::Plugins::XpTrackerPlugin::Story;

#(RAF)
#If this module is load because using the "use" directive before the plugin is
#initialized, then $debug will be 0
#(CC) this will not work in Dakar; TWiki::Func methods cannot be called before initPlugin.
my $debug;

#my $debug = &TWiki::Func::getPreferencesFlag( "XPTRACKERPLUGIN_DEBUG" );
#&TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::ShowVelocities is loaded" ) if $debug;

sub xpShowVelocities {
    my ( $iteration, $web ) = @_;

    my ( %whoAssigned, %whoSpent, %whoEtc, %whoTAssigned, %whoTRemaining ) = ();
    my (
        $totalSpent,    $totalEtc,       $totalAssigned,
        $totalVelocity, $totalTAssigned, $totalTRemaining
    ) = ( 0, 0, 0, 0, 0, 0 );

    my @stories =
      TWiki::Plugins::XpTrackerPlugin::Common::loadStories( $web, $iteration );
    foreach my $story (@stories) {
        my @tasks = $story->tasks;
        foreach my $task (@tasks) {
            my @whos =
              TWiki::Plugins::XpTrackerPlugin::xpRipWords( $task->who );
            foreach my $who (@whos) {
                $whoSpent{$who} += $task->spent;
                $totalSpent += $task->spent;

                $whoEtc{$who} += $task->etc;
                $totalEtc += $task->etc;

                $whoAssigned{$who} += $task->est;
                $totalAssigned += $task->est;

                $whoTAssigned{$who}++;
                $totalTAssigned++;

                if ( $task->etc > 0 ) {
                    $whoTRemaining{$who}++;
                    $totalTRemaining++;
                }
                else {

                    # ensure these variables always get initialised
                    $whoTRemaining{$who} += 0;
                    $totalTRemaining += 0;
                }
            }
        }
    }

    # Show them
    my $list = "<h3>Developer velocity for iteration " . $iteration . "</h3>\n";

    # Show the list
    $list .=
"<script src=\"%PUBURLPATH%/%SYSTEMWEB%/XpTrackerPlugin/sorttable.js\">\n";
    $list .= "<table class=\"sortable\" id=\"showvelocity\" border=\"1\">";
    $list .= "<tr bgcolor=\"#CCCCCC\">";

    #$list .= "<th rowspan=\"2\">Who</th>";
    $list .= "<th>Who</th>";

    #$list .= "<th colspan=\"4\">Ideals</th>";
    #$list .= "<th colspan=\"2\">Tasks</th>";
    #$list .= "</tr>";
    #$list .= "<tr bgcolor=\"#CCCCCC\">";
    $list .= "<th>Assigned</th>";
    $list .= "<th>Spent</th>";
    $list .= "<th>Remaining</th>";
    $list .= "<th>Completition</th>";
    $list .= "<th>&nbsp;</td>";
    $list .= "<th>Assigned Tasks</th>";
    $list .= "<th>Remaining Tasks</th>";
    $list .= "</tr>";

    foreach my $who ( sort { $whoEtc{$b} <=> $whoEtc{$a} } keys %whoSpent ) {

        my $completition = int(
            TWiki::Plugins::XpTrackerPlugin::Common::getPercentage(
                $whoSpent{$who}, $whoSpent{$who} + $whoEtc{$who}
            )
        );
        $list .= "<tr>";
        $list .= "<td> " . $who . " </td>";
        $list .= "<td align=\"center\">" . $whoAssigned{$who} . "</td>";
        $list .= "<td align=\"center\">" . $whoSpent{$who} . "</td>";
        $list .= "<td align=\"center\">" . $whoEtc{$who} . "</td>";
        $list .= "<td align=\"center\">" . $completition . "%</td>";
        $list .= "<td align=\"center\">&nbsp;</td>";
        $list .= "<td align=\"center\">" . $whoTAssigned{$who} . "</td>";
        $list .= "<td align=\"center\">" . $whoTRemaining{$who} . "</td>";
        $list .= "</tr>";
    }

#$list .= "<tr bgcolor=\"#CCCCCC\">";
#$list .= "<th align=\"left\">Total</th>";
#$list .= "<th>".$totalAssigned."</th>";
#$list .= "<th>".$totalSpent."</th>";
#$list .= "<th>".$totalEtc."</th>";
#$list .= "<th align=\"center\">".int(TWiki::Plugins::XpTrackerPlugin::Common::getPercentage($totalSpent,$totalSpent+$totalEtc))."%</th>";
#$list .= "<th align=\"center\">&nbsp;</td>";
#$list .= "<th>".$totalTAssigned."</th>";
#$list .= "<th>".$totalTRemaining."</th>";
#$list .= "</tr>";
    $list .= "</table>";

    return $list;
}

1;
