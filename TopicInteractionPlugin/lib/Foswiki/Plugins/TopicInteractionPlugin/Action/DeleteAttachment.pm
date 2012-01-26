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

package Foswiki::Plugins::TopicInteractionPlugin::Action::DeleteAttachment;

use strict;
use warnings;
use Error qw( :try );
use Foswiki::Plugins::DBCachePlugin ();
use Foswiki::Plugins::TopicInteractionPlugin::Core ();
use constant DRY => 0; # toggle me

sub handle {
  my ($response, $params) = @_;

  my $web = $params->{web};
  my $topic = $params->{topic};
  my $fileNames = $params->{filename};
  my $id = $params->{id};

  my @fileNames = split(/\s*,\s*/, $fileNames);

  # disable dbcache handler during loop
  Foswiki::Plugins::DBCachePlugin::disableRenameHandler();

  my $error;
  foreach my $fileName (@fileNames) {
    ($fileName) = Foswiki::Sandbox::sanitizeAttachmentName($fileName);

    # SMELL: it is okay that it is gone, that's what we want anyway
    #if (!Foswiki::Func::attachmentExists($web, $topic, $fileName)) {
    #  Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 102, "Attachment $fileName does not exist", $id);
    #  last;
    #}

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
      while (Foswiki::Func::attachmentExists($Foswiki::cfg{TrashWebName}, 'TrashAttachment', $toAttachment)) {
        $toAttachment = $base . $n . $ext;
        $n++;
      }

      Foswiki::Plugins::TopicInteractionPlugin::Core::writeDebug("moving $web.$topic.$fileName to Trash.TrashAttachment.$toAttachment");

      unless (DRY) {
        Foswiki::Func::moveAttachment(
          $web, $topic, $fileName,
          $Foswiki::cfg{TrashWebName}, 'TrashAttachment', $toAttachment
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

  if ($error) {
    Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 1, $error, $id);
  } else {
    Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 0, undef, $id);
  }
}

1;
