#
# Copyright (C) 2004 Rafael Alvarez, soronthar@yahoo.com
#
# Authors (in alphabetical order)
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

package TWiki::Plugins::XpTrackerPlugin::Story;
use TWiki::Plugins::XpTrackerPlugin;
use TWiki::Plugins::XpTrackerPlugin::Common;
use TWiki::Plugins::XpTrackerPlugin::Status;

sub new {
    my ( $type, $web, $name ) = @_;
    my $object = {
        name => $name,
        web  => $web,

        #Story info
        FEA          => "",
        order        => "",
        storySummary => "",
        storyLead    => "",
        iteration    => "",

        #Completition Status
        storyComplete => "",

        #Story Summary
        storySpent   => "",
        storyEtc     => "",
        storyCalcEst => "",

        #Story Status
        status     => "",
        color      => "#FFFFFF",
        storyStatS => "",
        done       => 0,
        overrun    => 0,

        #Assigned Staff
        all         => "",
        allReviewer => "",

        #Tasks
        _tasks => []
    };
    bless $object;
    $object->_processStoryText();
    return $object;
}

sub cmp {
    my ( $self, $toCompare ) = @_;
    return $self->order cmp $toCompare->order;
}

sub _processStoryText {
    my $self = shift;
    my $storyText = &TWiki::Func::readTopicText( $self->web, $self->name );
    $self->{storyComplete} =
      TWiki::Plugins::XpTrackerPlugin::Common::acceptanceTestStatus($storyText);
    $self->{storyLead} =
      &TWiki::Plugins::XpTrackerPlugin::xpGetValue( "\\*Story Lead\\*",
        $storyText, "storyLead" );
    $self->{FEA} =
      TWiki::Plugins::XpTrackerPlugin::xpGetValue( "\\*FEA\\*", $storyText,
        "notagsforthis" );
    $self->{iteration} =
      TWiki::Plugins::XpTrackerPlugin::xpGetValue( "\\*Iteration\\*",
        $storyText, "notagsforthis" );

    $self->{order} = $self->{FEA};

    if ( length $self->{order} < 2 ) {
        $self->{order} = "0" . $self->{order};
    }
    if ( length $self->{order} < 3 ) {
        $self->{order} = "0" . $self->{order};
    }

    $self->{storySummary} =
      TWiki::Plugins::XpTrackerPlugin::xpGetValue( "\\*Story summary\\*",
        $storyText, "notagsforthis" );

    _sumarize( $self, $storyText );

}

sub _sumarize {
    my $self  = $_[0];
    my @tasks = TWiki::Plugins::XpTrackerPlugin::Common::getStoryTasks( $_[1] );

    my ( $storySpent, $storyEtc, $storyCalcEst ) = 0;
    my $all         = "";
    my $allReviewer = "";

    foreach $task (@tasks) {
        my @spentList =
          TWiki::Plugins::XpTrackerPlugin::xpRipWords( $task->spent );
        foreach my $spent (@spentList) {
            $storySpent += $spent;
        }

        my @etcList = TWiki::Plugins::XpTrackerPlugin::xpRipWords( $task->etc );
        foreach my $etc (@etcList) {
            $storyEtc += $etc;
        }

        my @estList = TWiki::Plugins::XpTrackerPlugin::xpRipWords( $task->est );
        foreach my $etc (@estList) {
            $storyCalcEst += $etc;
        }

        my $who = $task->who;
        $who =~ s/^\s+//;
        $who =~ s/\s+$//;
        $all .= $who . " " unless ( $all =~ /$who/ );

        my $reviewer = $task->reviewer;
        $reviewer =~ s/^\s+//;
        $reviewer =~ s/\s+$//;
        $allReviewer .= $reviewer . " " unless ( $allReviewer =~ /$reviewer/ );

    }

    my ( $color, $storyStatS, $status ) =
      TWiki::Plugins::XpTrackerPlugin::Status::getStatus( $storySpent,
        $storyEtc, $self->storyComplete );
    my ( $done, $overrun ) =
      TWiki::Plugins::XpTrackerPlugin::Status::calculateStats( $storyCalcEst,
        $storySpent, $storyEtc );

    $self->storySpent($storySpent);
    $self->storyEtc($storyEtc);
    $self->storyCalcEst($storyCalcEst);
    $self->{done}    = $done;
    $self->{overrun} = $overrun;

    $self->all($all);
    $self->allReviewer($allReviewer);
    $self->storyStatS($storyStatS);
    $self->color($color);
    $self->status($status);

    $self->{_tasks} = \@tasks;
}

sub tasks {
    my $self = shift;
    return @{ $self->_tasks };
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
