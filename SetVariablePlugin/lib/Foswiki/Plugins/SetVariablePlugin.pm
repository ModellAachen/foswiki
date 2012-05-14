# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2012 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::SetVariablePlugin;

use strict;
use vars qw( 
  $VERSION $RELEASE $SHORTDESCRIPTION 
  $NO_PREFS_IN_TOPIC
  $core
);

$VERSION = '$Rev: 4287 (2009-06-23) $';
$RELEASE = '2.20';

$SHORTDESCRIPTION = 'Flexible handling of topic variables';
$NO_PREFS_IN_TOPIC = 1;

###############################################################################
sub initPlugin {
  my ($topic, $web, $user, $installWeb) = @_;

  Foswiki::Func::registerTagHandler('SETVAR', sub {
    getCore()->handleSetVar(@_) if Foswiki::Func::getContext()->{save};
    return '<!-- -->' ;
  });

  Foswiki::Func::registerTagHandler('GETVAR', sub { 
    return getCore()->handleGetVar(@_); 
  });

  Foswiki::Func::registerTagHandler('DELVAR', sub { 
    getCore()->handleUnsetVar(@_) if Foswiki::Func::getContext()->{save};
    return '<!-- -->' ;
  });

  Foswiki::Func::registerTagHandler('UNSETVAR', sub { 
    getCore()->handleUnsetVar(@_) if Foswiki::Func::getContext()->{save};
    return '<!-- -->' ;
  });

  $core = undef;

  return 1;
}

###############################################################################
sub getCore {
  return $core if $core;

  require Foswiki::Plugins::SetVariablePlugin::Core;
  $core = new Foswiki::Plugins::SetVariablePlugin::Core;

  return $core;
}

###############################################################################
sub beforeSaveHandler { return getCore()->handleBeforeSave(@_); }


1;
