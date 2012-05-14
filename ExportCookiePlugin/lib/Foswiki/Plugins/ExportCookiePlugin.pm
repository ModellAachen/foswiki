#!/usr/local/bin/perl -wI.
#
# This script Copyright (c) 2008 Impressive.media
# and distributed under the GPL (see below)
#
# Based on parts of GenPDF, which has several sources and authors
# This script uses html2pdf as backend, which is distributed under the LGPL
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

package Foswiki::Plugins::ExportCookiePlugin;

use strict;

use Assert;
use HTTP::Cookies::Find;
use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev: 12445$';

$RELEASE = 'Dakar';

$SHORTDESCRIPTION =
  'Exports the value of a cookie into the Foswiki variable %EXPORTCOOKIE%';
$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'ExportCookiePlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiku::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    Foswiki::Func::registerTagHandler( 'EXPORTCOOKIE', \&_GETCOOKIEVALUE );
    return 1;
}

sub _GETCOOKIEVALUE {
    my ( $this, $params, $theTopic, $theWeb ) = @_;
    my $query      = Foswiki::Func::getCgiQuery();
    my $value      = "";
    my $CookieName = $Foswiki::cfg{Plugins}{ExportCookiePlugin}{CookieName};

    foreach my $name ( $query->cookie() ) {
        if ( $name eq $CookieName ) {
            $value = $query->cookie( '-name' => $name );
        }
    }

    return $value;
}
1;
