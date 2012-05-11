# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2009 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::TagCloudPlugin;

use strict;
use vars qw(
  $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC 
  $isInitialized
);

$VERSION = '$Rev$';
$RELEASE = '2.21';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Renders a tag cloud given a list of terms';

###############################################################################
sub initPlugin {
  #my ($topic, $web, $user, $installWeb) = @_;

  # check for Plugins.pm versions
  if ($Foswiki::Plugins::VERSION < 1.1) {
    return 0;
  }

  Foswiki::Func::registerTagHandler('TAGCLOUD', \&_TAGCLOUD);
  $isInitialized = 0;

  return 1;
}

###############################################################################
sub _TAGCLOUD {
  #my($session, $params, $theTopic, $theWeb) = @_;

  unless ($isInitialized) {
    require Foswiki::Plugins::TagCloudPlugin::Core;
    $isInitialized = 1;
  }
  return Foswiki::Plugins::TagCloudPlugin::Core::handleTagCloud(@_);
}

###############################################################################

1;
