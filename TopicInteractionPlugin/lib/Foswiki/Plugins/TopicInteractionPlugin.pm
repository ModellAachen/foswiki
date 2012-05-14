# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2009-2012 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::TopicInteractionPlugin;

use strict;

our $VERSION = '$Rev: 1340 $';
our $RELEASE = '3.01';
our $SHORTDESCRIPTION = 'Improved interaction with attachments and !DataForms';
our $NO_PREFS_IN_TOPIC = 1;

use Foswiki::Func ();
use Foswiki::Plugins::JQueryPlugin ();

##############################################################################
sub initPlugin {

  Foswiki::Func::registerTagHandler('ATTACHMENTS', \&handleATTACHMENTS);

  Foswiki::Func::registerRESTHandler('changeproperties', \&restChangeProperties);
  Foswiki::Func::registerRESTHandler('delete', \&restDelete);
  Foswiki::Func::registerRESTHandler('move', \&restMove);
  Foswiki::Func::registerRESTHandler('upload', \&restUpload);
  Foswiki::Func::registerRESTHandler('createlink', \&restCreateLink);
  Foswiki::Func::registerRESTHandler('createimagegallery', \&restCreateImageGallery);
  Foswiki::Func::registerRESTHandler('download', \&restDownload);
  Foswiki::Func::registerRESTHandler('hide', \&restHide);
  Foswiki::Func::registerRESTHandler('unhide', \&restUnhide);

  Foswiki::Plugins::JQueryPlugin::registerPlugin("uploader", 'Foswiki::Plugins::TopicInteractionPlugin::Uploader');

  return 1;
}

##############################################################################
sub handleATTACHMENTS {
  require Foswiki::Plugins::TopicInteractionPlugin::Attachments;
  return Foswiki::Plugins::TopicInteractionPlugin::Attachments::handle(@_);
}

##############################################################################
sub restChangeProperties {
  require Foswiki::Plugins::TopicInteractionPlugin::Core;
  return Foswiki::Plugins::TopicInteractionPlugin::Core::restChangeProperties(@_);
}

##############################################################################
sub restDelete {
  require Foswiki::Plugins::TopicInteractionPlugin::Core;
  return Foswiki::Plugins::TopicInteractionPlugin::Core::restDelete(@_);
}

##############################################################################
sub restMove {
  require Foswiki::Plugins::TopicInteractionPlugin::Core;
  return Foswiki::Plugins::TopicInteractionPlugin::Core::restMove(@_);
}

##############################################################################
sub restUpload {
  require Foswiki::Plugins::TopicInteractionPlugin::Core;
  return Foswiki::Plugins::TopicInteractionPlugin::Core::restUpload(@_);
}

##############################################################################
sub restCreateLink {
  require Foswiki::Plugins::TopicInteractionPlugin::Core;
  return Foswiki::Plugins::TopicInteractionPlugin::Core::restCreateLink(@_);
}

##############################################################################
sub restCreateImageGallery {
  require Foswiki::Plugins::TopicInteractionPlugin::Core;
  return Foswiki::Plugins::TopicInteractionPlugin::Core::restCreateImageGallery(@_);
}

##############################################################################
sub restDownload {
  require Foswiki::Plugins::TopicInteractionPlugin::Core;
  return Foswiki::Plugins::TopicInteractionPlugin::Core::restDownload(@_);
}

##############################################################################
sub restHide {
  require Foswiki::Plugins::TopicInteractionPlugin::Core;
  return Foswiki::Plugins::TopicInteractionPlugin::Core::restHide(@_);
}

##############################################################################
sub restUnhide {
  require Foswiki::Plugins::TopicInteractionPlugin::Core;
  return Foswiki::Plugins::TopicInteractionPlugin::Core::restUnhide(@_);
}


1;
