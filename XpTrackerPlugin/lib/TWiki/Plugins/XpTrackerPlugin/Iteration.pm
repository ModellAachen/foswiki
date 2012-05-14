#
# Copyright (C) 2004 Rafael Alvarez, soronthar@yahoo.com
#
# Authors (in alphabetical order)
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
# Represents a Team Iteration
# =========================
# 2004-02-28 RafaelAlvarez Replace all the calls of "unofficial" subs
#                          with their equivalent in the Func module.
# =========================
package TWiki::Plugins::XpTrackerPlugin::Iteration;
use HTTP::Date;
use TWiki::Func;
use TWiki::Plugins::XpTrackerPlugin::Common;
use TWiki::Plugins::XpTrackerPlugin;

#(RAF)
#If this module is load using the "use" directive before the plugin is
#initialized, $debug will be 0
#(CC) this will not work in Dakar; TWiki::Func methods cannot be called before initPlugin.
my $debug;

#my $debug = &TWiki::Func::getPreferencesFlag( "XPTRACKERPLUGIN_DEBUG" );
#&TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::Iteration is loaded" ) if $debug;

sub new {
    my ( $type, $web, $name ) = @_;
    my $iteration = {
        name        => $name,
        web         => $web,
        startDate   => "",
        endDate     => "",
        remaining   => 0,
        order       => 0,
        summary     => "",
        spent       => 0,
        todo        => 0,
        est         => 0,
        done        => 0,
        overrun     => 0,
        numberStory => 0,
        length      => 0
    };

    bless $iteration;
    my $iterText = &TWiki::Func::readTopicText( $web, $name );

    $iteration->{startDate} =
      &TWiki::Plugins::XpTrackerPlugin::xpGetValueAndRemove( "\\*Start\\*",
        $iterText, "START" );
    $iteration->{startDate} =~
      s!([0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9][0-9]).*!$1!;
    $iteration->{endDate} =
      &TWiki::Plugins::XpTrackerPlugin::xpGetValueAndRemove( "\\*End\\*",
        $iterText, "notagsforthis" );
    $iteration->{endDate} =~
      s!([0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9][0-9]).*!$1!;

    if ( $iteration->{endDate} ) {
        $iteration->{remaining} =
          HTTP::Date::str2time( $iteration->{endDate} ) - time;
        if ( $iteration->{startDate} ) {
            my $days = int(
                (
                    HTTP::Date::str2time( $iteration->{endDate} ) -
                      HTTP::Date::str2time( $iteration->{startDate} )
                ) / 86400
            );
            $days = $days - ( int( $days / 7 ) * 2 ); #Two free days each 7 days
            $iteration->{length} = $days;
        }
    }

    $iteration->{summary} =
      &TWiki::Plugins::XpTrackerPlugin::xpGetValueAndRemove( "\\*Summary\\*",
        $iterText, "notagsforthis" );

    my $iterSec = HTTP::Date::str2time( $iteration->startDate ) - time
      if ( $iteration->startDate );
    $iterSec = 0 unless $iteration->startDate;
    $iteration->order($iterSec);

    return $iteration;
}

sub summarize {
    my $self = shift;
    my @stories =
      TWiki::Plugins::XpTrackerPlugin::Common::loadStories( $self->web,
        $self->name );
    my ( $totalSpent, $totalEtc, $totalEst ) = 0;
    my $count = 0;
    foreach my $story (@stories) {
        $totalSpent += $story->storySpent;
        $totalEtc   += $story->storyEtc;
        $totalEst   += $story->storyCalcEst;
        $count      += 1;
    }

    # Do iteration totals
    my ( $done, $overrun ) =
      TWiki::Plugins::XpTrackerPlugin::Status::calculateStats( $totalEst,
        $totalSpent, $totalEtc );

    $self->{spent} = $totalSpent || 0;
    $self->{todo}  = $totalEtc   || 0;
    $self->{est}   = $totalEst   || 0;
    $self->{done}  = $done;
    $self->{overrun}     = $overrun;
    $self->{numberStory} = $count;
}

sub AUTOLOAD {
    my $self  = shift;
    my $field = $AUTOLOAD;
    $field =~ s/.*://;
    if ( exists $self->{$field} ) {
        if (@_) {
            return $self->{$field} = shift;
        }
        else {
            return $self->{$field};
        }
    }
}

1;
