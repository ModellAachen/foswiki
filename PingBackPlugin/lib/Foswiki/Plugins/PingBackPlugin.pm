# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2012 Michael Daum http://michaeldaumconsulting.com
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

use strict;
use warnings;

package Foswiki::Plugins::PingBackPlugin;

our $VERSION = '$Rev$';
our $RELEASE = '0.06';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = 'Pingback service for Foswiki';

our $currentWeb;
our $currentTopic;
our $doneHeader;

use constant DEBUG => 0; # toggle me

use Foswiki::Func ();
use Foswiki::Contrib::XmlRpcContrib ();

###############################################################################
sub writeDebug {
  print STDERR "- PingBackPlugin - " . $_[0] . "\n" if DEBUG;
}

###############################################################################
sub initPlugin {
  ($currentTopic, $currentWeb) = @_;

  $doneHeader = 0;

  Foswiki::Func::registerTagHandler('PINGBACK', sub {
    require Foswiki::Plugins::PingBackPlugin::Core;
    return Foswiki::Plugins::PingBackPlugin::Core::handlePingbackTag(@_);
  });

  Foswiki::Contrib::XmlRpcContrib::registerMethod('pingback.ping', sub {
    require Foswiki::Plugins::PingBackPlugin::Core;
    return Foswiki::Plugins::PingBackPlugin::Core::handlePingbackCall(@_);
  });

  return 1;
}

###############################################################################
sub isPingBackEnabled {
  return  Foswiki::Func::isTrue(Foswiki::Func::getPreferencesFlag('ENABLEPINGBACK'));
}

###############################################################################
# we can't use addToZone as the pingback specification to autodetect the
# server only demands the link to be within the first 5KB. So some sources
# might not detect the xmlrpc service if we add the pingback relation th the
# _end_ of the <head>...</head> section rather than to the start
sub postRenderingHandler {

  if (isPingBackEnabled() && !$doneHeader) {
    $doneHeader = 1;
    my $xmlRpcUrl = Foswiki::Func::getScriptUrl($currentWeb, $currentTopic, 'xmlrpc');
    my $xmlRpcLink = "<link rel='pingback' href='$xmlRpcUrl' />";
    $_[0] =~ s/<title>(.*?[\r\n]+)/<title>$1$xmlRpcLink\n/;
  }

  $_[0] =~ s/%(START|STOP)PINGBACK%//go;
}

###############################################################################
sub afterSaveHandler {
  require Foswiki::Plugins::PingBackPlugin::Core;
  return Foswiki::Plugins::PingBackPlugin::Core::afterSaveHandler(@_);
}

1;
