#
# Copyright (C) 2002 Lecando AB, http://www.lecando.com
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
#
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional.
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# =========================
package TWiki::Plugins::RollupPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  $exampleCfgVar $totalEstimatedTime $totalActualTime
  $totalRemainingTime
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between EmptyPlugin and Plugins.pm");
        return 0;
    }

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::RollupPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

# =========================
sub commonTagsHandler {
    $_[0] =~ s/%ROLLUP{(.*?)}%/&rollup($1)/geo;
    $_[0] =~ s/%ROLLUP%/&rollup()/geo;
}

#==========================#
# sub methods not part     #
# of plugin API            #
#==========================#

#=================================================
# Identifies the topic to rollup and
# does just that.
#=================================================
sub rollup {
    my ($tempTopic) = @_;

    $tempTopic = $topic if $tempTopic eq "";

    my ($topicToSearch) =
      concatenateStringArray( &TWiki::Func::readTopic( $web, $tempTopic ) );
    my ($returnString) = "---++ Rollup of <nop>" . $tempTopic . ":\n---\n";
    $returnString .= getStories($topicToSearch) . "\n";
    $returnString .= "---+++ Total For Iteration \n";
    $returnString .=
      "|*All Tasks*| *Estimated Time* | *Actual Time* | *Remaining Time* |\n";
    $returnString .=
        "|All|  "
      . $totalEstimatedTime . " |  "
      . $totalActualTime . " |  "
      . $totalRemainingTime . " |\n";

}

#=================================================
# Finds the stories in the given topic. Iterates
# through them to find tasks.
#=================================================
sub getStories {
    my ($topicToSearch) = @_;
    my ($returnString);
    my (@stories) = findTopicWithSuffix( $topicToSearch, "Story" );
    foreach $story (@stories) {
        my ($storyString) =
          concatenateStringArray( &TWiki::Func::readTopic( $web, $story ) );
        $returnString .= "---++++ <nop>" . $story . "\n";
        $returnString .= "_Developer:" . getDeveloper($storyString) . "_\n\n";
        $returnString .= getTasks($storyString);
    }
    $returnString .= "---\n";

    # Might have tasks in story
    my ($iterationTasks) = getTasks($topicToSearch);
    $returnString .= "---++++ Iteration Tasks \n\n" . $iterationTasks
      if ( $iterationTasks ne "" );
    $returnString .= "---";
    return $returnString;
}

#=================================================
# Finds the the entry Developer:
# and returns what is entered after it
#=================================================
sub getDeveloper {
    my ($topicToSearch) = @_;
    $topicToSearch =~ /(.*?)\b(.*Developer:\D?)\b(\w*)/g;
    return $3;
}

#=================================================
# Finds the tasks in a story
#=================================================
sub getTasks {
    my ($topicToSearch) = @_;
    my ($returnString) =
      "| *Task* | *Estimated Time* | *Actual Time* | *Remaining Time* |\n ";
    my (@tasks) = findTopicWithSuffix( $topicToSearch, "Task" );

    my ($sumEstimatedTime);
    my ($sumActualTime);
    my ($sumRemainingTime);
    foreach $task (@tasks) {
        my ($topicToSearch) =
          concatenateStringArray( &TWiki::Func::readTopic( $web, $task ) );
        my $estimatedTime = findTime( $topicToSearch, "EstimatedTime:" );
        my $actualTime    = findTime( $topicToSearch, "ActualTime:" );
        my $remainingTime = findTime( $topicToSearch, "RemainingTime:" );
        $sumEstimatedTime   += $estimatedTime;
        $totalEstimatedTime += $estimatedTime;
        $sumActualTime      += $actualTime;
        $totalActualTime    += $actualTime;
        $sumRemainingTime   += $remainingTime;
        $totalRemainingTime += $remainingTime;
        $returnString .=
            "|<nop>" 
          . $task . "|  "
          . $estimatedTime . " |  "
          . $actualTime . " |  "
          . $remainingTime . " |\n";
    }
    $returnString .=
        "|*Sum:*|  *"
      . $sumEstimatedTime
      . "* |  *"
      . $sumActualTime
      . "* |  *"
      . $sumRemainingTime . "* |\n";
    return $returnString;
}

#=================================================
# Returns all the topics with a given suffix within a given topic.
#=================================================
sub findTopicWithSuffix {
    my ( $topicTo, $suffix ) = @_;
    my (@topics);
    while ( $topicTo =~ /(.*?)\b(.*$suffix)\b/gm ) {
        $topics[ ++$#topics ] = $2;
        $topicNo++;
    }
    return @topics;
}

#=================================================
# Finds numbered value after a given entry
#=================================================
sub findTime {
    my ( $topicToSearch, $timeToFind ) = @_;
    $topicToSearch =~ /(.*?)\b($timeToFind\D*?)\b(\d*)/g;
    return $3;

}

#=================================================
# Takes a array of strings and concatenates them
#=================================================
sub concatenateStringArray {
    my ($concatenatedString);
    foreach $part (@_) {
        $concatenatedString .= $part;
    }
    return $concatenatedString;
}

1;

