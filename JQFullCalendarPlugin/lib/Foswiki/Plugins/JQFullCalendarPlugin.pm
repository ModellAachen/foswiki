# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009-2010 Michael Daum, http://michaeldaumconsulting.com
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
#
package Foswiki::Plugins::JQFullCalendarPlugin;
use strict;
use warnings;

our $VERSION = '$Rev$';
our $RELEASE = '0.1';
our $SHORTDESCRIPTION = '<nop>FullCalendar jQuery widget for Foswiki';
our $NO_PREFS_IN_TOPIC = 1;

use Foswiki::Plugins::JQueryPlugin ();

sub initPlugin {
  my ($topic, $web, $user) = @_;

  Foswiki::Plugins::JQueryPlugin::registerPlugin('fullcalendar', 'Foswiki::Plugins::JQFullCalendarPlugin::FULLCALENDAR');

  return 1;
}

1;
