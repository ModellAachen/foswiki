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
package TWiki::Plugins::XpTrackerPlugin::Show;

use HTTP::Date;
use TWiki::Func;
use TWiki::Plugins::XpTrackerPlugin;
use TWiki::Plugins::XpTrackerPlugin::Status;
use TWiki::Plugins::XpTrackerPlugin::Iteration;

#(RAF)
#If this module is load using the "use" directive before the plugin is
#initialized, $debug will be 0
#(CC) this will not work in Dakar; TWiki::Func methods cannot be called before initPlugin.
my $debug;

#my $debug = &TWiki::Func::getPreferencesFlag( "XPTRACKERPLUGIN_DEBUG" );
#&TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::Show is loaded" ) if $debug;

###########################
# ThomasEschner: xpShowDeveloperTasks
# RafaelAlvarez: Modified to be able to consult the open task from any web.
# Shows open tasks by developer.

sub developerTasks {
    my ( $developer, $web ) = @_;

    TWiki::Plugins::XpTrackerPlugin::Cache::initCache($web);

    my @projects = TWiki::Plugins::XpTrackerPlugin::xpGetAllProjects($web);

    # Show the list
    my $list = "\n\n---++Open tasks assigned to $developer\n\n";

    # todo: build a list of projects/iterations sorted by date
    my ( $totalSpent, $totalEtc, $totalEst ) = ( 0, 0, 0 );
    foreach my $project (@projects) {
        my $text;
        ( $text, $totalSpent, $totalEtc, $totalEst ) =
          &developerTasksByProject( $developer, $project, $web );

        if (   ( $totalEtc && $totalEtc > 0 )
            || ( $totalSpent && $totalSpent > 0 ) )
        {
            $list .= "\n\n\n";
            $list .= "---+++ Project: " . $web . "." . $project . "\n\n";
            $list .= $text;
        }
    }

    $list .= "<table border=1 width=\"100%\">";
    $list .= "<tr bgcolor=\"#CCCCCC\">";
    $list .= "<td width=\"50%\" ><b>Developer totals</b></td>";
    $list .=
      "<td width=\"10%\"  align=\"center\"><b>" . $totalEst . "</b></td>";
    $list .=
      "<td width=\"5%\" align=\"center\"><b>" . $totalSpent . "</b></td>";
    $list .= "<td width=\"10%\" align=\"center\"><b>" . $totalEtc . "</b></td>";
    $list .= "<td width=\"12%\" >&nbsp;</td>";
    $list .= "<td width=\"13%\">&nbsp;</td>";
    $list .= "</tr>";
    $list .= "</table>";

    $list .= "<table>";
    $list .= "<tr>";
    $list .= "<td>task due within</td>";
    $list .= "<td bgcolor=#FFFFCC>3 days</td>";
    $list .= "<td bgcolor=#FFCCCC>2 days</td>";
    $list .= "<td bgcolor=#FF6666>1 day</td>";
    $list .= "</tr>";
    $list .= "</table>";

    return $list;
}

###########################
# RafaelAlvarez: xpShowDeveloperTasksByProject
# Shows open tasks in a project by developer in the specified web.
sub developerTasksByProject {
    my ( $developer, $project, $web ) = @_;

    TWiki::Plugins::XpTrackerPlugin::Cache::initCache($web);

    my $list = "";
    my @teams =
      &TWiki::Plugins::XpTrackerPlugin::xpGetProjectTeams( $project, $web );
    foreach my $team (@teams) {
        my @teamIters =
          &TWiki::Plugins::XpTrackerPlugin::xpGetTeamIterations( $team, $web );

        # write out all iterations to table
        my $count = 1;
        foreach my $iterationName (@teamIters) {
            my ( $text, $iterEst, $iterSpent, $iterEtc ) =
              developerTasksByIteration( $developer, $iterationName, $web,
                ( $count == 1 ), 0 );

            TWiki::Func::writeDebug(
                join( ",", ( $iterationName, $iterEst, $iterSpent, $iterEtc ) )
            ) if $debug;
            if (   ( $iterEtc && $iterEtc > 0 )
                || ( $iterSpent && $iterSpent > 0 ) )
            {
                $count++;    #Show header only in the first iteration shown
                TWiki::Func::writeDebug( $iterationName . " OK" ) if $debug;
                $list .= $text;

                # Add to totals
                $totalSpent += $iterSpent;
                $totalEtc   += $iterEtc;
                $totalEst   += $iterEst;
            }
        }    #foreach my $iterationName (@teamIters) {
    }
    return ( $list, $totalSpent, $totalEtc, $totalEst );
}

