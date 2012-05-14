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
package TWiki::Plugins::XpTrackerPlugin::Cache;
use strict;

use TWiki::Plugins::XpTrackerPlugin;
use TWiki::Func;

my %cachedProjectTeams     = ();
my %cachedTeamIterations   = ();
my %cachedIterationStories = ();
my $loadedWeb              = "";

my @cachedProjects = ();

my $cacheFile         = ".xpcache";
my $projectsCacheFile = ".xpprojectcache";

#(RAF)
#If this module is load using the "use" directive before the plugin is
#initialized, $debug will be 0
#(CC) this will not work in Dakar; TWiki::Func methods cannot be called before initPlugin.
my $debug;

#my $debug = &TWiki::Func::getPreferencesFlag( "XPTRACKERPLUGIN_DEBUG" );
#&TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::Cache is loaded" ) if $debug;

#-------------------------------------------------------------------------------
sub initCache {
    my $web = shift;

    my $cacheFileName = &getCacheFileName( $web, $cacheFile );

    # if there is no disk cache file, build one
    if ( !( -e "$cacheFileName" ) ) {
        &TWiki::Func::writeDebug("NO CACHE, BUILDING DISK CACHE") if $debug;
        buildCache($web);
    }
    elsif ( !$web eq $loadedWeb ) {
        _readCache($cacheFileName);
        $loadedWeb = $web;

    }
}

#-------------------------------------------------------------------------------

sub _readCache {
    my $cacheFileName = shift;
    my $cacheText     = &TWiki::Func::readFile($cacheFileName);
    _cleanCache();

    while ( $cacheText =~ s/PROJ : (.*?) : (.*?)\n// ) {
        $cachedProjectTeams{$1} = "$2";
    }

    while ( $cacheText =~ s/TEAM : (.*?) : (.*?)\n// ) {
        $cachedTeamIterations{$1} = "$2";
    }

    while ( $cacheText =~ s/ITER : (.*?) : (.*?)\n// ) {
        $cachedIterationStories{$1} = "$2";
    }
}

#-------------------------------------------------------------------------------
sub _cleanCache {

    # Clean the current cache;
    %cachedProjectTeams     = ();
    %cachedTeamIterations   = ();
    %cachedIterationStories = ();
}

#-----------------------------------------------------------------------------
sub buildCache {
    my $web = shift;
    _cleanCache();

    my @topics = &TWiki::Func::getTopicList($web);
    foreach my $topic (@topics) {

#TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::Cache::buildCache $topic" );
        my $topicText = &TWiki::Func::readTopicText( $web, $topic );

        #Found a Story
        my $iteration =
          TWiki::Plugins::XpTrackerPlugin::xpGetValue( "\\*Iteration\\*",
            $topicText, "storyiter" );
        $cachedIterationStories{$iteration} .= "$topic "
          if ( _isValidTopic( $web, $iteration ) );

        #Found an Iteration
        my $team =
          TWiki::Plugins::XpTrackerPlugin::xpGetValue( "\\*Team\\*", $topicText,
            "notagsforthis" );
        $cachedTeamIterations{$team} .= "$topic "
          if ( _isValidTopic( $web, $team ) );

        #Found a team
        my $project =
          TWiki::Plugins::XpTrackerPlugin::xpGetValue( "\\*Project\\*",
            $topicText, "notagsforthis" );
        $cachedProjectTeams{$project} .= "$topic "
          if ( _isValidTopic( $web, $project ) );
    }

    # dump information to disk cache file
    my $projCache = "";
    my $teamCache = "";
    my $iterCache = "";
    my @projects  = getAllProjects($web);

    foreach my $project (@projects) {

        my @teams = getProjectTeams( $project, $web );
        $projCache .= "PROJ : $project : @teams \n";
        foreach my $team (@teams) {

            my @teamIters = getTeamIterations( $team, $web );
            $teamCache .= "TEAM : $team : @teamIters \n";
            foreach my $iter (@teamIters) {

                my @iterStories = getIterStories( $iter, $web );
                $iterCache .= "ITER : $iter : @iterStories \n";
            }
        }
    }

    my $cacheText = $projCache . $teamCache . $iterCache;
    &TWiki::Func::saveFile( getCacheFileName( $web, ".xpcache" ), $cacheText );
}

sub _isValidTopic {
    my ( $web, $topic ) = @_;
    return ( $topic && TWiki::Func::topicExists( $web, $topic ) );
}

#-----------------------------------------------------------------------------
sub getCacheFileName {
    my ( $web, $cacheFile ) = @_;

    # SMELL: update to use getWorkArea()
    return TWiki::Func::getDataDir() . "/" . $web . "/" . $cacheFile;
}

#-------------------------------------------------------------------------------
sub getAllProjects {
    return keys %cachedProjectTeams;
}

#-------------------------------------------------------------------------------
sub getProjectTeams {
    my ( $project, $web ) = @_;
    return
      defined( $cachedProjectTeams{$project} )
      ? split( /\s+/, $cachedProjectTeams{$project} )
      : ();

}

#-------------------------------------------------------------------------------
sub getTeamIterations {
    my ( $team, $web ) = @_;
    return
      defined( $cachedTeamIterations{$team} )
      ? split( /\s+/, $cachedTeamIterations{$team} )
      : ();
}

#-------------------------------------------------------------------------------
sub getIterStories {
    my ( $iteration, $web ) = @_;
    return
      defined( $cachedIterationStories{$iteration} )
      ? split( /\s+/, $cachedIterationStories{$iteration} )
      : ();
}

1;

