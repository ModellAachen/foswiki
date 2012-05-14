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

# =========================
package Foswiki::Plugins::TopicSpecificNavigationPlugin
  ;    # change the package name and $pluginName!!!

# =========================
# Always use strict to enforce variable scoping
use strict;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use Foswiki::Plugins::DBConnectorPlugin;
use Error qw(:try);

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
$RELEASE = '0.6';

# Short description of this plugin
# One line description, is shown in the %FoswikiWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION =
'This plugins introduces a new navigation type for each topic: It should be used to place things like related links, further readups etc.';

# Name of this Plugin, only used in this module
$pluginName = 'TopicSpecificNavigationPlugin';
our $curWeb;
our $curTopic;

# =========================

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;
    my $pluginPubHome = Foswiki::Func::getPubUrlPath() . "/System/$pluginName";
    Foswiki::Func::registerRESTHandler( 'getnavigation', \&_getSubnavigation );
    Foswiki::Func::registerRESTHandler( 'setnavigation', \&_saveSubnavigation );

    my $output =
        '<style type="text/css" media="screen">@import url(\''
      . $pluginPubHome
      . '/topicspecificnav.css\');</style>';
    Foswiki::Func::addToHEAD( $pluginName . "_basecss", $output );
    $curWeb   = $web;
    $curTopic = $topic;

    # Plugin correctly initialized
    return 1;
}

sub _getSubnavigation {
    my $session = shift;
    my $web     = $session->{webName};
    my $topic   = $session->{topicName};

    my %result =
      Foswiki::Plugins::DBConnectorPlugin::getValues( $web, $topic,
        ['subnavigation'] );
    return $result{'subnavigation'};
}

sub _saveSubnavigation {
    my $session       = shift;
    my $web           = $session->{webName};
    my $topic         = $session->{topicName};
    my $query         = $session->{cgiQuery};
    my $subnavigation = $query->param("subnavigation");
    my %pairs;
    $pairs{'subnavigation'} = $subnavigation;
    my %result =
      Foswiki::Plugins::DBConnectorPlugin::updateValues( $web, $topic,
        \%pairs );
    return 1;
}

1;

# vim: ft=perl foldmethod=marker
