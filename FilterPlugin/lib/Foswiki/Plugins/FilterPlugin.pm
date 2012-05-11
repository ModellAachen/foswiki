# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2012 Michael Daum http://michaeldaumconsulting.com
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
###############################################################################
package Foswiki::Plugins::FilterPlugin;

use strict;
use warnings;

use Foswiki::Func();

our $VERSION = '$Rev$';
our $RELEASE = '3.01';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = 'Substitute and extract information from content by using regular expressions';
our $core;

###############################################################################
sub initPlugin {
  my ($currentTopic, $currentWeb) = @_;

  Foswiki::Func::registerTagHandler('FORMATLIST', sub {
    return getCore(shift)->handleFormatList(@_);
  });

  Foswiki::Func::registerTagHandler('MAKEINDEX', sub {
    return getCore(shift)->handleMakeIndex(@_);
  });

  Foswiki::Func::registerTagHandler('SUBST', sub {
    return getCore(shift)->handleSubst(@_);
  });

  Foswiki::Func::registerTagHandler('EXTRACT', sub {
    return getCore(shift)->handleExtract(@_);
  });

  $core = undef;
  return 1;
}

###############################################################################
sub commonTagsHandler {
# my ($text, $topic, $web, $included, $meta ) = @_;

  my $theTopic = $_[1];
  my $theWeb = $_[2];

  while($_[0] =~ s/%STARTSUBST{(?!.*%STARTSUBST)(.*?)}%(.*?)%STOPSUBST%/&handleFilterArea($1, 1, $2, $theWeb, $theTopic)/ges) {
    # nop
  }
  while($_[0] =~ s/%STARTEXTRACT{(?!.*%STARTEXTRACT)(.*?)}%(.*?)%STOPEXTRACT%/&handleFilterArea($1, 0, $2, $theWeb, $theTopic)/ges) {
    # nop
  }
}

###############################################################################
sub getCore {
  my $session = shift;

  unless (defined $core) {
    require Foswiki::Plugins::FilterPlugin::Core;
    $core = new Foswiki::Plugins::FilterPlugin::Core($session)
  }

  return $core;
}

###############################################################################
sub handleFilterArea {
  return getCore()->handleFilterArea(@_);
}

1;
