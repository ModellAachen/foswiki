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
# 2004-02-28 RafaelAlvarez Replace all the calls of "unofficial" subs
#                          with their equivalent in the Func module.
# =========================
package TWiki::Plugins::XpTrackerPlugin::ShowLoad;

use HTTP::Date;
use TWiki::Func;
use TWiki::Plugins::XpTrackerPlugin;
use TWiki::Plugins::XpTrackerPlugin::Iteration;

#(RAF)
#If this module is load using the "use" directive before the plugin is
#initialized, $debug will be 0
#(CC) this will not work in Dakar; TWiki::Func methods cannot be called before initPlugin.
my $debug;

#my $debug = &TWiki::Func::getPreferencesFlag( "XPTRACKERPLUGIN_DEBUG" );
#&TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::ShowLoad is loaded" ) if $debug;

###########################
# ThomasEschner: xpShowLoad
#
# Shows workload by developer and project/iteration.

sub xpShowLoad {
    my ( $dev, $web ) = @_;

    my $now             = time;
    my $unassignedTasks = 0;
    my ( @projiter, @projiterSec, @nobodiesStories, %devDays );

    my @projects = &TWiki::Plugins::XpTrackerPlugin::xpGetAllProjects($web);

    my $list =
        "<h3>Workload for developer " 
      . $dev
      . " and project iteration in $web</h3>\n\n";

    # Collect data
    my $count = 0;

    foreach my $project (@projects) {
        my @teams =
          &TWiki::Plugins::XpTrackerPlugin::xpGetProjectTeams( $project, $web );
        foreach my $team (@teams) {
            my @teamIters =
              &TWiki::Plugins::XpTrackerPlugin::xpGetTeamIterations( $team,
                $web );
            foreach my $iterationName (@teamIters) {
                $count++;
                my $iteration =
                  new TWiki::Plugins::XpTrackerPlugin::Iteration( $web,
                    $iterationName );

                # Set up other story stats
                my ($storySpent) = 0;
                my ($storyEtc)   = 0;
                my ($storyEst)   = 0;

                my @allStories =
                  &TWiki::Plugins::XpTrackerPlugin::xpGetIterStories(
                    $iterationName, $web );
                my $mainWeb = TWiki::Func::getMainWebname();

                # Iterate over each story and task
                foreach my $story (@allStories) {
                    my $storyText = &TWiki::Func::readTopicText( $web, $story );

                    # Suck in the tasks
                    while (1) {
                        (
                            my $status,
                            my $name,
                            my $est,
                            my $taskWho,
                            my $spent,
                            my $taskEtc,
                            my $tstatus
                          )
                          = TWiki::Plugins::XpTrackerPlugin::xpGetNextTask(
                            $storyText);
                        last if ( !$status );

                        my @who =
                          TWiki::Plugins::XpTrackerPlugin::xpRipWords($taskWho);

                        for ( my $x = 0 ; $x < @who ; $x++ ) {

                            # straighten $who
                            $who[$x] =~ s/($mainWeb\.)?(.*)/$mainWeb\.$2/;

                            # no display unless selected
                            my $test = eval { $who[$x] =~ /$dev/ };
                            next unless $test;

                            $devDays{ $who[$x] }[$count] =
                              ( $devDays{ $who[$x] }[$count] || 0 ) + $taskEtc;

                            # Calculate est
                            $storyEtc += $taskEtc;
                        }
                    }
                }

                # no display if nothing left to do
                if ( $storyEtc == 0 ) {
                    $count--;
                    next;
                }

                $projiter[$count] =
                  " $project <br> $iterationName <br> $iteration->{endDate} ";
                $projiterSec[$count] = $iteration->{remaining};
            }
        }
    }

    # Show the list
    $list .= "<table border=\"1\">";
    $list .= "<tr bgcolor=\"#CCCCCC\"><th align=\"left\">Developer</th>";
    for
      my $pi ( sort { $projiterSec[$a] <=> $projiterSec[$b] } ( 1 .. $count ) )
    {
        $list .= "<th> " . $projiter[$pi] . " <br> </th>";
    }
    $list .= "</tr>";

    for my $who ( sort keys %devDays ) {
        my $cumulLoad = 0;
        $list .= "<tr><td bgcolor=#CCCCCC> " . $who . "</td>";
        for my $pi ( sort { $projiterSec[$a] <=> $projiterSec[$b] }
            ( 1 .. $count ) )
        {
            my $color = "";
            $cumulLoad += $devDays{$who}[$pi] * 24 * 3600;
            my $load = ( 7 * $cumulLoad ) / ( 5 * $projiterSec[$pi] )
              if ( $projiterSec[$pi] );    # twisted: 1 day is 8 hours
            $load = -1 unless ( $projiterSec[$pi] );

            if ( $load < 0 ) {
                $color = " bgcolor=#FF6666 ";
            }
            elsif ( $load > 0.6 ) {
                $color = " bgcolor=#FFCCCC ";
            }
            elsif ( $load > 0.45 ) {
                $color = " bgcolor=#FFFFCC ";
            }
            elsif ( $load > 0.3 ) {
                $color = " bgcolor=#CCFFCC ";
            }
            else {
                $color = " bgcolor=#CCCCFF ";
            }
            $list .=
                "<td" 
              . $color
              . "  align=\"center\"><b>"
              . ( $devDays{$who}[$pi] || "&nbsp;" ) . "</b>";

            if ( defined $devDays{$who}[$pi] && ( $devDays{$who}[$pi] > 0 ) ) {
                if ( $load > 0 ) {
                    $list .= " <br> " . sprintf( "%d \%\%", 100 * $load ) . " ";
                }
                else {
                    $list .= " <br> (late!) ";
                }
            }

            $list .= "</td>";
        }
        $list .= "</tr>";
    }
    if ( $unassignedTasks != 0 ) {
        $list .= "<tr><td>nobodies tasks in</td>";

        # stories with unassigned tasks
        for my $pi ( sort { $projiterSec[$a] <=> $projiterSec[$b] }
            ( 1 .. $count ) )
        {
            $list .= "<td align=\"center\"> &nbsp; ";
            for my $story ( keys %{ $nobodiesStories[$pi] } ) {
                $list .= $story . " <br> ";
            }
            $list .= "</td>";
        }
        $list .= "</tr>";
    }
    $list .= "</table>";

    $list .=
"<table><td>load ranges</td><td bgcolor=#CCCCFF>0-30</td><td bgcolor=#CCFFCC>30-45</td><td bgcolor=#FFFFCC>45-60</td><td bgcolor=#FFCCCC>60...</td><td>estimated on a 5/7, 8/24 basis</td></table>";
    return $list;
}

1;
