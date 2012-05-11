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
# SingletonWikiWordPlugin implements features as described on
# http://twiki.org/cgi-bin/view/Codev/?topic=SingletonWikiWord

# =========================
package TWiki::Plugins::SingletonWikiWordPlugin;    # change the package name!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  $exampleCfgVar
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
            "Version mismatch between SingletonWikiWordPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("SINGLETONWIKIWORDPLUGIN_DEBUG");

    # Plugin correctly initialized
    writeDebug(
"- TWiki::Plugins::SingletonWikiWordPlugin::initPlugin( $web.$topic ) is OK"
    );
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    writeDebug(
        "- X - SingletonWikiWordPlugin::commonTagsHandler( $_[0]$_[2].$_[1] )");

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%
    $_[0] =~
s/(\s+)\.([A-Z]+[a-z]*)/"$1".&TWiki::Func::internalLink("[[$2]]",$web,$web,"",1)/geo;

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/geo;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/geo;
}

sub writeDebug {
    &TWiki::Func::writeDebug(@_) if $debug;
}

1;
