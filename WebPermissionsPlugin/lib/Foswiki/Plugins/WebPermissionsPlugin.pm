# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) Evolved Media Network 2005
# Copyright (C) Spanlink Communications 2006
# and Foswiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.
#
# Author: Crawford Currie http://c-dot.co.uk
#
# This plugin helps with permissions management by displaying the web
# permissions in a big table that can easily be edited. It updates WebPreferences
# in each affected web.

package Foswiki::Plugins::WebPermissionsPlugin;

use strict;

use Foswiki::Func ();

our $VERSION           = '$Rev: 160$';
our $RELEASE           = '9 Jun 2010';
our $SHORTDESCRIPTION  = 'View and edit web permissions';
our $NO_PREFS_IN_TOPIC = 1;

use constant TRACE => 0;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.10 ) {
        Foswiki::Func::writeWarning(
            'Version mismatch between WebPermissionsPlugin and Foswiki::Plugins'
        );
        return 0;
    }

    Foswiki::Func::registerTagHandler( 'WEBPERMISSIONS', \&_WEBPERMISSIONS );
    Foswiki::Func::registerTagHandler( 'TOPICPERMISSIONS',
        \&_TOPICPERMISSIONS );

    # SMELL: need to disable this if the USERSLIST code is ever moved into the
    # core.
    Foswiki::Func::registerTagHandler( 'USERSLIST', \&_USERSLIST );

    Foswiki::Func::registerRESTHandler( 'change', \&_changeHandler );

    return 1;
}

sub _changeHandler {
    my $session = shift;
    require Foswiki::Plugins::WebPermissionsPlugin::Core;
    Foswiki::Plugins::WebPermissionsPlugin::Core::changeHandler($session);
}

sub _WEBPERMISSIONS {
    my ( $session, $params, $topic, $web ) = @_;

    #return undef unless Foswiki::Func::isAdmin();

    require Foswiki::Plugins::WebPermissionsPlugin::Core;
    Foswiki::Plugins::WebPermissionsPlugin::Core::WEBPERMISSIONS(@_);
}

#TODO: add param topic= and show= specify to list only groups / only users / both
sub _TOPICPERMISSIONS {
    require Foswiki::Plugins::WebPermissionsPlugin::Core;
    return Foswiki::Plugins::WebPermissionsPlugin::Core::TOPICPERMISSIONS(@_);
}

sub _USERSLIST {
    require Foswiki::Plugins::WebPermissionsPlugin::Core;
    return Foswiki::Plugins::WebPermissionsPlugin::Core::USERSLIST(@_);
}

#TODO: rejig this so it works for the WEBPERMS too
sub beforeSaveHandler {
    require Foswiki::Plugins::WebPermissionsPlugin::Core;
    return Foswiki::Plugins::WebPermissionsPlugin::Core::beforeSaveHandler(@_);
}

1;
