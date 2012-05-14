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
package TWiki::Plugins::XpTrackerPlugin::ShowProjectStories;

use HTTP::Date;
use TWiki::Func;
use TWiki::Plugins::XpTrackerPlugin;

#(RAF)
#If this module is load using the "use" directive before the plugin is
#initialized, $debug will be 0
#(CC) this will not work in Dakar; TWiki::Func methods cannot be called before initPlugin.
my $debug;

#my $debug = &TWiki::Func::getPreferencesFlag( "XPTRACKERPLUGIN_DEBUG" );
#&TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::ShowProjectStories is loaded" ) if $debug;

sub xpShowProjectStories {

    my ( $project, $web ) = @_;

    my $listComplete =
      "<h3>Completed stories for project " . $project . "</h3>\n\n";
    $listComplete .=
"| *Team* | *Iteration* | *Story* | *Summary* | *FEA* | *Completion Date* |\n";

    my $listIncomplete =
      "<h3>Uncompleted stories for project " . $project . "</h3>\n\n";
    $listIncomplete .=
      "| *Team* | *Iteration* | *Story* | *Summary* | *FEA* |\n";

    my @teams =
      &TWiki::Plugins::XpTrackerPlugin::xpGetProjectTeams( $project, $web );
    foreach my $team (@teams) {

        my @teamIters =
          &TWiki::Plugins::XpTrackerPlugin::xpGetTeamIterations( $team, $web );

        # write out all iterations to table
        foreach my $iter (@teamIters) {

            # get additional information from iteration
            my $iterText = &TWiki::Func::readTopicText( $web, $iter );
            my $end = &TWiki::Plugins::XpTrackerPlugin::xpGetValueAndRemove(
                "\\*End\\*", $iterText, "notagsforthis" );

            my @allStories =
              &TWiki::Plugins::XpTrackerPlugin::xpGetIterStories( $iter, $web );

            foreach my $story (@allStories) {
                my $storyText = &TWiki::Func::readTopicText( $web, $story );

                my $storySummary = &TWiki::Plugins::XpTrackerPlugin::xpGetValue(
                    "\\*Story summary\\*",
                    $storyText, "notagsforthis" );
                my $fea =
                  &TWiki::Plugins::XpTrackerPlugin::xpGetValue( "\\*FEA\\*",
                    $storyText, "notagsforthis" );
                my $ret = &TWiki::Plugins::XpTrackerPlugin::xpGetValue(
                    "\\*Passed acceptance test\\*",
                    $storyText, "complete" );
                my $storyComplete = uc( substr( $ret, 0, 1 ) );
                if ( $storyComplete eq "Y" || $storyComplete eq "E" ) {
                    $listComplete .=
                        "| " 
                      . $team . " | " 
                      . $iter . " | " 
                      . $story . " | "
                      . $storySummary . " | "
                      . $fea . " | "
                      . $end . "|\n";
                }
                else {
                    $listIncomplete .=
                        "| " 
                      . $team . " | " 
                      . $iter . " | " 
                      . $story . " | "
                      . $storySummary . " | "
                      . $fea . "|\n";
                }
            }
        }
    }
    $listComplete   .= "\n\n";
    $listIncomplete .= "\n\n";

    return $listComplete . $listIncomplete;
}

1;
