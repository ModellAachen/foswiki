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

package Foswiki::Plugins::TopicInteractionPlugin::Action::MoveAttachment;

use strict;
use warnings;
use Error qw( :try );
use Foswiki::Plugins::DBCachePlugin ();
use Foswiki::Plugins::TopicInteractionPlugin::Core ();
use constant DRY => 0; # toggle me

sub handle {
  my ($response, $params) = @_;

  my @fileNames = split(/\s*,\s*/, $params->{filename});

  my $web = $params->{web};
  my $topic = $params->{topic};
  my $id = $params->{id};

  my $newWeb = $params->{newweb} || $web;
  my $newTopic = $params->{newtopic} || $topic;

  # check existence
  ($newWeb, $newTopic) = Foswiki::Func::normalizeWebTopicName($newWeb, $newTopic);
  unless (Foswiki::Func::topicExists($newWeb, $newTopic)) {
    Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 101, "Topic $newWeb.$newTopic does not exist", $id);
    return;
  }

  # check null move
  if ($newWeb eq $web && $newTopic eq $topic) {
    Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 108, "Won't copy attachment to itself", $id);
    return;
  }

  # check permissions
  unless (Foswiki::Func::checkAccessPermission(
    'CHANGE', Foswiki::Func::getWikiName(), undef, $newTopic, $newWeb)) {
    Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 102, "Access denied", $id);
    return;
  }

  # disable dbcache handler during loop
  Foswiki::Plugins::DBCachePlugin::disableRenameHandler();

  my $error;
  foreach my $fileName (@fileNames) {
    ($fileName) = Foswiki::Sandbox::sanitizeAttachmentName($fileName);

    unless (Foswiki::Func::attachmentExists($web, $topic, $fileName)) {
      Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 104, "Attachment $fileName does not exist", $id);
      return;
    }

    try {

      # from Foswiki::UI::Rename
      # look for a non-conflicting name in the trash web
      my $base = $fileName;
      my $ext = '';
      if ( $base =~ s/^(.*)(\..*?)$/$1_/ ) {
        $ext = $2;
      }
      my $toAttachment = $fileName;
      my $n = 1;
      while (Foswiki::Func::attachmentExists($newWeb, $newTopic, $toAttachment)) {
        $toAttachment = $base . $n . $ext;
        $n++;
      }

      Foswiki::Plugins::TopicInteractionPlugin::Core::writeDebug("moving $web.$topic.$fileName to $newWeb.$newTopic.$toAttachment");

      unless (DRY) {
        Foswiki::Func::moveAttachment(
          $web, $topic, $fileName,
          $newWeb, $newTopic, $toAttachment
        );
      }
    } catch Error::Simple with {
      $error = shift->{-text};
      Foswiki::Plugins::TopicInteractionPlugin::Core::writeDebug("ERROR: $error");
    };

    last if $error;
  }

  # enabling dbcache handlers again
  Foswiki::Plugins::DBCachePlugin::enableRenameHandler();

  # manually update this topic
  Foswiki::Plugins::DBCachePlugin::loadTopic($web, $topic);
  Foswiki::Plugins::DBCachePlugin::loadTopic($newWeb, $newTopic);

  if ($error) {
    Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 1, $error, $id)
  } else {
    Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 0, '', $id);
  }
}

1;
