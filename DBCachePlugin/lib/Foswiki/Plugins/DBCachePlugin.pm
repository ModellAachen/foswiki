# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2012 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::DBCachePlugin;

#use Monitor;
#Monitor::MonitorMethod('Foswiki::Contrib::DBCachePlugin');
#Monitor::MonitorMethod('Foswiki::Contrib::DBCachePlugin::Core');
#Monitor::MonitorMethod('Foswiki::Contrib::DBCachePlugin::WebDB');

use strict;
use vars qw(
  $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC
  $baseWeb $baseTopic $isInitialized
  $addDependency 
  $isEnabledSaveHandler
  $isEnabledRenameHandler
);

$VERSION = '$Rev$';
$RELEASE = '4.10';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Lightweighted frontend to the DBCacheContrib';

###############################################################################
# plugin initializer
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  # check for Plugins.pm versions
  #  if ($Foswiki::Plugins::VERSION < 1.1) {
  #    return 0;
  #  }

  Foswiki::Func::registerTagHandler('DBQUERY', sub {
    initCore();
    return Foswiki::Plugins::DBCachePlugin::Core::handleDBQUERY(@_);
  });

  Foswiki::Func::registerTagHandler('DBCALL', sub {
    initCore();
    return Foswiki::Plugins::DBCachePlugin::Core::handleDBCALL(@_);
  });

  Foswiki::Func::registerTagHandler('DBSTATS', sub {
    initCore();
    return Foswiki::Plugins::DBCachePlugin::Core::handleDBSTATS(@_);
  });

  Foswiki::Func::registerTagHandler('DBDUMP', sub {
    initCore();
    return Foswiki::Plugins::DBCachePlugin::Core::handleDBDUMP(@_);
  });

  Foswiki::Func::registerTagHandler('DBRECURSE', sub {
    initCore();
    return Foswiki::Plugins::DBCachePlugin::Core::handleDBRECURSE(@_);
  });

  Foswiki::Func::registerTagHandler('DBPREV', sub {
    initCore();
    return Foswiki::Plugins::DBCachePlugin::Core::handleNeighbours(1, @_);
  });

  Foswiki::Func::registerTagHandler('DBNEXT', sub {
    initCore();
    return Foswiki::Plugins::DBCachePlugin::Core::handleNeighbours(0, @_);
  });

  Foswiki::Func::registerTagHandler('TOPICTITLE', sub {
    initCore();
    return Foswiki::Plugins::DBCachePlugin::Core::handleTOPICTITLE(@_);
  });

  Foswiki::Func::registerTagHandler('GETTOPICTITLE', sub {
    initCore();
    return Foswiki::Plugins::DBCachePlugin::Core::handleTOPICTITLE(@_);
  });

  Foswiki::Func::registerRESTHandler('UpdateCache', \&restUpdateCache);

  Foswiki::Func::registerRESTHandler('dbdump', sub {
    initCore();
    return Foswiki::Plugins::DBCachePlugin::Core::restDBDUMP(@_);
  });

  # SMELL: remove this when Foswiki::Cache got into the core
  my $cache = $Foswiki::Plugins::SESSION->{cache}
    || $Foswiki::Plugins::SESSION->{cache};
  if (defined $cache) {
    $addDependency = \&addDependencyHandler;
  } else {
    $addDependency = \&nullHandler;
  }

  $isInitialized = 0;
  $isEnabledSaveHandler = 1;
  $isEnabledRenameHandler = 1;

  return 1;
}

###############################################################################
sub initCore {
  return if $isInitialized;
  $isInitialized = 1;

  require Foswiki::Plugins::DBCachePlugin::Core;
  Foswiki::Plugins::DBCachePlugin::Core::init($baseWeb, $baseTopic);
}

###############################################################################
# REST handler to allow offline cache updates
sub restUpdateCache {
  my $session = shift;
  my $web = $session->{webName};

  my $db = getDB($web);
  $db->load(1) if $db;
}

###############################################################################
sub disableSaveHandler {
  $isEnabledSaveHandler = 0;
}

###############################################################################
sub enableSaveHandler {
  $isEnabledSaveHandler = 1;
}

###############################################################################
sub disableRenameHandler {
  $isEnabledRenameHandler = 0;
}

###############################################################################
sub enableRenameHandler {
  $isEnabledRenameHandler = 1;
}

###############################################################################
sub loadTopic {
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::loadTopic(@_);
}

###############################################################################
# after save handlers
sub afterSaveHandler {
  #my ($text, $topic, $web, $meta) = @_;

  return unless $isEnabledSaveHandler;

  # Temporarily disable afterSaveHandler during a "createweb" action:
  # The "createweb" action calls save serveral times during its operation.
  # The below hack fixes an error where this handler is already called even though
  # the rest of the web hasn't been indexed yet. For some reasons we'll end up
  # with only the current topic being index into in the web db while the rest
  # would be missing. Indexing all of the newly created web is thus defered until
  # after "createweb" has finished.

  my $context = Foswiki::Func::getContext();
  my $request = Foswiki::Func::getCgiQuery();
  my $action = $request->param('action') || '';
  if ($context->{manage} && $action eq 'createweb') {
    #print STDERR "suppressing afterSaveHandler during createweb\n";
    return;
  }

  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::afterSaveHandler($_[2], $_[1]);
}

###############################################################################
# deprecated: use afterUploadSaveHandler instead
sub afterAttachmentSaveHandler {
  #my ($attrHashRef, $topic, $web) = @_;
  return unless $isEnabledSaveHandler;

  return if $Foswiki::Plugins::VERSION >= 2.1 || 
    $Foswiki::cfg{DBCachePlugin}{UseUploadHandler}; # set this to true if you backported the afterUploadHandler

  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::afterSaveHandler($_[2], $_[1]);
}

###############################################################################
# Foswiki::Plugins::VERSION >= 2.1
sub afterUploadHandler {
  return unless $isEnabledSaveHandler;

  my ($attrHashRef, $meta) = @_;
  my $web = $meta->web;
  my $topic = $meta->topic;
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::afterSaveHandler($web, $topic);
}

###############################################################################
# Foswiki::Plugins::VERSION >= 2.1
sub afterRenameHandler {
  return unless $isEnabledRenameHandler;

  my ($web, $topic, $attachment, $newWeb, $newTopic, $newAttachment) = @_;

  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::afterSaveHandler($web, $topic, $newWeb, $newTopic, $attachment, $newAttachment);
}

###############################################################################
sub renderWikiWordHandler {
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::renderWikiWordHandler(@_);
}

###############################################################################
# tags

###############################################################################
# perl api
sub getDB {
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::getDB(@_);
}

sub getTopicTitle {
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::getTopicTitle(@_);
}

###############################################################################
# SMELL: remove this when Foswiki::Cache got into the core
sub nullHandler { }

sub addDependencyHandler {
  my $cache = $Foswiki::Plugins::SESSION->{cache}
    || $Foswiki::Plugins::SESSION->{cache};
  return $cache->addDependency(@_) if $cache;
}

1;
