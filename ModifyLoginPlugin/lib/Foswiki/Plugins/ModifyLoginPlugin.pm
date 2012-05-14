# See bottom of file for default license and copyright information

=begin TML

---+ package ModifyLoginPlugin

This is a simple plugin that can convert the login provided by the user
to a the format needed by Foswiki server to identify the user.

It is typically used when you have a single sign on scheme like mod_ldap
where the login name can be authenticated in more than one way. Typically
ldap servers will authenticate users without paying attention to case.

This means that the same user can be authenticated as ABC123 and abc123

Foswiki however is case sensitive. This means that users that sometimes use
uppercase and sometimes lowercase login will often not be recognized by
Foswiki but appear with their raw login name and maybe be denied access.

Using this plugin you can set 
Foswiki::cfg{Plugins}{ModifyLoginPlugin}{ChangeCase} to 'lower' and the user
will always have his login name converted to lowercase.

Foswiki will then always see the user as his lowercase login.

The plugin has one additional independent feature. It can assign a login name
based on a specific path. This is used to open a controlled backdoor to
Foswiki via a specific list of topics. This enables creating a special user
with a carefully assigned set of access rights. A typical use is to create
a query page that can lookup information within a web without authentication.

A plugin may be implemented to look directly at the ENV and use the
REMOTE_USER directly. This plugin cannot deal with that. But most plugin
should behave correctly.

=cut

# change the package name!!!
package Foswiki::Plugins::ModifyLoginPlugin;

# Always use strict to enforce variable scoping
use strict;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package. This should always be in the format
# $Rev: 5771 $ so that Foswiki can determine the checked-in status of the
# extension.
our $VERSION = '$Rev: 5771 $';

# $RELEASE is used in the "Find More Extensions" automation in configure.
our $RELEASE = '2.0';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
  'The plugin can modify a login by changing case or stripping all after @';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use
# preferences set in the plugin topic. This is required for compatibility
# with older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, leave $NO_PREFS_IN_TOPIC at 1 and use
# =$Foswiki::cfg= entries, or if you want the users
# to be able to change settings, then use standard Foswiki preferences that
# can be defined in your %USERSWEB%.SitePreferences and overridden at the web
# and topic level.
#
# %SYSTEMWEB%.DevelopingPlugins has details of how to define =$Foswiki::cfg=
# entries so they can be used with =configure=.
our $NO_PREFS_IN_TOPIC = 1;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

*REQUIRED*

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using =Foswiki::Func::writeWarning= and return 0. In this case
%<nop>FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

__Note:__ Please align macro names with the Plugin name, e.g. if
your Plugin is called !FooBarPlugin, name macros FOOBAR and/or
FOOBARSOMETHING. This avoids namespace issues.

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Plugin correctly initialized
    return 1;
}

=begin TML

---++ initializeUserHandler( $loginName, $url, $pathInfo )
   * =$loginName= - login name recovered from $ENV{REMOTE_USER}
   * =$url= - request url
   * =$pathInfo= - pathinfo from the CGI query
Allows a plugin to set the username. Normally Foswiki gets the username
from the login manager. This handler gives you a chance to override the
login manager.

Return the *login* name.

This handler is called very early, immediately after =earlyInitPlugin=.

*Since:* Foswiki::Plugins::VERSION = '2.0'

=cut

sub initializeUserHandler {
    my ( $loginName, $url, $pathInfo ) = @_;

    # Map path to special users unless you are already authenticated as an
    # AdminGroup member
    if (
        defined $Foswiki::cfg{Plugins}{ModifyLoginPlugin}{MapPathToUser}
        {$pathInfo}
        && !Foswiki::Func::isAnAdmin($loginName) )
    {
        return $Foswiki::cfg{Plugins}{ModifyLoginPlugin}{MapPathToUser}
          {$pathInfo};
    }

  # Change case of login name
  # This plugin assumes {Register}{AllowLoginName}, otherwise it will do nothing

    return $loginName unless $Foswiki::cfg{Register}{AllowLoginName};

    if ( $Foswiki::cfg{Plugins}{ModifyLoginPlugin}{ChangeCase} eq 'lowercase' )
    {
        $loginName = lc($loginName);
    }
    elsif (
        $Foswiki::cfg{Plugins}{ModifyLoginPlugin}{ChangeCase} eq 'uppercase' )
    {
        $loginName = uc($loginName);
    }

    # Strip everything from @ till the end of the login incl @
    if ( $Foswiki::cfg{Plugins}{ModifyLoginPlugin}{StripAfterAtsign} ) {
        $loginName =~ s/@.*$//;
    }

    return $loginName;
}

1;
__END__

# This copyright information applies to the ModifyLoginPlugin:
#
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# ModifyLoginPlugin is Copyright (C) 2010 Kenneth Lavrsen.
# 
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# This license applies to CaseInsensitiveUserPlugin and to any derivatives.
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
# For licensing info read LICENSE file in the root of this distribution.
