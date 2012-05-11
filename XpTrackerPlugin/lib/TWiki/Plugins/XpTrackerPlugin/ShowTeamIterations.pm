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
# Show the list of all iterations for a given team, with it summary information
# =========================
# 2004-02-23 RafaelAlvarez Changed the iteration ordering so the most
#                          recently started iterations appear first
# =========================
# TODO: Count the stories by status
package TWiki::Plugins::XpTrackerPlugin::ShowTeamIterations;

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
#&TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::ShowTeamIterations is loaded" ) if $debug;

sub xpShowTeamIteration {
    my ( $team, $web ) = @_;

    my $list = "<h3>All iterations for team " . $team . " </h3>\n\n";

    $list .=
"| *Iter* | *Summary* | *Start* | *End* | *Stories* | *Est* | *Spent* | *<nop>ToDo* | *Progress* | *Done* | *Overrun* |\n";

    my @iterations =
      TWiki::Plugins::XpTrackerPlugin::Common::loadTeamIterations( $web,
        $team );

    # write out all iterations to table
    foreach my $iteration ( sort { $b->order <=> $a->order } @iterations ) {

        #$iteration->sumarize();
        my $gaugeTxt = TWiki::Plugins::XpTrackerPlugin::HtmlUtil::gaugeLite(
            $iteration->done );
        $list .= "| " . $iteration->name;
        $list .= " | " . $iteration->summary;
        $list .= "  |  " . $iteration->startDate;
        $list .= "  |  " . $iteration->endDate;
        $list .= "  |  " . $iteration->numberStory;
        $list .= "  |  " . $iteration->est;
        $list .= "  |  " . $iteration->spent;
        $list .= "  |  " . $iteration->todo;
        $list .= "  |  " . $gaugeTxt;
        $list .= "  |  " . $iteration->done . "%";
        $list .= "  |  " . $iteration->overrun . "%";
        $list .= "  |\n";
    }

    # append CreateNewIteration form
    $list .= &TWiki::Plugins::XpTrackerPlugin::xpCreateHtmlForm(
        "ItNewname",
        &TWiki::Func::getPreferencesValue("XPTRACKERPLUGIN_ITERATIONTEMPLATE"),
        "Create new iteration for this team"
    );

    return $list;
}

1;
