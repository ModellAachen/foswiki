# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2003 Walter Mundt, emage@spamcop.net
#
# Based on EmptyPlugin 1.010,
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
# This is a plugin to implement the <render> tag and the
# ~templatedef
# ...
# ~~
# Templating syntax within a topic.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
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
package TWiki::Plugins::RecursiveRenderPlugin;

use strict;
use Data::Dumper;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $TranslationToken $renderedText @renderStack
  %macros $prefix $rprefix $rLevel
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'RecursiveRenderPlugin';    # Name of this Plugin

# =========================
sub writeDebug {
    TWiki::Func::writeDebug(@_) if $debug;
}

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    #initialize a few other things
    @renderStack  = ();
    %macros       = ();
    $renderedText = [];
    $prefix       = "_render_";
    $rprefix      = $prefix . "r_";
    $rLevel       = -1;

    # Plugin correctly initialized
    writeDebug(
"- TWiki::Plugins::RecursiveRenderPlugin::initPlugin( $web.$topic ) is OK"
    );
    return 1;
}

# =========================
sub startRenderingHandler {

    # my ( $text, $web, $meta ) = @_; do not uncomment, use $_[0]
    writeDebug("- ${pluginName}::startRenderingHandler( $_[1] )");

    push @renderStack, $renderedText;
    $rLevel++;
    $renderedText = [];

    # This handler is called by getRenderedVersion just before the line loop

    # read in ~macros
    while ( $_[0] =~ s/\n~([^\n]*)\n(.*?)\n~~(?=\n)//s ) {
        my $macroName = $1;
        my $macroText = TWiki::Func::renderText( $2, $_[1], $_[2] );
        $macroText =~ s/~(?=$macroName)/~<nop>/g;    # no direct recursion
        $macros{$macroName} = $macroText;
    }

    # check for recursive loops
    my @names = keys %macros;
    my @usageMatrix;
    for ( my $i = 0 ; $i < @names ; $i++ ) {
        my $macroText = $macros{ $names[$i] };
        for ( my $j = 0 ; $j < @names ; $j++ ) {
            if ( index( $macroText, "~$names[$j]" ) != -1 ) {
                $usageMatrix[$i][$j] = 1;
            }
        }
    }
    for ( my $m = 0 ; $m < @names ; $m++ ) {
        for ( my $s = 0 ; $s < @names ; $s++ ) {
            for ( my $e = 0 ; $e < @names ; $e++ ) {
                if ( $usageMatrix[$s][$m] && $usageMatrix[$m][$e] ) {
                    if ( $s == $e ) {    #loop, break it
                        writeDebug(
"- ${pluginName}::startRenderingHandler - breaking loop at $names[$s]"
                        );
                        $macros{ $names[$s] } =~ s/~/~<nop>/g;
                        $usageMatrix[$s] = [];
                    }
                    else {
                        $usageMatrix[$s][$e] = 1;
                    }
                }
            }
        }
    }

    # read in <render> blocks
    my $renderCount = 0;
    my $tag         = "render";
    my $newText     = $_[0];
    my $idx         = rindex( $newText, "<$tag>" );
    while ( $idx != -1 ) {
        my $endText = substr( $newText, $idx );
        $endText =~ s!<$tag>(.*?)</$tag>!$prefix$renderCount!is;
        my $toRender = $1;
        $toRender =~ s/$prefix/$rprefix/;
        my $rText = TWiki::Func::renderText( $toRender, $_[1], $_[2] );
        $rText =~ s/$rprefix/$prefix/;
        $$renderedText[$renderCount] = $rText;
        $renderCount++;
        $newText = substr( $newText, 0, $idx ) . $endText;
        $idx = rindex( $newText, "<$tag>" );
    }
    $_[0] = $newText;

}

# =========================
sub endRenderingHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    writeDebug("- ${pluginName}::endRenderingHandler( $web.$topic )");

    if ( $rLevel == 0 ) {
        my $doneWithMacros = 0;
      MACROLOOP: until ($doneWithMacros) {
            $doneWithMacros = 1;
            foreach my $name ( sort { length($b) <=> length($a) } keys %macros )
            {
                if ( $_[0] =~ s/~$name/$macros{$name}/ge ) {
                    $doneWithMacros = 0;
                    next MACROLOOP;
                }
            }
        }
    }

    if (@$renderedText) {
        while ( $_[0] =~ s/$prefix([0-9]+)/$$renderedText[$1]/e ) { }
    }

    $renderedText = pop @renderStack;
    $rLevel--;
}

1;
