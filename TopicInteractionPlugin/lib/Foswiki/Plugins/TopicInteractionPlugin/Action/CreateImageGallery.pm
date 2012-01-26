# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2010-2012 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::TopicInteractionPlugin::Action::CreateImageGallery;

use strict;
use warnings;
use Error qw( :try );
use Foswiki::Func ();
use Foswiki::Plugins::TopicInteractionPlugin::Core ();
use constant DRY => 0; # toggle me

sub handle {
  my ($response, $params) = @_;

  my @fileNames = split(/\s*,\s*/, $params->{filename});

  my $web = $params->{web};
  my $topic = $params->{topic};
  my $id = $params->{id};

  my ($oopsUrl, $loginName, $unlockTime) = Foswiki::Func::checkTopicEditLock($web, $topic);
  if ($unlockTime) {
    Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 105, "Topic is locked by $loginName", $id);
    return;
  }
  my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);
  my $format = '%IMAGEGALLERY{include="$pattern"}%';
  my $pattern = '^('.join('|', @fileNames).')$';
  $format =~ s/\$pattern\b/$pattern/g;
  $text .= $format."\n";

  my $error;
  try {
    Foswiki::Func::saveTopic($web, $topic, $meta, $text);
  } catch Error::Simple with {
    $error = shift->{-text};
    Foswiki::Plugins::TopicInteractionPlugin::Core::writeDebug("ERROR: $error");
  };

  if ($error) {
    Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 1, $error, $id);
  } else {
    Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 0, undef, $id)
  }
}

1;

