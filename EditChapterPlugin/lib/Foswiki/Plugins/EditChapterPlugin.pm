# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2012 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::EditChapterPlugin;

use strict;

use Foswiki::Func();
use Foswiki::Plugins();
use Foswiki::Plugins::JQueryPlugin ();
use Foswiki::Contrib::JsonRpcContrib ();

our $VERSION = '$Rev$';
our $RELEASE = '4.31';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = 'An easy sectional edit facility';
our $core;

###############################################################################
sub initPlugin {
  $core = undef;

  Foswiki::Func::registerTagHandler('EXTRACTCHAPTER', sub {
    return getCore(shift)->handleEXTRACTCHAPTER(@_);
  });

  Foswiki::Contrib::JsonRpcContrib::registerMethod("EditChapterPlugin", "lock", sub {
    return getCore(shift)->jsonRpcLockTopic(@_);
  });

  Foswiki::Contrib::JsonRpcContrib::registerMethod("EditChapterPlugin", "unlock", sub {
    return getCore(shift)->jsonRpcUnlockTopic(@_);
  });

  return 1;
}

###############################################################################
sub getCore {
  my $session = shift || $Foswiki::Plugins::SESSION;

  unless ($core) {
    require Foswiki::Plugins::EditChapterPlugin::Core;
    $core = new Foswiki::Plugins::EditChapterPlugin::Core($session);
  }

  return $core;
}

###############################################################################
sub commonTagsHandler {
  ### my ( $text, $topic, $web, $meta ) = @_;

  $_[0] =~ s/%(STOP|START)CHAPTER%/<!-- $1CHAPTER -->/g; # cleanup

  my $context = Foswiki::Func::getContext();
  return unless $context->{'view'};
  return if $context->{'static'};
  return unless $context->{'authenticated'};

  my $query = Foswiki::Func::getCgiQuery();
  my $contenttype = $query->param('contenttype') || '';
  return if $contenttype eq "application/pdf"; 

  getCore()->commonTagsHandler(@_);
}

1;
