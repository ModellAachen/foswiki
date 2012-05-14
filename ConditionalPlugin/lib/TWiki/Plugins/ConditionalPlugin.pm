# r1.2
#
# ConditionalPlugin for TWiki
# Copyright (C) 2002 Jeroen van Dongen, jeroen@vthings.net
#
# TWiki WikiClone ($wikiversion has version info)
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
#
# ConditionalPlugin
# =========================
#
# Used to handle if-then and if-then-else constructs
# The recognised syntax is
# %IF{ scalar operator scalar }% text %ELSE% text %ENDIF%
#
# The '%ELSE% text' clause is optional.
#
# Change history:
# r1.0 - initial revision
# r1.1 - improved regexp to deal with multi-line spanning if/else constructs
# r1.2 - minor improvements, added lazy-loading of Safe.pm
#

# =========================
package TWiki::Plugins::ConditionalPlugin;

# =========================
use vars qw(
  $VERSION $RELEASE $debug $sandbox $pluginInitialized
);

#use Safe;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$prefixPattern      = '(^|[\s\-\*\(])';
$ops                = '(<|>|<=|>=|lt|gt|le|ge|==|\!=|<=>|eq|ne|cmp|=~|\!~)';
$condPattern_ifonly = '(%IF{(\s*\w+\s*' . $ops . '\s*\w+\s*)}%(.*?)%ENDIF%)';
$condPattern_ifelse =
  '(%IF{(\s*\w+\s*' . $ops . '\s*\w+\s*)}%(.*?)%ELSE%(.*?)%ENDIF%)';
$postfixPattern = '(?=[\s\.\,\;\:\!\?\)]*(\s|$))';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between ConditionalPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("CONDITIONALPLUGIN_DEBUG");

    # Don't initialize the sandbox yet. Loaded conditionally
    # only when required.
    $pluginInitialized = 0;

    # create a sandbox to safely eval the condition expression

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::ConditionalPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

sub _initDefaults {
    require Safe;

    # create a sandbox to safely eval the condition expression
    $sandbox = new Safe;
    $sandbox->permit_only(qw(:base_core));

    $pluginInitialized = 1;
}

sub handleConditional {
    my ( $cond, $true_text, $false_text ) = @_;
    &TWiki::Func::writeDebug(
        "- Conditional: match $cond, $true_text, $false_text")
      if $debug;
    return $sandbox->reval($cond) ? $true_text : $false_text;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug(
        "- ConditionalPlugin::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # check if there's an IF statement in this topic, otherwise we don't
    # have to load the lot.
    if ( $_[0] !~ m/%IF{.*}%/ ) {

        # nothing to do
        &TWiki::Func::writeDebug("- ConditionalPlugin: nothing to do")
          if $debug;
        return;
    }

    _initDefaults() if ( !$pluginInitialized );

    # try to match if/else first (otherwise it gets masked by the if-only
    # variant
    $_[0] =~
s/$prefixPattern$condPattern_ifelse$postfixPattern/&handleConditional($3, $5, $6)/geo;

    # try to match the if-only variant
    $_[0] =~
s/$prefixPattern$condPattern_ifonly$postfixPattern/&handleConditional($3, $5, '')/geos;

}

1;
