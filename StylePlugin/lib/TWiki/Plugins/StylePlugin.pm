#
# TWiki WikiClone ($wikiversion has version info)
#
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
# =========================
#
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional.
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# =========================
package TWiki::Plugins::StylePlugin;    # change the package name!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  $exampleCfgVar $skipskin
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pstylebegin = '^\.(\w+)\s*$';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between StylePlugin and Plugins.pm");
        return 0;
    }

# Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
# $exampleCfgVar = &TWiki::Func::getPreferencesValue( "STYLEPLUGIN_EXAMPLE" ) || "default";
    $skipskin = &TWiki::Func::getPreferencesValue("STYLEPLUGIN_SKIPSKIN") || "";

    # Get plugin debug flag
    $debug  = &TWiki::Func::getPreferencesFlag("STYLEPLUGIN_DEBUG");
    $styles = &TWiki::Func::getPreferencesValue("STYLEPLUGIN_SITESTYLES")
      || ".sample {text-decoration:underline}";    # drb 3/9
    $applied = 0;

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::StylePlugin::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

sub startRenderingHandler {
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &TWiki::Func::writeDebug(
        "- StylePlugin::startRenderingHandler( $_[1].$topic )")
      if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    my $cskin  = &TWiki::Func::getSkin();
    my $skipit = 0;
    foreach my $ss ( split( /\s*,\s*/, $skipskin ) ) {
        if ( $cskin eq $ss ) {
            $skipit = 1;
        }
    }
    return if ($skipit);

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/go;
    # emit the custom styles ...
    $_[0] = "<style type=\"text/css\">$styles</style>\n$_[0]" if !$applied;

    # ... but only once
    $applied = 1;
}

# ------------------------=
sub outsidePREHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#   &TWiki::Func::writeDebug( "- StylePlugin::outsidePREHandler( $web.$topic )" ) if $debug;

   # This handler is called by getRenderedVersion, in loop outside of <PRE> tag.
   # This is the place to define customized rendering rules.
   # Note: This is an expensive function to comment out.
   # Consider startRenderingHandler instead
   # blockquote begin: ---"(
    $_[0] =~ s/^---\"\(\s*$/<blockquote>/go;

    # blockquote end: ---")
    $_[0] =~ s/^---\"\)\s*$/<\/blockquote>/go;

    # pre style begin: ---{.style
    $_[0] =~ s/^---\{\.(\w+)\s*$/<pre class=$1>/go;

    # pre style end: ---}
    $_[0] =~ s/^---\}\s*$/<\/pre>/go;

    # div style begin: ---[.style
    $_[0] =~ s/^---\[\.(\w+)\s*$/<div class=$1>/go;

    # div style end: ---]
    $_[0] =~ s/^---\]\s*$/<\/div>/go;

    # paragraph style begin: .style
    $_[0] =~ s/^\.(\w+)\s*$/<p class=$1>/go;

# acronym: ((acronym)(abbreviation)(text)) e.g. ((acronym)(RSS)(Rich Site Summary))
    $_[0] =~
s/\(\(acronym\)\((\w+)\)\(([^\(\)]*)\)\)/<acronym title="$2">$1<\/acronym>/go;

    # span: ((style)(text))
    $_[0] =~ s/\(\((\w+)\)\(([^\(\)]*)\)\)/<span class=$1>$2<\/span>/go;
}

1;
