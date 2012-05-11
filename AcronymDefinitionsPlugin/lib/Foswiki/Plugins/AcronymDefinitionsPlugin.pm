# See bottom of file for default license and copyright information

package Foswiki::Plugins::AcronymDefinitionsPlugin;

use strict;
use warnings;

# This should always be $Rev: 12204 (2011-07-23) $ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
our $VERSION = '$Rev: 12204 (2011-07-23) $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
our $RELEASE = '0.1';

# Short description of this plugin
# # One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
'A plugin to wrap acronyms in an HTML "acronym" element with "title" attribute';

# %SYSTEMWEB%.DevelopingPlugins has details of how to define =$Foswiki::cfg=
# entries so they can be used with =configure=.
our $NO_PREFS_IN_TOPIC = 1;

# Module variables used between functions within this module
my $disabled = 0;
my $web;
my $user;    # For access control checking - passed from initPlugin
my %prefs;
my $debug;

my %acronyms;

BEGIN {

    # Do a dynamic 'use locale' for this module
    if ( $Foswiki::useLocale || $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub initPlugin {

    my $topic = $_[0];
    $web  = $_[1];
    $user = $_[2];
    my $installWeb = $_[3];

    # Check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between AcronymDefinitionsPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug =
      Foswiki::Func::getPreferencesFlag("ACRONYMDEFINITIONSPLUGIN_DEBUG");

    Foswiki::Func::writeDebug("ACRONYMDEFINITIONSPLUGIN_DEBUG is enabled")
      if $debug;

    $prefs{'acronymDefinitions'} =
      Foswiki::Func::getPreferencesValue("ACRONYMDEFINITIONS")
      || Foswiki::Func::getPreferencesValue(
        "ACRONYMDEFINITIONSPLUGIN_ACRONYMDEFINITIONS")
      || '';

    $disabled = 1
      unless $prefs{'acronymDefinitions'};

    return 1;
}

#=============

sub postRenderingHandler {

    return if ($disabled);

    my $acronymDefinitions = $prefs{'acronymDefinitions'};

    # Lookbehind/lookahead WikiWord delimiters taken from Foswiki::Render
    my $STARTWW = qr/^|(?<=[\s\(])/m;
    my $ENDWW   = qr/$|(?=[^[:alpha:][:digit:]])/m;

    if ($acronymDefinitions) {

        $acronymDefinitions =~ m|^(?:(.*)\.)?(.*)$|;
        my $acronymDefinitionsWeb   = $1;
        my $acronymDefinitionsTopic = $2;

        if ( $acronymDefinitionsWeb eq '' ) { undef $acronymDefinitionsWeb; }

        # Check topic exists, exit if not.
        unless (
            Foswiki::Func::topicExists(
                $acronymDefinitionsWeb, $acronymDefinitionsTopic
            )
          )
        {
            Foswiki::Func::writeDebug(
                "Specified acronym definition topic doesn't exist, exiting")
              if $debug;
            return;
        }

        # Check current user can view the topic, exit if not.
        unless (
            Foswiki::Func::checkAccessPermission(
                'VIEW', $user, undef, $acronymDefinitionsTopic,
                $acronymDefinitionsWeb, undef
            )
          )
        {
            Foswiki::Func::writeDebug(
"Specified acronym definition topic not viewable by current user, exiting"
            ) if $debug;
            return;
        }

        undef %acronyms;
        Foswiki::Func::writeDebug("Cleared acronyms") if $debug;

        _populateAcronymsHash( $acronymDefinitionsWeb,
            $acronymDefinitionsTopic );

        # 'abbrevRegex' matches things we consider acronyms.
        $_[0] =~ s/(
            $STARTWW                            # Prefix
            (?:$Foswiki::regex{'abbrevRegex'})  # Acronym
            $ENDWW                              # Suffix
            )
           /&_wrapAcronym($1)
           /geox;
    }

    # Fix content of 'title' tag if broken by preceding.
    $_[0] =~ s| <title>(.*)
                <acronym[^>]+>
                ([^<]+)
                </acronym>
                (.*)
                </title>
              | <title>$1$2$3</title>
              |x;

}

sub _populateAcronymsHash {

    my $acronymDefinitionsWeb   = $_[0];
    my $acronymDefinitionsTopic = $_[1];
    my $meta;
    my $text;
    my $acronym;
    my $definition;

    Foswiki::Func::writeDebug("Populating acronyms hash") if $debug;

    ( $meta, $text ) = Foswiki::Func::readTopic( $acronymDefinitionsWeb,
        $acronymDefinitionsTopic, undef );

    my @entries = split /\n/, $text;

    foreach my $entry (@entries) {

        # Acronym definition lines must have format:
        #    * [Acronym] - [Definition]

        $entry =~ /^   \* (.*) - (.*)$/;
        Foswiki::Func::writeDebug("Acronym: $1; Definition: $2") if $debug;

        $acronym = $1;
        if ( $2 ne '' ) {
            $definition = $2;
        }
        else {
            $definition = 'No definition specified';
        }

        $acronyms{$acronym} = $definition;

    }

}

sub _wrapAcronym {

    if ( exists $acronyms{ $_[0] } ) {
        Foswiki::Func::writeDebug(" -- Wrapping $_[0]")
          if $debug;
        return "<acronym title='$acronyms{$_[0]}'>" . $_[0] . "</acronym>";
    }
    else {
        Foswiki::Func::writeDebug(
            " -- No definition found for acronym - returning $_[0] ")
          if $debug;
        return $_[0];
    }
}

1;

__END__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

   Copyright (C) 2012 Alexis Hazell, alexis.hazell@gmail.com

 This plugin contains code adapted from the ControlWikiWordPlugin
   Copyright (C) 2010 George Clark, geonwiki@fenachrone.com
   Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
   Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
 and the StopWikiWordLinkPlugin
    Copyright (C) 2006 Peter Thoeny, peter@thoeny.org
 and the FindElsewherePlugin
    Copyright (C) 2002 Mike Barton, Marco Carnut, Peter Hernst
    Copyright (C) 2003 Martin Cleaver, (C) 2004 Matt Wilkie (C) 2007 Crawford Currie

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
