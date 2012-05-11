# See bottom of file for license and copyright details
package Foswiki::Plugins::PublishPlugin::PageAssembler;

use strict;

use Foswiki;
use Foswiki::Plugins;

# This module assembles a page from the text and the template,
# and does similar processing to that found in
# Foswiki::writeCompletePage - i.e. rendering the "head" and
# "script" zones and inserting them into the right place in
# the page. Later versions of Foswiki also render other zones
# at the same time.
#
# The challenge is that the Foswiki core has changed over time.
# Different versions of Foswiki do it differently, and the
# ZonePlugin patches the Foswiki core to do it in another
# slightly differently way.
#
# Therefore, this module contains code for each incarnation
# of the core, and chooses the right approach at runtime.

my $Assembler;

sub assemblePage {

    #my $publisher = shift;
    #my $tmpl = shift;
    #my $text = shift;

    $Assembler = _chooseMethod() unless $Assembler;

    return $Assembler->(@_);
}

sub _chooseMethod {
    if ( not $Foswiki::Plugins::VERSION or $Foswiki::Plugins::VERSION < 2.0 ) {

      # Ancient, or else not Foswiki - use something that is guaranteed to work.
        return \&_noHeadOrScriptZones;
    }
    elsif ( $Foswiki::Plugins::VERSION < 2.1 ) {

        # Foswiki 1.0.x - need to check if ZonePlugin is installed or not
        #
        # Cannot use the contexts because PublishPlugin "leaves" the
        # contexts for disabled plugins, but "leaving" the
        # ZonePluginEnabled context does not undo ZonePlugin's
        # monkey-patching.
        if ( $Foswiki::cfg{Plugins}{ZonePlugin}{Enabled} ) {

            # 1.0 with ZonePlugin - use a simple implementation
            # because ZonePlugin inserts zones in the completePageHandler
            return \&_noHeadOrScriptZones;
        }
        else {

            # 1.0 without ZonePlugin - mimic the behaviour of the core
            return \&_foswiki1x0NoZonePlugin;
        }

    }
    else {

        # Foswiki 1.1 or later - mimic the behaviour of the core
        return \&_foswiki1x1;
    }

    # Fall back on a very basic works-everywhere method
    return \&_noHeadOrScriptZones;
}

# This is the classic PublishPlugin way. The head and script zones are NOT rendered here.
sub _noHeadOrScriptZones {
    my $publisher = shift;
    my $tmpl      = shift;
    return $tmpl;
}

# This is for use with 1.0.x, WITHOUT the ZonePlugin
sub _foswiki1x0NoZonePlugin {
    my $publisher   = shift;
    my $tmpl        = shift;
    my $addedToHead = $Foswiki::Plugins::SESSION->RENDERHEAD();
    $tmpl =~ s/(<\/head>)/$addedToHead$1/;
    return $tmpl;
}

sub _foswiki1x1 {
    my $publisher = shift;
    my $tmpl      = shift;

    # nasty kludge. backup zone content for plugins which only call
    # addToZone during plugin initialization.  _renderZones deletes
    # the zone content and subsequent published topics will be missing
    # that content
    my $this = $Foswiki::Plugins::SESSION;
    my %zones;
    while ( my ( $zoneName, $zone ) = each %{ $this->{_zones} } ) {
        $zones{$zoneName} = {};

        $zones{$zoneName}{$_} = $zone->{$_}
          foreach grep { /^JQUERYPLUGIN::/ } keys %$zone;
    }

    my $result = $Foswiki::Plugins::SESSION->_renderZones($tmpl);

    $this->{_zones}{$_} = $zones{$_} for keys %zones;

    return $result;
}

1;

# Copyright (C) 2010 Arthur Clemens, http://visiblearea.com
# Copyright (C) 2010 Michael Tempest
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
# Removal of this notice in this or derivatives is forbidden.
