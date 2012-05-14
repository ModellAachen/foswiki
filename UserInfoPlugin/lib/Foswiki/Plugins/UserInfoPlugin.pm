# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2006 Michael Daum <micha@nats.informatik.uni-hamburg.de>
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

package Foswiki::Plugins::UserInfoPlugin;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins ();

our $uipCore;
our $VERSION = '$Rev$';
our $RELEASE = '2.00';
our $SHORTDESCRIPTION = 'Render information about the users on your wiki';
our $NO_PREFS_IN_TOPIC = 1;

###############################################################################
sub initPlugin {
  #($topic, $web, $user, $installWeb) = @_;

  $uipCore = undef;

  Foswiki::Func::registerTagHandler('NRVISITORS', sub { return getCore()->handleNrVisitors(@_);});
  Foswiki::Func::registerTagHandler('NRUSERS', sub { return getCore()->handleNrUsers(@_);});
  Foswiki::Func::registerTagHandler('NRGUESTS', sub { return getCore()->handleNrGuests(@_);});
  Foswiki::Func::registerTagHandler('NRLASTVISITORS', sub { return getCore()->handleNrLastVisitors(@_);});
  Foswiki::Func::registerTagHandler('VISITORS', sub { return getCore()->handleVisitors(@_);});
  Foswiki::Func::registerTagHandler('LASTVISITORS', sub { return getCore()->handleLastVisitors(@_);});
  Foswiki::Func::registerTagHandler('NEWUSERS', sub { return getCore()->handleNewUsers(@_);});

  return 1;
}

###############################################################################
sub getCore {
  return $uipCore if $uipCore;

  require Foswiki::Plugins::UserInfoPlugin::Core;
  $uipCore = new Foswiki::Plugins::UserInfoPlugin::Core();

  return $uipCore;
}

1;

