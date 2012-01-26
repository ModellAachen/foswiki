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

package Foswiki::Plugins::TopicInteractionPlugin::Action::UnhideAttachment;

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

  # disable dbcache handler during loop
  Foswiki::Plugins::DBCachePlugin::disableRenameHandler();

  my $error;
  foreach my $fileName (@fileNames) {
    ($fileName) = Foswiki::Sandbox::sanitizeAttachmentName($fileName);

    unless (Foswiki::Func::attachmentExists($web, $topic, $fileName)) {
      Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 102, "Attachment $fileName does not exist", $id);
      last;
    }

    Foswiki::Plugins::TopicInteractionPlugin::Core::writeDebug("unhiding fileName=$fileName, web=$web, topic=$topic");

    try {
      unless (DRY) {
        $error = Foswiki::Func::saveAttachment(
          $web, $topic, $fileName, {
            dontlog     => !$Foswiki::cfg{Log}{upload},
            hide        => 0,
          });

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

  if ($error) {
    Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 1, $error, $id);
  } else {
    Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 0, undef, $id)
  }
}

1;

