# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
# =========================
#
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   earlyInitPlugin         ( )                                     1.020
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   beforeCommonTagsHandler ( $text, $topic, $web )                 1.024
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   afterCommonTagsHandler  ( $text, $topic, $web )                 1.024
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   afterSaveHandler        ( $text, $topic, $web, $errors )        1.020
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional.
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# =========================
package TWiki::Plugins::FakeBasicAuthRegPlugin
  ;    # change the package name and $pluginName!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $exampleCfgVar
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'FakeBasicAuthRegPlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

#    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
#    $exampleCfgVar = TWiki::Func::getPluginPreferencesValue( "EXAMPLE" ) || "default";

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub registrationHandler {
    my ( $web, $wikiName, $loginName ) =
      @_;    # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug(
        "- ${pluginName}::registrationHandler( $_[0], $_[1] )")
      if $debug;

    # Allows a plugin to set a cookie at time of user registration.
    # Called by the register script.

# The register script doesn't add the user to the password file if the userid
# is passed into it in the reg form (which is what happens in FakeBasicAuth)
# However, we really do want to create that user in the pw file but instead
# of using their wikiname, use there username and set the password to "password".
# FakeBasicAuth automatically logs you in using that password (see the SSL docs)
    if ( !TWiki::User::AddUserPassword( $loginName, "password" ) ) {

# well, what do we do here?  the register script doesn't handle errors from this handler
# do we redirect???
    }
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

 # do custom extension rule, like for example:
 # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
 # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
 #
 # The following allow us to dig at SSL cert env vars from the registration form
 #
 # Handle the varname, substitution from, to form first
    $_[0] =~
      s/%ENV{([^,}]+),([^,}]+),([^}]+)}%/&handleEnvVariableWSubs($1,$2,$3)/ge;

#    TWiki::Func::writeDebug("envvar: $1, subsfrom: $2, substo: $3") ;#if $debug;
# Handle the varname, substitution (removal) form next
    $_[0] =~ s/%ENV{([^,}]+),([^}]+)}%/&handleEnvVariableWSubs($1,$2)/ge;

    #    TWiki::Func::writeDebug("envvar: $1, subsfrom: $2") ;#if $debug;
    # Handle the varname form
    $_[0] =~ s/%ENV{([^}]+)}%/&handleEnvVariableWSubs($1)/ge;

    #    TWiki::Func::writeDebug("envvar: $1") ;#if $debug;
}

# Mostly a copy of TWiki.pm's version (but allows substitution)
sub handleEnvVariableWSubs {
    my ( $theVar, $subsfrom, $substo ) = @_;
    my $value = $ENV{$theVar} || "";

    #    TWiki::Func::writeDebug("envvar: $theVar = $value") ;#if $debug;
    if ( defined($subsfrom) ) {

        #        TWiki::Func::writeDebug("subsfrom: $subsfrom") ;#if $debug;
        $substo = "" unless ( defined($substo) );

        #	TWiki::Func::writeDebug("substo: $substo") ;#if $debug;
        $value =~ s/$subsfrom/$substo/ge;

        #	TWiki::Func::writeDebug("new value: $value") ;#if $debug;
    }
    return $value;
}

1;
