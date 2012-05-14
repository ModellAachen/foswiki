# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
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
# For licensing info read LICENSE file in the TWiki root.

=pod

---+ package TemplateToolkitPlugin

This plugin allows to use
[[http://www.template-toolkit.org][Template Toolkit]]
syntax in your TWiki topic.

=cut

package TWiki::Plugins::TemplateToolkitPlugin;

use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package.
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $NO_PREFS_IN_TOPIC );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION = 'Allow Template Toolkit expansion of topics';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use preferences
# stored in the plugin topic. This default is required for compatibility with
# older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, use $TWiki::cfg entries set in LocalSite.cfg, or
# if you want the users to be able to change settings, then use standard TWiki
# preferences that can be defined in your %USERSWEB%.SitePreferences and overridden
# at the web and topic level.
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
my $pluginName = 'TemplateToolkitPlugin';

# The template object.  It is made persistent to allow it to be
# created from e.g. a mod_perl startup routine, like that:
#     use Template;
#     use TWiki::Plugins::TemplateToolkitPlugin;
#     $TWiki::Plugins::TemplateToolkitPlugin::tt = Template->new(...);
# For non-persistent interpreters the tt object is instanciated in
# initPlugin
our $tt;

# Defaults can be overridden by configuration settings
#    1 TT preferences - only used once on object creation
my %tt_defaults = ( START_TAG => '(?:(?<=\[{2})|(?<=\]\[)|(?<![\[\]]))\[%', );
my %tt_params = ();

# Variables which need to be recorded between different callbacks
# *Must* be initialized per-request for mod_perl compliance
my $process_tt;
my $process_tt_default = 0;

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

The initialisation performs the following steps:
   1 saves configuration options as package vars
   1 registers the tag handler for =%<nop>TEMPLATETOOLKIT%=

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Pick our own subset of %TWiki::cfg for easier reference
    my $config = $TWiki::cfg{Plugins}{TemplateToolkitPlugin};

    # Initialize request specific data to be passed to the handlers
    $process_tt =
      defined $config->{UseTT}
      ? _isTrue( $config->{UseTT} )
      : $process_tt_default;
    $tt_defaults{INCLUDE_PATH} = "$TWiki::cfg{PubDir}/$installWeb/$pluginName";
    %tt_params = ();

    $debug = $config->{Debug} || 0;

    # register the _TT function to handle %TEMPLATETOOLKIT{...}%.
    TWiki::Func::registerTagHandler( 'TEMPLATETOOLKIT', \&_TT );

    # Plugin correctly initialized
    return 1;
}

# ----------------------------------------------------------------------
# Purpose:          Handle the %TEMPLATETOOLKIT{...} tag
# Parameters:       See below
# Returns:          Empty string
sub _TT {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    # $session  - a reference to the TWiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: The empty string - this variable is just an invisible trigger
    #         to control TT processing

    $process_tt = _isTrue( $params->{_DEFAULT} )
      if ( defined $params->{_DEFAULT} );
    if ( $params->{WRAPPER} ) {
        $tt_params{WRAPPER} = $params->{WRAPPER};
    }
    return '';
}

=pod

---++ preRenderingHandler( $text, \%map )
   * =$text= - text, with the head, verbatim and pre blocks replaced with placeholders
   * =\%map= - reference to a hash that maps the placeholders to the removed blocks.

This current handler feeds the text without verbatim blocks to TT and
returns the result (using $_[0] as in/out parameter).

Currently it is disabled because it turned out that many legacy TT
templates contain blank lines, indented lines or other things which
would be interpreted by the TML parser.

=cut

sub DISABLE_preRenderingHandler {
    my ( $text, $pMap ) = @_;

    return unless TWiki::Func::getContext()->{body_text};
    if ($process_tt) {
        return unless _create_TT();

        my $out;
        if ( $tt->process( \$_[0], {}, \$out ) ) {
            $_[0] = $out;
        }
        else {
            TWiki::Func::writeWarning(
                "TT processing error - see web server log for details");
            warn $tt->error();
        }
    }
}

=pod

---++ postRenderingHandler( $text )
   * =$text= - the text that has just been rendered. May be modified in place.

This current handler feeds the text to TT and returns the result
(using $_[0] as in/out parameter).

=cut

sub postRenderingHandler {
    my ($text) = @_;

    return unless TWiki::Func::getContext()->{body_text};
    if ($process_tt) {
        return unless _create_TT();

        my $out;
        if ( $tt->process( \$_[0], {}, \$out ) ) {
            $_[0] = $out;
        }
        else {
            TWiki::Func::writeWarning(
                "TT processing error - see web server log for details");
            warn $tt->error();
        }
    }
}

# ----------------------------------------------------------------------
# Non-serviceable parts inside
# ----------------------------------------------------------------------

# ----------------------------------------------------------------------
# Purpose:          Create the TT object if it doesn't exist
# Parameters:       None
# Returns:          $tt - TT object
# Globals:
#    Configuration: $TWiki::cfg{Plugins}{TemplateToolkitPlugin}
#    Conf defaults: %tt_defaults
#    TT object:     $tt
sub _create_TT {

    # The TT object may have been created before in a persistent interpreter,
    # so check for existence before doing it for this particular request
    if ($tt) {
        return $tt;
    }

    eval { require Template; };
    if ($@) {
        TWiki::Func::writeWarning("Failed to use the Template Toolkit module");
        return undef;
    }

    # Initialize TT options from the defaults hash
    # override with values from the configuration if present
    # override with params as obtained from the %TEMPLATETOOLKIT{....}% tag
    my $tt_config = $TWiki::cfg{Plugins}{TemplateToolkitPlugin}{TTOptions};
    my %tt_options =
        ( defined $tt_config and ref $tt_config eq 'HASH' )
      ? ( %tt_defaults, %$tt_config, %tt_params )
      : ( %tt_defaults, %tt_params );

    # Create the TT object
    $tt = Template->new( \%tt_options );
    if ( !$tt ) {
        TWiki::Func::writeWarning("Failed to create the TT object");
        return undef;
    }

    return $tt;
}

# ----------------------------------------------------------------------
# Purpose:          Detect various indicators for "true"
# Parameters:       $value - string to be identified
# Returns:          1 if $value is some sort of "true", 0 otherwise
sub _isTrue {
    my $value = shift;
    return $value =~ /^on|yes|1$/i ? 1 : 0;
}

1;
