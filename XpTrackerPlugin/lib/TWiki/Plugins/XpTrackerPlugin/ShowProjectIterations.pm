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
package TWiki::Plugins::XpTrackerPlugin::ShowProjectIterations;

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
#&TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::ShowProjectIterations is loaded" ) if $debug;

sub xpShowProjectIterations {

    my ( $project, $web ) = @_;

    my $list = TWiki::Plugins::XpTrackerPlugin::HtmlUtil::emmitTwikiHeader( 3,
        "All iterations for project " . $project );

    $list .= "| *Team* ";
    $list .= "| *Iter* ";
    $list .= "| *Summary* ";
    $list .= "| *Start* ";
    $list .= "| *End* ";
    $list .= "| *Lenght* ";
    $list .= "| *Est* ";
    $list .= "| *Spent* ";
    $list .= "| *<nop>ToDo* ";
    $list .= "| *Progress* ";
    $list .= "| *Done* ";
    $list .= "| *Overrun* |\n";

    my @projTeams =
      &TWiki::Plugins::XpTrackerPlugin::xpGetProjectTeams( $project, $web );
    foreach my $team (@projTeams) {

        my @iterations =
          TWiki::Plugins::XpTrackerPlugin::Common::loadTeamIterations( $web,
            $team );

        # write out all iterations to table
        foreach my $iteration ( sort { $b->order <=> $a->order } @iterations ) {
            my $gaugeTxt = TWiki::Plugins::XpTrackerPlugin::HtmlUtil::gaugeLite(
                $iteration->done );
            $list .= "| " . $team . " ";
            $list .= "| " . $iteration->name . " ";
            $list .= "| " . $iteration->summary . " ";
            $list .= "|  " . $iteration->startDate . "  ";
            $list .= "|  " . $iteration->endDate . "  ";
            $list .= "|  " . $iteration->length . "  ";
            $list .= "|  " . $iteration->est . "  ";
            $list .= "|  " . $iteration->spent . "  ";
            $list .= "|  " . $iteration->todo . "  ";
            $list .= "|  " . $gaugeTxt . "  ";
            $list .= "|  " . $iteration->done . "%  ";
            $list .= "|  " . $iteration->overrun . "%  |\n";
        }

    }
    return $list;
}

1;