###########################
# RafaelAlvarez: developerTasksByIteration
# Shows open tasks in an iteration by developer in the specified web.

sub developerTasksByIteration {
    my ( $developer, $iterationName, $web, $header, $totalize ) = @_;

    TWiki::Plugins::XpTrackerPlugin::Cache::initCache($web);

    my $list = "<table cellspacing=\"1\" border=\"1\" width=\"100%\">";

    if ($header) {
        $list .= "<tr bgcolor=\"#CCCCCC\">";
        $list .=
"<th width=\"50%\" align=\"left\"></b>Iteration</b><br>&nbsp;&nbsp;Story<br>&nbsp;&nbsp;&nbsp;&nbsp;Task </th>";
        $list .= "<th width=\"10%\" align=\"center\">Estimate</th>";
        $list .= "<th width=\"5%\" align=\"center\">Spent</th>";
        $list .= "<th width=\"10%\" align=\"center\">To do</th>";
        $list .= "<th width=\"12%\" align=\"center\">Status</th>";
        $list .= "<th width=\"13%\" align=\"center\">Iteration due</th>";
        $list .= "</tr>";
    }

    $list .= "<tr>";
    $list .=
      "<td colspan=\"6\"> <b> " . $web . "." . $iterationName . " </b> </td>";
    $list .= "</tr>";

    my ( $iterEst, $iterSpent, $iterEtc ) = ( 0, 0, 0 );

    # Get date of iteration
    my $iteration =
      new TWiki::Plugins::XpTrackerPlugin::Iteration( $web, $iterationName );

    my $iterDate      = $iteration->{endDate};
    my $iterDatecolor = "";

    my $iterSec = $iteration->{remaining};

    if    ( $iterSec < 1 * 24 * 3600 ) { $iterDatecolor = "#FF6666"; }
    elsif ( $iterSec < 2 * 24 * 3600 ) { $iterDatecolor = "#FFCCCC"; }
    elsif ( $iterSec < 3 * 24 * 3600 ) { $iterDatecolor = "#FFFFCC"; }

    my @allStories =
      &TWiki::Plugins::XpTrackerPlugin::xpGetIterStories( $iterationName,
        $web );

    foreach my $story ( sort { $a cmp $b } @allStories ) {
        my $storyText = &TWiki::Func::readTopicText( $web, $story );

        # Set up other story stats
        my ($storySpent) = 0;
        my ($storyEtc)   = 0;
        my ($storyEst)   = 0;

        # Suck in the tasks
        my ( @taskName, @taskStat, @taskEst, @taskWho, @taskSpent, @taskEtc ) =
          ();    # arrays for each task
        my $taskCount = 0;              # Amount of tasks in this story
        my @storyStat = ( 0, 0, 0 );    # Array of counts of task status

        while (1) {
            my ( $status, $name, $est, $who, $spent, $etc, $tstatus ) =
              TWiki::Plugins::XpTrackerPlugin::xpGetNextTask($storyText);
            last if ( !$status );

            # straighten $who
            $who =~ s/(Acsele\.)?(.*)/Acsele\.$2/;    #TODO: User web

            # no display unless selected
            if ($developer) {
                my $test = eval { $who =~ /$developer/ };
                next unless $test;
            }

            $taskName[$taskCount]  = $name;
            $taskEst[$taskCount]   = $est;
            $taskWho[$taskCount]   = $who;
            $taskSpent[$taskCount] = $spent;
            $taskEtc[$taskCount]   = $etc;
            $taskStat[$taskCount]  = $tstatus;
            $storyStat[ $taskStat[$taskCount] ]++;

            # Calculate spent
            $storySpent += $spent;

            # Calculate etc
            $storyEtc += $etc;

            # Calculate est
            $storyEst += $etc;

            $taskCount++;
        }

        # no display if not involved
        next if ( $storyEst == 0 );

        # no display if nothing left to do
        next if ( $storyEtc == 0 );

        # Calculate iter status
        $iterEst   += $storyEst;
        $iterSpent += $storySpent;
        $iterEtc   += $storyEtc;

        # Calculate story status
        my ( $color, $statusS ) =
          TWiki::Plugins::XpTrackerPlugin::Status::getStatus( $storySpent,
            $storyEtc, 'N' );

        # Show iteration line
        $list .= "<tr bgcolor=\"$color\">";
        $list .=
          "<td width=\"50%\">&nbsp;&nbsp; " . $web . "." . $story . "</td>";
        $list .=
          "<td width=\"10%\" align=\"center\"><b>" . $storyEst . "</b></td>";
        $list .=
          "<td width=\"5%\" align=\"center\"><b>" . $storySpent . "</b></td>";
        $list .=
          "<td width=\"10%\" align=\"center\"><b>" . $storyEtc . "</b></td>";
        $list .= "<td width=\"12%\" nowrap>" . $statusS . "</td>";
        $list .=
            "<td width=\"13%\" nowrap bgcolor=\""
          . $iterDatecolor . "\">"
          . $iterDate . "</td>";
        $list .= "</tr>";

        # Show each task
        for ( my $i = 0 ; $i < $taskCount ; $i++ ) {

            # Line for each engineer
            my @who =
              TWiki::Plugins::XpTrackerPlugin::xpRipWords( $taskWho[$i] );
            my $est   = $taskEst[$i];
            my $spent = $taskSpent[$i];
            my $etc   = $taskEtc[$i];

            for ( my $x = 0 ; $x < @who ; $x++ ) {
                next if ( $etc == 0 );
                my ( $taskColor, $taskStatusS ) =
                  TWiki::Plugins::XpTrackerPlugin::Status::getStatus( $spent,
                    $etc, 'N' );

                $list .= "<tr bgcolor=\"" . $taskColor . "\">";
                $list .= "<td >&nbsp;";
                $list .= "&nbsp;&nbsp;&nbsp; " . $taskName[$i]
                  if ( $taskName[$i] );
                $list .= "</td>";
                $list .= "<td align=\"center\">" . $est . "</td>";
                $list .= "<td align=\"center\">" . $spent . "</td>";
                $list .= "<td align=\"center\">" . $etc . "</td>";
                $list .= "<td nowrap>" . $taskStatusS . "</td>";
                $list .= "<td> &nbsp;</td>";
                $list .= "</tr>";
            }

        }

        # Add a spacer
        $list .= "<tr><td colspan=\"6\">&nbsp;</td></tr>";

    }    #foreach my $story (sort {$a cmp $b } @allStories) {

    if ($totalize) {
        $list .= "<tr bgcolor=\"#CCCCCC\">";
        $list .= "<td ><b>Developer totals</b></td>";
        $list .= "<td align=\"center\"><b>" . $iterEst . "</b></td>";
        $list .= "<td align=\"center\"><b>" . $iterSpent . "</b></td>";
        $list .= "<td align=\"center\"><b>" . $iterEtc . "</b></td>";
        $list .= "<td>&nbsp;</td><td>&nbsp;</td>";
        $list .= "</tr>";
    }

    $list .= "</table>";

    if (wantarray) {
        return ( $list, $iterEst, $iterSpent, $iterEtc );
    }
    else {
        return $list;
    }
}

1;
