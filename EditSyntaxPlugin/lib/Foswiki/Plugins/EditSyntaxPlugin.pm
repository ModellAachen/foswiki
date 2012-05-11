# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 Peter Thoeny, peter@thoeny.org
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

package Foswiki::Plugins::EditSyntaxPlugin;

use strict;
use vars qw( $VERSION $RELEASE $debug $pluginName $installWeb );

# This should always be $Rev$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Name of this Plugin, only used in this module
$pluginName = 'EditSyntaxPlugin';

# ================================================================
sub initPlugin {
    my ( $topic, $web, $user, $installweb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Example code of how to get a preference value, register a variable handler
    # and register a RESTHandler. (remove code you do not need)

 # Get plugin preferences variables
 #my $example = Foswiki::Func::getPreferencesValue( "\U$pluginName\E_EXAMPLE" );

    # get debug flag
    $debug = Foswiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    $installWeb = $installweb;

    # Plugin correctly initialized
    return 1;
}

# ================================================================
sub DISABLE_commonTagsHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    Foswiki::Func::writeDebug(
        "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
}

# ================================================================
sub beforeEditHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;
    Foswiki::Func::writeDebug(
        "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )")
      if $debug;

    my $editSyntax = Foswiki::Func::getPreferencesValue('EDITSYNTAX') || '';
    $_[0] = _translateText( $_[0], $editSyntax, 'T2X' ) if ($editSyntax);
}

# ================================================================
sub afterEditHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;
    Foswiki::Func::writeDebug(
        "- ${pluginName}::afterEditHandler( $_[2].$_[1] )")
      if $debug;

    my $editSyntax = Foswiki::Func::getPreferencesValue('EDITSYNTAX') || '';
    $_[0] = _translateText( $_[0], $editSyntax, 'X2T' ) if ($editSyntax);
}

# ================================================================
sub _translateText {
    my ( $text, $editSyntax, $type ) = @_;

    my @rules = _readRegexRules( $editSyntax, $type );
    return $text unless scalar(@rules);
    foreach my $rule (@rules) {
        $rule =~ /^(.*)$/;
        $rule = $1;    # FIXME - this is a security hole!
        eval("\$text =~ $rule;");
    }
    $text =~ s/_TML_/_EXT_/go;
    return $text;
}

# ================================================================
sub _readRegexRules {
    my ( $editSyntax, $type ) = @_;
    my $text =
      Foswiki::Func::readTopicText( $installWeb, "${editSyntax}EditSyntaxRegex",
        '', 1 );
    my $regex = '(\/.*?\/.*?\/)( +\#| *$)';
    my @rules =
      map { s/.*?\* $type\: *$regex.*/s${1}g/; $_ }
      grep { /\* $type\: *$regex/ }
      split( /[\n\r]+/, $text );
    return @rules;
}

# ================================================================
1;
