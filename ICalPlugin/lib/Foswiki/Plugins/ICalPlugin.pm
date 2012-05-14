# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# ICalPlugin is Copyright (C) 2011-2012 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::ICalPlugin;

use strict;
use warnings;

use Foswiki::Func ();

our $VERSION = '$Rev$';
our $RELEASE = '1.12';
our $SHORTDESCRIPTION = 'Access ical data in wikiapps';
our $NO_PREFS_IN_TOPIC = 1;
our $core;
our $baseTopic;
our $baseWeb;

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  Foswiki::Func::registerTagHandler(
    'FORMATICAL',
    sub {
      return getCore()->FORMATICAL(@_);
    }
  );

  # not sure whether the related context variable is already set during initPlugin
  # so we use Foswiki::cfg
  if ($Foswiki::cfg{Plugins}{MetaDataPlugin}{Enabled}) {
    require Foswiki::Plugins::MetaDataPlugin;

    Foswiki::Plugins::MetaDataPlugin::registerDeleteHandler(
      'EVENT',
      sub {
        my ($web, $topic, $record) = @_;

        my $core = getCore();
        my $event = $core->getEventFromMetaData($web, $topic, $record);

        return $core->updateCalendar(undef, [$event]);
      }
    );
  }

  return 1;
}

###############################################################################
sub finishPlugin {
  $core = undef;
}

###############################################################################
sub afterSaveHandler {
  return getCore()->afterSaveHandler(@_);
}

###############################################################################
sub getCore {

  unless (defined $core) {
    require Foswiki::Plugins::ICalPlugin::Core;
    $core = new Foswiki::Plugins::ICalPlugin::Core($baseWeb, $baseTopic);
  }

  return $core;
}

1;
