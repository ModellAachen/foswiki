# See bottom of file for license and copyright information
#
# See Plugin topic for history and plugin information

=begin TML

---+ package Foswiki::Plugins::AntiWikiSpamPlugin

AntiWikiSpam plugin uses the shared Anti-spam regex list to 
check topic text when saving, refusing to save if it finds a match.

=cut

package Foswiki::Plugins::AntiWikiSpamPlugin;

use Error qw(:try);
use strict;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version

our $VERSION           = '$Rev$';
our $RELEASE           = '1.3.2';
our $SHORTDESCRIPTION  = 'Lightweight wiki spam prevention';
our $NO_PREFS_IN_TOPIC = 1;

#### Plugin handlers

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    #forceUpdate
    Foswiki::Func::registerRESTHandler( 'forceUpdate', \&_RESTforceUpdate );

    Foswiki::Func::registerRESTHandler(
        'removeUser', \&_RESTremoveUser,
        authenticate => 1,
        validate     => 1,
        http_allow   => 'POST'
    );

    return 1;
}

sub beforeSaveHandler {
    require Foswiki::Plugins::AntiWikiSpamPlugin::Core;
    return Foswiki::Plugins::AntiWikiSpamPlugin::Core::beforeSaveHandler(@_);
}

sub beforeAttachmentSaveHandler {
    require Foswiki::Plugins::AntiWikiSpamPlugin::Core;
    return
      Foswiki::Plugins::AntiWikiSpamPlugin::Core::beforeAttachmentSaveHandler(
        @_);
}

# Handler for $Foswiki::Plugins::VERSION 2.3 and later
sub validateRegistrationHandler {
    require Foswiki::Plugins::AntiWikiSpamPlugin::Core;
    return
      Foswiki::Plugins::AntiWikiSpamPlugin::Core::validateRegistrationHandler(
        @_);
}

# Check a registration to see if the email address used is blacklisted
sub registrationHandler {
    return
      if $Foswiki::Plugins::VERSION >=
          2.3;    # 2.3 uses validateRegistrationHandler

    require Foswiki::Plugins::AntiWikiSpamPlugin::Core;
    return Foswiki::Plugins::AntiWikiSpamPlugin::Core::registrationHandler(@_);
}

#### REST handlers

# can be used to force an update of the spam list
# %SCRIPTURL%/rest/AntiWikiSpamPlugin/forceUpdate
sub _RESTforceUpdate {
    require Foswiki::Plugins::AntiWikiSpamPlugin::Core;
    return Foswiki::Plugins::AntiWikiSpamPlugin::Core::_RESTforceUpdate(@_);
}

# Remove a user. Expunge them utterly.
# Passed with param: user, which can be a wikiname or a login name
# Calls the removeUser function to remove the registration
# Moves the user topic to SuspectSpammer
# %SCRIPTURL%/rest/AntiWikiSpamPlugin/removeUser?user=name
# name can be a wikiname or a login name
sub _RESTremoveUser {
    require Foswiki::Plugins::AntiWikiSpamPlugin::Core;
    return Foswiki::Plugins::AntiWikiSpamPlugin::Core::_RESTremoveUser(@_);
}

1;
__END__
Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2005-2009 Sven Dowideit SvenDowideit@wikiring.com
Copyright (C) 2009-2012 George Clark
Copyright (C) 2012 Crawford Currie http://c-dot.co.uk

AntiWikiSpamPlugin is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

For licensing info read LICENSE file in the Foswiki root.
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

As per the GPL, removal of this notice is prohibited.
