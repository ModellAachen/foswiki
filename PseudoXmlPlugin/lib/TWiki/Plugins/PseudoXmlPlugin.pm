#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2003 William B. Norris IV <wbniv@saneasylumstudios.com>.  All Rights Reserved.
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
package TWiki::Plugins::PseudoXmlPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  %htmlTags
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
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between PseudoXmlPlugin and Plugins.pm");
        return 0;
    }

    # html 4.0 list from http://htmlhelp.com/reference/html40/alist.html
    %htmlTags = map { $_ => 1 } qw(
      a abbr acronym address applet area b base basefont bdo big blockquote body br button caption center cite code col colgroup dd del dfn dir div dl dt em fieldset font form frame frameset h1 h2 h3 h4 h5 h6 head hr html i iframe img input ins isindex kbd label legend li link map menu meta noframes noscript object ol optgroup option p param pre q s samp script select small span strike strong style sub sup table tbody td textarea tfoot th thead title tr tt u ul var
    );

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("PSEUDOXMLPLUGIN_DEBUG");

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::PseudoXmlPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================

sub handleTag {
    my ( $tag, $text, $id ) = @_;
    my $ret = '';

    if ( my $isHtmlTag = $htmlTags{$tag} ) {
        $ret .= qq{<$tag >$text</$tag >};
    }
    else {
        my $type = $id && 'id' || 'class';
        $ret .= qq{<span $type="$tag">$text</span>};
    }

    return $ret;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug(
        "- PseudoXmlPlugin::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

# this regex is (still) pretty terrible (it now nests, but i think this is really slow?)
    my $nLastMatches = -1;
    while ( my $nMatches =
        $_[0] =~
        s|<(#)?([A-Za-z0-9_-]+?)>(.+?)</\2>|handleTag( $2, $3, $1 )|geo )
    {
        last if $nMatches == $nLastMatches;
        $nLastMatches = $nMatches;
    }
}

# =========================

1;
