# See bottom of file for default license and copyright information

=pod

---+ package Foswiki::Plugins::JQuerymbComponentsPlugin

import and simplify the use of mb.ideas jQuery GUI components

=cut

package Foswiki::Plugins::JQuerymbComponentsPlugin;

use strict;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

our $VERSION = '$Rev: 7105 $';
our $RELEASE = '0.3';
our $SHORTDESCRIPTION =
  'import and simplify the use of mb.ideas jQuery GUI components';
our $NO_PREFS_IN_TOPIC = 1;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    if ( $Foswiki::cfg{Plugins}{JQueryPlugin}{Enabled} ) {
        require Foswiki::Plugins::JQueryPlugin;
        Foswiki::Plugins::JQueryPlugin::registerPlugin( "mb.menu",
            'Foswiki::Plugins::JQuerymbComponentsPlugin::MBMENU' );
    }

    # Plugin correctly initialized
    return 1;
}

1;
__END__
This copyright information applies to the JQuerymbComponentsPlugin:

Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

JQuerymbComponentsPlugin is Copyright (C) 2009-2010 SvenDowideit@fosiki.com
 
Foswiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code as follows:
Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved.

This license applies to JQuerymbComponentsPlugin and to any derivatives.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

For licensing info read LICENSE file in the root of this distribution.
