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

package TWiki::Plugins::XpTrackerPlugin::ShowProjectTeams;

use HTTP::Date;
use TWiki::Func;
use TWiki::Plugins::XpTrackerPlugin;

#(RAF)
#If this module is load using the "use" directive before the plugin is
#initialized, $debug will be 0
#(CC) this will not work in Dakar; TWiki::Func methods cannot be called before initPlugin.
my $debug;

#my $debug = &TWiki::Func::getPreferencesFlag( "XPTRACKERPLUGIN_DEBUG" );
#&TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::ShowProjectTeams is loaded" ) if $debug;

sub xpShowProjectTeams {

    my ( $project, $web ) = @_;

    my @projTeams =
      &TWiki::Plugins::XpTrackerPlugin::xpGetProjectTeams( $project, $web );

    my $list = TWiki::Plugins::XpTrackerPlugin::HtmlUtil::emmitTwikiHeader( 3,
        "All teams for project " . $project );

    $list .= TWiki::Plugins::XpTrackerPlugin::HtmlUtil::emmitArrayInBullets(
        @projTeams);

    # append CreateNewTeam form
    $list .= &TWiki::Plugins::XpTrackerPlugin::xpCreateHtmlForm(
        "NewnameTeam",
        &TWiki::Func::getPreferencesValue("XPTRACKERPLUGIN_TEAMTEMPLATE"),
        "Create new team for <nop>" . $project . " project"
    );

    return $list;
}

1;
