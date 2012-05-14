# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009 Sven Hess, shess@seibert-media.net
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

package Foswiki::Plugins::SectionPermissionPlugin;

use strict;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version

our $VERSION = '$Rev: 3048 (2009-03-12) $';
our $RELEASE = 'v1.0';
our $SHORTDESCRIPTION =
  'Deny or allow view of sections for specific wiki groups';
our $NO_PREFS_IN_TOPIC = 1;

# global vars
use vars qw($currentUser);

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    $currentUser = $user;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Plugin correctly initialized
    return 1;
}

sub commonTagsHandler {

    my ( $text, $topic, $web, $included, $meta ) = @_;

    while ( $_[0] =~
s/%STARTPERMISSION{(?!.*%STARTPERMISSION)(.*?)}%(.*?)%STOPPERMISSION%/&sectionPermissions($1, $2)/ges
      )
    {
    }

}

sub initCore {

    require Foswiki::Plugins::SectionPermissionPlugin::Core;
    Foswiki::Plugins::SectionPermissionPlugin::Core::init($currentUser);
}

sub sectionPermissions {

    initCore();
    return Foswiki::Plugins::SectionPermissionPlugin::Core::sectionPermissions(
        @_);
}

1;
