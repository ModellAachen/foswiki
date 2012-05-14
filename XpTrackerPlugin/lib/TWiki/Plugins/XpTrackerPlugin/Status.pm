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
#
# Manages the story and task coloring according to their completition status
#
# =========================
package TWiki::Plugins::XpTrackerPlugin::Status;
use strict;

#(RAF)
#If this module is load because using the "use" directive before the plugin is
#initialized, $debug will be 0
#(CC) this will not work in Dakar; TWiki::Func methods cannot be called before initPlugin.
my $debug;

# = &TWiki::Func::getPreferencesFlag( "XPTRACKERPLUGIN_DEBUG" );
#&TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::Status is loaded" ) if $debug;

# reasonable defaults for colouring. By default task and stories
# have the same colour schemes.
my %status = (
    unstarted  => [ '#FFCCCC', 'Not Started' ],
    inprogress => [ '#FFFF99', "In progress" ],
    finished   => [ '#99FF99', "Finished" ],
    acceptance => [ '#CCFFFF', "Acceptance" ],
    complete   => [ '#99FF99', "Complete" ],
    error      => [ '#999999', "Error" ],
    hold       => [ '#999999', "On Hold" ],
    deployment => [ '#99CCCC', "Deployment" ]
);

sub initModule() {
    my $v;
    foreach my $option ( keys %status ) {

        # read defaults from XpTrackerPlugin topic
        &TWiki::Func::writeDebug(
"- TWiki::Plugins::XpTrackerPlugin::Status XPTRACKERPLUGIN_\U$option\UCOLOR"
        ) if $debug;
        $v =
          &TWiki::Func::getPreferencesValue("XPTRACKERPLUGIN_\U$option\UCOLOR")
          || undef;
        $status{$option}[0] = $v if defined($v);
    }
}

sub getColor {
    my $status = shift;
    return $status{$status}[0];
}

sub getStatusS {
    my $status = shift;
    return $status{$status}[1];
}

sub getStatus {
    my ( $storySpent, $storyEtc, $storyComplete ) = @_;

    my $color      = "";
    my $storyStatS = "";
    my $desc       = "";

    if ( $storyEtc == 0 ) {
        if ( $storyComplete eq "Y" ) {
            $desc = "complete";
        }
        elsif ( $storyComplete eq "E" ) {
            $desc = "error";
        }
        elsif ( $storyComplete eq "D" ) {
            $desc = "deployment";
        }
        elsif ( $storyComplete eq "H" ) {
            $desc = "hold";
        }
        else {
            $desc = "acceptance";
        }
    }
    elsif ( $storySpent == 0 ) {
        $desc = "unstarted";
    }
    else {
        $desc = "inprogress";
    }

    $color      = $status{$desc}[0] || "";
    $storyStatS = $status{$desc}[1] || "";

    return ( $color, $storyStatS, $desc );
}

sub calculateStats {
    my ( $est, $spent, $todo ) = @_;
    $est   = $est   || 0;
    $spent = $spent || 0;
    $todo  = $todo  || 0;

    my $done = int(
        TWiki::Plugins::XpTrackerPlugin::Common::getPercentage(
            $spent, $spent + $todo
        )
    );
    my $overrun = int(
        TWiki::Plugins::XpTrackerPlugin::Common::getPercentage( $spent + $todo,
            $est ) - 100
    );

    $overrun = "+" . $overrun if ( $overrun > 0 );
    return ( $done, $overrun );
}

sub showColours {
    my ($web) = @_;

    my $table = "%TABLE{initsort=\"1\"}%\n";
    $table .= "|*name*|*colour*|*title*|\n";
    my ( $key, $value );

    # read colours and put them in table

    while ( ( $key, $value ) = each(%status) ) {
        $table .=
"|$key| <table width=\"100%\"><tr><td bgcolor=\"@$value[0]\">@$value[0]</td></tr></table>|@$value[1]|\n";
    }

    return $table

}

1;

