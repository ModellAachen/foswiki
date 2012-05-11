#
# Foswiki
#
# Copyright (C) 2001 Motorola
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

package Foswiki::Plugins::TocPlugin;

our $VERSION = '$Rev$';
our $RELEASE = '2.1.1';
our $wif;
our $SHORTDESCRIPTION  = 'Sophisticated table of contents generation';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    return 1;
}

sub preRenderingHandler {
    require Foswiki::Plugins::TocPlugin::TOCIF;
    require Foswiki::Plugins::TocPlugin::TOC;
    my $session = $Foswiki::Plugins::SESSION;
    my ( $web, $topic ) = ( $session->{webName}, $session->{topicName} );
    $wif ||= Foswiki::Plugins::TocPlugin::TOCIF->getInterface( $web, $topic );
    $_[0] =
      Foswiki::Plugins::TocPlugin::TOC::processTopic( $wif, $web, $topic,
        $_[0] );
    $_[0] =~ s/%TOCBUTTONS%//go;    #dzus ugly fix - FIXME in time
}

1;
