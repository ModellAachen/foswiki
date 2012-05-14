# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# MetaDataPlugin is Copyright (C) 2011-2012 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::MetaDataPlugin;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Contrib::JsonRpcContrib ();
use Foswiki::Plugins::MetaDataPlugin::Core();
use Error qw( :try );

our $VERSION = '$Rev$';
our $RELEASE = '1.40';
our $SHORTDESCRIPTION = 'Bring custom meta data to wiki apps';
our $NO_PREFS_IN_TOPIC = 1;
our $core;
our $baseWeb;
our $baseTopic;

##############################################################################
sub earlyInitPlugin {

  my $session = $Foswiki::Plugins::SESSION;
  $core = new Foswiki::Plugins::MetaDataPlugin::Core($session);

  return 0;
}


##############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  # register macro handlers
  Foswiki::Func::registerTagHandler('RENDERMETADATA', sub {
    my $session = shift;
    return $core->RENDERMETADATA(@_);
  });
  Foswiki::Func::registerTagHandler('NEWMETADATA', sub {
    my $session = shift;
    return $core->NEWMETADATA(@_);
  });

  # register meta definitions
  my $webMetaData = Foswiki::Func::getPreferencesValue("WEBMETADATA") || '';
  registerMetaData($webMetaData);

#  Foswiki::Contrib::JsonRpcContrib::registerMethod("MetaDataPlugin", "get", sub {
#     my $session = shift;
#    return $core->jsonRpcGet(@_);
#  });

#  Foswiki::Contrib::JsonRpcContrib::registerMethod("MetaDataPlugin", "save", sub {
#     my $session = shift;
#    return $core->jsonRpcSave(@_);
#  });

#  Foswiki::Contrib::JsonRpcContrib::registerMethod("MetaDataPlugin", "update", sub {
#     my $session = shift;
#    return $core->jsonRpcUpdate(@_);
#  });

  Foswiki::Contrib::JsonRpcContrib::registerMethod("MetaDataPlugin", "delete", sub {
    my $session = shift;
    return $core->jsonRpcDelete(@_);
  });

  $core->init;

  return 1;
}

##############################################################################
sub finishPlugin {
  $core = undef;
}

##############################################################################
sub registerDeleteHandler {
  return $core->registerDeleteHandler(@_);
}

##############################################################################
sub beforeSaveHandler { 
  $core->beforeSaveHandler(@_); 
}

##############################################################################
sub registerMetaData {
  my $topics = shift;

  foreach my $item (split(/\s*,\s*/, $topics)) {
    my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($baseWeb, $item);
    my $metaDef = getMetaDataDefinition($web, $topic);
    my ($key) = topicName2MetaData($topic);
    #print STDERR "meta data key = $key\n";
    Foswiki::Meta::registerMETA($key, %$metaDef); 
  }
}

##############################################################################
# convert a web.topic pointing to a DataForm definition to a pair
# (key, alias) used to register metadata types based on this DataForm
sub topicName2MetaData {
  my $topic = shift;

  # 1. strip off the the web part
  (undef, $topic) = Foswiki::Func::normalizeWebTopicName($baseWeb, $topic);

  # 2. generate alias which are all lowercase and strip off any ...Topic suffix
  # from the DataForm name
  my $alias = $topic;
  $alias =~ s/Topic$//; 
  $alias =~ s/Form$//; 
  $alias = lc($alias);

  # 3. the real metadata key used to register it is the upper case version
  # of the alias
  my $key = uc($alias);

  return ($key, $alias);
}

##############################################################################
sub getMetaDataDefinition {
  my ($web, $topic) = @_;

  return unless Foswiki::Func::topicExists($web, $topic);

  my $formDef;

  try {
    $formDef = new Foswiki::Form($Foswiki::Plugins::SESSION, $web, $topic);
  } catch Error::Simple with {

    # just in case, cus when this fails it takes down more of foswiki
    Foswiki::Func::writeWarning("MetaDataPlugin::getMetaDataDefinition() failed for $web.$topic:".shift);

  } catch Foswiki::AccessControlException with {
    # catch but simply bail out
  };

  return unless defined $formDef;

  my @other = ();
  my @require = ();

  push @require, 'name'; # is always required

  foreach my $field (@{$formDef->getFields}) {
    my $name = $field->{name};
    if ($field->isMandatory) {
      push @require, $name;
    } else {
      push @other, $name;
    }
  }

  my ($key, $alias) = topicName2MetaData($topic);
  my $metaDef = {
    alias => $alias,
    many => 1,
    form => $web.'.'.$topic,
  };

  $metaDef->{require} = [ @require ] if @require;
  $metaDef->{other} = [ @other ] if @other;

  return $metaDef;
}

1;
