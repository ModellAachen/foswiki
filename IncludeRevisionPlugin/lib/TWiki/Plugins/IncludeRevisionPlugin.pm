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
package TWiki::Plugins::IncludeRevisionPlugin;    # change the package name!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# =========================
sub initPlugin {
    return 1;
}

# =========================
sub commonTagsHandler {
    $_[0] =~ s/%INCLUDEREV{(.*?)}%/&handleIncludeRev($1)/geo;
}

# =========================
sub handleIncludeRev {
    my $rawentry = shift || return "";
    $rawentry =~ s/\"//g;
    $rawentry =~ /\s*(.*?)\s*,\s*(.*)\s*/;
    my $page = $1 || return "";
    my $rev  = $2 || return "";
    my $text;

    # convert all .'s into /'s
    $page =~ s/\./\//g;

    # match the webname and topicnames
    $page =~ /(.*)\/(.*)/;
    my $webName = $1;
    my $topic   = $2;

    $text .= &TWiki::Func::readTopicText( $webName, $topic, $rev );
    $text =~
s/%META.*{.*version=\"(.*?)\"}?%/<a href="\%SCRIPTURLPATH\%\/view\%SCRIPTSUFFIX\%\/$webName\/$topic?rev=$1"><nop>$topic<\/a> *Revision: $1*/g;
    return $text;
}

# =========================

1;
