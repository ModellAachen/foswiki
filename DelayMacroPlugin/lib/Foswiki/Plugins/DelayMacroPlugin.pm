# See bottom of file for default license and copyright information

=begin TML

---+ package DelayMacroPlugin

This is a simple plugin that can delay the expansion of macros.
You use this when you have a macro inside another macro and that supports
tokens $percnt and $quot such as SEARCH and you want this macro to expand
after the SEARCH is complete.

=cut

# change the package name!!!
package Foswiki::Plugins::DelayMacroPlugin;

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
our $RELEASE = '1.1';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION = 'Plugin delays expansion of Foswiki macros';

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

    Foswiki::Func::registerTagHandler( 'DELAY', \&_delayMacro );

    Foswiki::Func::registerTagHandler( 'DELAYSEARCH', \&_delayMacro );

    # Plugin correctly initialized
    return 1;
}

# delayMacro expands %DELAY.. and returns
# DELAY hidden by $percnt and $quot if delay > 0
# The macro specified by macro parameter if delay = 0
sub _delayMacro {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    # $session  - a reference to the Foswiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a Foswiki::Attrs object containing
    #             parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             (unnamed) parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the macro. This will replace the
    # macro call in the final text.

    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # INPUT will be 'onions'

    my $delay = defined $params->{delay} ? $params->{delay} : 1;
    $delay = 1 unless $delay =~ /\d+/;
    my $macro = $params->{macro} || 'SEARCH';
    my $default = defined $params->{_DEFAULT} ? $params->{_DEFAULT} : '';
    my $result = '';

    if ( $delay-- > 0 ) {
        $result = "\$percntDELAY{";
        $result .= "\$quot$default\$quot ";
        $result .= "delay=\$quot$delay\$quot ";

        foreach my $key ( keys %$params ) {
            next if ( $key eq '_RAW' || $key eq '_DEFAULT' || $key eq 'delay' );

            $result .= "$key=\$quot" . $params->{$key} . "\$quot ";
        }
        $result .= "}\$percnt";
    }
    else {
        $result = "%" . $macro . "{";
        $result .= "\"$default\" ";

        foreach my $key ( keys %$params ) {
            next
              if ( $key eq '_RAW'
                || $key eq '_DEFAULT'
                || $key eq 'macro'
                || $key eq 'delay' );

            $result .= $key . "=\"" . $params->{$key} . "\" ";
        }

        $result .= "}%";
    }

    return $result;

}

1;
__END__

# This copyright information applies to the DelayMacroPlugin:
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
