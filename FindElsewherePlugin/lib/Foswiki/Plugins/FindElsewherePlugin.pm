# See bottom of file for license and copyright details
# This is the FindElsewhere Foswiki plugin,
# see http://foswiki.org/Extensions/FindElsewherePlugin for details.
package Foswiki::Plugins::FindElsewherePlugin;

use strict;
use warnings;

our $NO_PREFS_IN_TOPIC = 1;
our $VERSION           = '$Rev$';
our $RELEASE           = '2.4';
our $SHORTDESCRIPTION =
"Automatically link to another web(s) if a topic isn't found in the current web.";

sub initPlugin {

    #my( $topic, $web, $user, $installWeb ) = @_;

    my $disabled = Foswiki::Func::getPreferencesFlag("DISABLELOOKELSEWHERE");
    unless ( defined($disabled) ) {

        # Compatibility, deprecated
        $disabled =
          Foswiki::Func::getPluginPreferencesFlag("DISABLELOOKELSEWHERE");
    }
    return 0 if $disabled;

    require Foswiki::Plugins::FindElsewherePlugin::Core;
    Foswiki::Plugins::FindElsewherePlugin::Core::initPlugin(@_);

    # Alias the handler to the one in the core package
    *Foswiki::Plugins::FindElsewherePlugin::preRenderingHandler =
      \&Foswiki::Plugins::FindElsewherePlugin::Core::preRenderingHandler;

    return 1;
}

1;
__END__
Copyright (C) 2002 Mike Barton, Marco Carnut, Peter HErnst
Copyright (C) 2003 Martin Cleaver
Copyright (C) 2004 Matt Wilkie
Copyright (C) 2007 Crawford Currie http://c-dot.co.uk
Copyright (C) 2008-2012 Foswiki Contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at 
http://www.gnu.org/copyleft/gpl.html

