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
# 2004-02-26 RafaelAlvarez Modified the xpShowProjectCompletitionByTasks method
#                           so it iterates only once over the stories.
# 2004-02-27 RafaelAlvarez Changed the iteration ordering in xpShowProjectCompletitionByTasks
#                          so the most recently started iterations appear first
# 2004-02-28 RafaelAlvarez Replace all the calls of "unofficial" subs
#                          with their equivalent in the Func module.
# =========================
package TWiki::Plugins::XpTrackerPlugin::ShowProjectCompletitionByTasks;

use HTTP::Date;
use TWiki::Func;
use TWiki::Plugins::XpTrackerPlugin;
use TWiki::Plugins::XpTrackerPlugin::Status;
use TWiki::Plugins::XpTrackerPlugin::Common;

#(RAF)
#If this module is load using the "use" directive before the plugin is
#initialized, $debug will be 0
#(CC) this will not work in Dakar; TWiki::Func methods cannot be called before initPlugin.
my $debug;

#my $debug = &TWiki::Func::getPreferencesFlag( "XPTRACKERPLUGIN_DEBUG" );
#&TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::ShowProjectCompletitionByTasks is loaded" ) if $debug;

sub xpShowProjectCompletionByTasks {

    my ( $project, $web ) = @_;

    my @projectStories =
      &TWiki::Plugins::XpTrackerPlugin::xpGetProjectStories( $project, $web );

    # Iterate over each, and build iteration hash
    my ($unstarted) = 0;
    my ($progress)  = 0;
    my ($complete)  = 0;
    my ($total)     = 0;
    my ( %master, %unstarted, %progress, %complete ) = ();

    foreach my $story (@projectStories) {
        my $storyText = &TWiki::Func::readTopicText( $web, $story );
        my $storyAcceptance =
          TWiki::Plugins::XpTrackerPlugin::Common::acceptanceTestStatus(
            $storyText);
        my $iter =
          &TWiki::Plugins::XpTrackerPlugin::xpGetValue( "\\*Iteration\\*",
            $storyText, "storyiter" );
        if ( $iter ne "TornUp" ) {
            if ( !exists $unstarted{$iter} ) {
                $unstarted{$iter} = 0;
                $progress{$iter}  = 0;
                $complete{$iter}  = 0;
                $accepted{$iter}  = 0;
            }

            while (1) {
                (
                    my $status,
                    my $taskName,
                    my $taskEst,
                    my $taskWho,
                    my $taskSpent,
                    my $taskEtc,
                    my $taskStatus
                  )
                  = TWiki::Plugins::XpTrackerPlugin::xpGetNextTask($storyText);
                if ( !$status ) {
                    last;
                }
                $master{$iter}++;

                my ( $color, $statusS, $desc ) =
                  TWiki::Plugins::XpTrackerPlugin::Status::getStatus(
                    $taskSpent, $taskEtc, $storyAcceptance );
                if ( $desc eq "unstarted" ) {
                    $unstarted{$iter}++;
                    $unstarted++;
                }
                elsif ( $desc eq "inprogress" ) {
                    $progress{$iter}++;
                    $progress++;
                }
                elsif ( $desc eq "complete" ) {
                    $complete{$iter}++;
                    $complete++;
                }
                else {
                    $accepted{$iter}++;
                    $accepted++;
                }
                $total++;

                #                if ($desc eq "unstarted") {
                #                    $unstarted{$iter}++;
                #                    $unstarted++;
                #                } elsif ($desc eq "inprogress") {
                #                    $progress{$iter}++;
                #                    $progress++;
                #                } else{
                #    	            $complete{$iter}++;
                #    	            $complete++;
                #                }
                #                $total++;
            }
        }
    }

    # Get date of each iteration
    my %iterKeys = ();
    foreach my $iteration ( keys %master ) {
        my $iterText = &TWiki::Func::readTopicText( $web, $iteration );
        my $iterDate =
          &TWiki::Plugins::XpTrackerPlugin::xpGetValue( "\\*Start\\*",
            $iterText, "START" );
        my $iterSec = HTTP::Date::str2time($iterDate) - time;
        $iterKeys{$iteration} = $iterSec;
    }

    # Show the list
    my $list = "<h3>Project " . $project . " tasks status</h3>\n\n";
    $list .=
"| *Iteration* |  *Total tasks* | *Not Started* | *In progress* | *Completed* | *Acceptance* | *Percent completed* |\n";

    # OK, display them
    foreach
      my $iteration ( sort { $iterKeys{$b} <=> $iterKeys{$a} } keys %master )
    {
        my $pctComplete = 0;
        if ( $complete{$iteration} > 0 ) {
            $pctComplete = sprintf( "%u",
                ( $complete{$iteration} * 100 / $master{$iteration} ) );
        }
        $list .= "| "
          . $iteration . "  |  "
          . $master{$iteration} . "  |  "
          . $unstarted{$iteration}
          . "  |   "
          . $progress{$iteration} . "  |  "
          . $complete{$iteration} . "  |  "
          . $accepted{$iteration} . "  |  "
          . $pctComplete
          . "\%  |\n";
    }
    my $pctComplete = 0;
    if ( $complete > 0 ) {
        $pctComplete = sprintf( "%u", ( $complete * 100 / $total ) );
    }
    $list .=
        "| *Totals*  |  *" 
      . $total
      . "*  |  *"
      . $unstarted
      . "*  |  *"
      . $progress
      . "*  |  *"
      . $complete
      . "*  |  *"
      . $accepted
      . "*  |  *"
      . $pctComplete
      . "%*  |\n";

    return $list;
}

1;
