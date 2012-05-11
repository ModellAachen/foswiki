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

# change the package name and $pluginName!!!
package Foswiki::Plugins::GoUptoTocPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package.
use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

# This should always be $Rev: 12445$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 12445$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '0.2.2';

# Short description of this plugin
# One line description, is shown in the %FoswikiWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION =
  'Adds a arrow to each header, which lets you jump up the TOC anchor';

# Name of this Plugin, only used in this module
$pluginName = 'GoUptoTocPlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # Plugin correctly initialized
    return 1;
}

sub preRenderingHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    # if there is a TOC

    if ( $_[0] =~ /.*a name="foswikiTOC".*/ ) {
        my $name = $Foswiki::cfg{Plugins}{GoUptoTocPlugin}{LinkName};
        $_[0] =~
s/(---[+]{1,4}\s+)(.*)/---$1$2 <a href="#foswikiTOC" class="GouptoTocLink" title="Click to scroll up to the table of contents" style="font-size:12px;text-decoration:none;color:blue">$name<\/a>/mgi;
    }
}
1;
