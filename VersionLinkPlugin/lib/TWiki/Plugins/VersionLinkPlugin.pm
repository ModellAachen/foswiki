#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2001 Ed Lott, Ed_Lott@jellyvision.com
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
# This TWiki plugin let's you script an attachment to a version
# of a file (vs. the latest version, which is what you get with
# ATTACHURL).
#
# initPlugin is required, all other are optional.

# =========================
package TWiki::Plugins::VersionLinkPlugin;

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
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between VersionLinkPlugin and Plugins.pm");
        return 0;
    }

 # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $exampleCfgVar = &TWiki::Func::getPreferencesValue("EMPTYPLUGIN_EXAMPLE")
      || "default";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("VERSIONLINKPLUGIN_DEBUG");

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::VersionLinkPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug(
        "- VersionLinkPlugin::commonTagsHandler( $_[2].$_[1] )")
      if $debug;
    $_[0] =~ s/%VERSIONLINK{(.*?)}%/&handleVersionLink($1)/geo;
    $_[0] =~ s/%VERSIONLINK%/&handleVersionLink("")/geo;
}

# =========================
sub handleVersionLink {
    my $exp = @_;
    my ( $filename, $rev ) = split( /,/, $_[0] );

    if ( !$filename ) {

        # help
        return
"$installWeb.VersionLinkPlugin help: Write a file/version expression, i.e. %<nop>VERSIONLINK{\"foo.c,1.1\"}%";
    }
    if ( !$rev ) {

        # help
        return
"$installWeb.VersionLinkPlugin help: Write a file/version expression, i.e. %<nop>VERSIONLINK{\"foo.c,1.1\"}%";
    }

    my $text =
"<a href=\"%SCRIPTURLPATH%/viewfile%SCRIPTSUFFIX%/%WEB%/%TOPIC%?rev=$rev&filename=$filename\">$filename</a>";
    &TWiki::Func::writeDebug(
        "- VersionLinkPlugin::handleVersionLink: <<$text>>")
      if $debug;

    return "$text";
}

# =========================

1;
