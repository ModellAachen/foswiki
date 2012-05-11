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
# 2004-02-28 RafaelAlvarez Replace all the calls of "unofficial" subs
#                          with their equivalent in the Func module.
# =========================
package TWiki::Plugins::XpTrackerPlugin::Common;
use TWiki::Func;
use TWiki::Plugins::XpTrackerPlugin;
use TWiki::Plugins::XpTrackerPlugin::Task;
use TWiki::Plugins::XpTrackerPlugin::Story;
use TWiki::Plugins::XpTrackerPlugin::Iteration;

sub getStoryTasks {
    my @tasks = ();

    while (1) {
        (
            my $status, my $name, my $est, my $who, my $spent, my $etc,
            my $tstatus, my $reviewer
        ) = TWiki::Plugins::XpTrackerPlugin::xpGetNextTask( $_[0] );
        last if ( !$status );

        my $task = new TWiki::Plugins::XpTrackerPlugin::Task();
        $task->name($name);
        $task->est($est);
        $task->who($who);
        $task->reviewer($reviewer);
        $task->spent($spent);
        $task->etc($etc);
        $task->tstatus($tstatus);

        push @tasks, $task;
    }
    return @tasks;
}

sub loadStories {
    my ( $web, $iterationName ) = @_;
    my @storiesTitles =
      TWiki::Plugins::XpTrackerPlugin::xpGetIterStories( $iterationName, $web );
    return loadStoriesByTitle( $web, @storiesTitles );
}

sub loadStoriesByTitle {
    my $web     = shift;
    my @stories = ();
    foreach my $storyTitle (@_) {
        push @stories,
          new TWiki::Plugins::XpTrackerPlugin::Story( $web, $storyTitle );
    }
    return @stories;
}

sub loadTeamIterations {
    my ( $web, $team, $dontSummarize ) = @_;
    my @iterations = ();
    my @teamIters =
      &TWiki::Plugins::XpTrackerPlugin::xpGetTeamIterations( $team, $web );
    foreach my $iter (@teamIters) {
        my $iteration =
          new TWiki::Plugins::XpTrackerPlugin::Iteration( $web, $iter );
        $iteration->summarize() unless $dontSummarize;
        push @iterations, $iteration;
    }
    return @iterations;
}

sub getPercentage {
    my ( $a, $b ) = @_;

    if ( $b == 0 && $a == 0 ) {
        return 100;
    }
    elsif ( $b > 0 && $a > 0 ) {
        return 100 * $a / $b;
    }
    else {
        return 0;
    }
}

sub acceptanceTestStatus {
    my $storyComplete = "N";
    my $ret           = &TWiki::Plugins::XpTrackerPlugin::xpGetValue(
        "\\*Passed acceptance test\\*",
        $_[0], "complete" );
    if ($ret) {
        $storyComplete = uc( substr( $ret, 0, 1 ) );
    }

    return $storyComplete;
}

sub readStoryText {
    my ( $web, $story ) = @_;

    my $storyText = &TWiki::Func::readTopicText( $web, $story );
    $storyText =~ s/%META.*?%//go;
    $storyText =~ s/%TOPIC%/$story/go;

    return $storyText;
}

1;
