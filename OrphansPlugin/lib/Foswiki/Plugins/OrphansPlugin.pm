# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Wind River
# Plugin written by http://Foswiki.org/cgi-bin/view/Main/CrawfordCurrie
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
# Plugin that supports content management operations
#
package Foswiki::Plugins::OrphansPlugin;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION );

$VERSION          = '$Rev$';
$RELEASE          = '07 Nov 2009';
$SHORTDESCRIPTION = 'Locate and manage orphaned topics';

sub initPlugin {

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.1 ) {
        die "Require Plugins.pm >= 1.1";
    }

    Foswiki::Func::registerTagHandler( 'FINDORPHANS', \&_findOrphans );

    return 1;
}

# Handle the "FINDORPHANS" tag
sub _findOrphans {
    my ( $session, $params, $topic, $web ) = @_;
    require Foswiki::Plugins::OrphansPlugin::Orphans;
    my $orphans = new Foswiki::Plugins::OrphansPlugin::Orphans( $web, $params );
    return $orphans->tabulate($params);
}

1;
