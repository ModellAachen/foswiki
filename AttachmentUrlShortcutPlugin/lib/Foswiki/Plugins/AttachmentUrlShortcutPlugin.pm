# This script Copyright (c) 2008 Impressive.media
# and distributed under the GPL (see below)
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

package Foswiki::Plugins::AttachmentUrlShortcutPlugin;

use strict;
use Assert;
use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev: 12445$';
$RELEASE = 'Dakar';
$SHORTDESCRIPTION =
  'Lets you use shortened syntax for links for attachments with %A%';

$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'AttachmentUrlShortcutPlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }
    my $marcoName =
      $Foswiki::cfg{Plugins}{AttachmentUrlShortcutPlugin}{MacroName};
    Foswiki::Func::registerTagHandler( $marcoName, \&_AURLSHORT );

    return 1;
}

sub _AURLSHORT {
    my ( $this, $params, $topic, $web ) = @_;
    $web   = $params->{'Bereich'}  || $params->{'web'}   || $web;
    $topic = $params->{'Dokument'} || $params->{'topic'} || $topic;
    my $file =
         $params->{'Anhang'}
      || $params->{'name'}
      || $params->{_DEFAULT}
      || "";
    my $name = $params->{'Name'} || $params->{'label'} || $file;
    my $url;
    if ( $file eq "" ) {
        return Foswiki::Func::getScriptUrl( $web, $topic, 'viewfile',
            'filename' => '' );
    }

    #else
    $url = Foswiki::Func::getScriptUrl( $web, $topic, 'viewfile',
        'filename' => $file );
    return "[[$url][$name]]";
}

1;
