# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2012 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::BreadCrumbsPlugin::Core;

use strict;
use vars qw($homeTopic $lowerAlphaRegex $upperAlphaRegex $numericRegex);
use Foswiki::Plugins ();

use constant DEBUG => 0;    # toggle me

###############################################################################
sub writeDebug {
  return unless DEBUG;

  #&Foswiki::Func::writeDebug('- BreadCrumbPlugin - '.$_[0]);
  print STDERR '- BreadCrumbPlugin - ' . $_[0] . "\n";
}

###############################################################################
sub init {

  $homeTopic =
       Foswiki::Func::getPreferencesValue('HOMETOPIC')
    || $Foswiki::cfg{HomeTopicName}
    || 'WebHome';

  if ($Foswiki::Plugins::VERSION < 1.1) {
    $lowerAlphaRegex = Foswiki::Func::getRegularExpression('lowerAlpha');
    $upperAlphaRegex = Foswiki::Func::getRegularExpression('upperAlpha');
    $numericRegex = Foswiki::Func::getRegularExpression('numeric');
  }
}

###############################################################################
sub recordTrail {
  my ($web, $topic) = @_;

  writeDebug("called recordTrail($web, $topic)");

  ($web, $topic) = Foswiki::Func::normalizeWebTopicName($web, $topic);
  my $here = "$web.$topic";
  my $trail = Foswiki::Func::getSessionValue('BREADCRUMB_TRAIL') || '';
  my @trail = split(',', $trail);

  # Detect cycles by scanning back along the trail to see if we've been here
  # before
  for (my $i = scalar(@trail) - 1; $i >= 0; $i--) {
    my $place = $trail[$i];
    if ($place eq $here) {
      splice(@trail, $i);
      last;
    }
  }
  push(@trail, $here);

  Foswiki::Func::setSessionValue('BREADCRUMB_TRAIL', join(',', @trail));
}

###############################################################################
sub renderBreadCrumbs {
  my ($session, $params, $currentTopic, $currentWeb) = @_;

  writeDebug("called renderBreadCrumbs($currentWeb, $currentTopic)");

  # return an empty string if the current location is unknown
  return '' if $currentWeb eq 'Unknown' && $currentTopic eq 'Unknown';

  # get parameters
  my $webTopic = $params->{_DEFAULT} || "$currentWeb.$currentTopic";
  my $header = $params->{header} || '';
  my $format = $params->{format};
  my $topicformat = $params->{topicformat};
  my $footer = $params->{footer} || '';
  my $separator = $params->{separator};
  my $recurse = $params->{recurse} || 'on';
  my $include = $params->{include} || '';
  my $exclude = $params->{exclude} || '';
  my $type = $params->{type} || 'location';
  my $maxlength = $params->{maxlength} || 0;
  my $ellipsis = $params->{ellipsis};
  my $spaceout = $params->{spaceout} || 'off';
  my $spaceoutsep = $params->{spaceoutsep};
  my $translate = Foswiki::Func::isTrue($params->{translate});

  $separator = ' ' unless defined $separator;
  $separator = '' if $separator eq 'none';
  $format = '[[$webtopic][$name]]' unless defined $format;
  $topicformat = $format unless defined $topicformat;
  $ellipsis = ' ... ' unless defined $ellipsis;
  $spaceout = ($spaceout eq 'on') ? 1 : 0;
  $spaceoutsep = '-' unless defined $spaceoutsep;

  my %recurseFlags = map { $_ => 1 } split(/,\s*/, $recurse);

  #foreach my $key (keys %recurseFlags) {
  #  writeDebug("recurse($key)=$recurseFlags{$key}");
  #}

  # compute breadcrumbs
  my ($web, $topic) = normalizeWebTopicName($currentWeb, $webTopic);
  my $breadCrumbs;
  if ($type eq 'path') {
    $breadCrumbs = getPathBreadCrumbs();
  } else {
    $breadCrumbs = getLocationBreadCrumbs($web, $topic, \%recurseFlags);
  }

  my $doneSplice = 0;
  if ($maxlength) {
    my $length = @$breadCrumbs;
    if ($length > $maxlength) {
      splice(@$breadCrumbs, 0, $length - $maxlength);
      $doneSplice = 1;
    }
  }

  # format result
  my @lines = ();

  my $i18n;
  $i18n = $session->i18n() if $translate;

  foreach my $item (@$breadCrumbs) {
    next unless $item;
    my $line;
    if ($item->{istopic}) {
      next if $exclude ne '' && $item->{topic} =~ /^($exclude)$/;
      next if $include ne '' && $item->{topic} !~ /^($include)$/;
      $line = $topicformat;
    } else {
      next if $exclude ne '' && $item->{web} =~ /^($exclude)$/;
      next if $include ne '' && $item->{web} !~ /^($include)$/;
      $line = $format;
    }
    my $webtopic = $item->{target};
    $webtopic =~ s/\//./go;
    my $name = $item->{name};
    $name = spaceOutWikiWord($item->{name}, $spaceoutsep) if $spaceout;
    $name = $i18n->maketext($name) if $translate;
    $line =~ s/\$name/$name/g;
    $line =~ s/\$target/$item->{target}/g;
    $line =~ s/\$webtopic/$webtopic/g;
    $line =~ s/\$topic/$item->{topic}/g;
    $line =~ s/\$web/$item->{web}/g;

    #writeDebug("... added");
    push @lines, $line;
  }
  my $result = $header . ($doneSplice ? $ellipsis : '') . join($separator, @lines) . $footer;

  # expand common variables
  escapeParameter($result);

  return $result;
}

###############################################################################
sub getPathBreadCrumbs {

  my $trail = Foswiki::Func::getSessionValue('BREADCRUMB_TRAIL') || '';
  my @trail = map {
    /^(.*)\.(.*?)$/;
    my $web = $1;
    my $topic = $2;
    my $name = getTopicTitle($web, $topic);
    $name = $web if $name eq $topic && $topic eq $homeTopic;
    {
      target => $_,
      name => $name,
      web => $web,
      topic => $topic,
      istopic => 1
    }
  } split(',', $trail);

  return \@trail;
}

###############################################################################
sub getLocationBreadCrumbs {
  my ($thisWeb, $thisTopic, $recurse) = @_;

  my @breadCrumbs = ();

  # collect all parent webs as breadcrumbs
  if ($recurse->{off} || $recurse->{weboff}) {
    my $webName = $thisWeb;
    if ($webName =~ /^(.*)[\.\/](.*?)$/) {
      $webName = $2;
    }

    #writeDebug("adding breadcrumb: target=$thisWeb/$homeTopic, name=$webName");
    push @breadCrumbs,
      {
      target => "$thisWeb/$homeTopic",
      name => $webName,
      web => $thisWeb,
      topic => $homeTopic,
      istopic => 0
      };
  } else {
    my $parentWeb = '';
    my @webCrumbs;
    foreach my $parentName (split(/\//, $thisWeb)) {
      $parentWeb .= '/' if $parentWeb;
      $parentWeb .= $parentName;
      my $name = getTopicTitle($parentWeb, $homeTopic);
      $name = $parentName if $name eq $homeTopic;

      #writeDebug("adding breadcrumb: target=$parentWeb/$homeTopic, name=$name");
      push @webCrumbs,
        {
        target => "$parentWeb/$homeTopic",
        name => $name,
        web => $parentWeb,
        topic => $homeTopic,
        istopic => 0
        };
    }
    if ($recurse->{once} || $recurse->{webonce}) {
      my @list;
      push @list, pop @webCrumbs;
      push @list, pop @webCrumbs;
      push @breadCrumbs, reverse @list;
    } else {
      push @breadCrumbs, @webCrumbs;
    }
  }

  # collect all parent topics
  my %seen;
  unless ($recurse->{off} || $recurse->{topicoff}) {
    my $web = $thisWeb;
    my $topic = $thisTopic;
    my @topicCrumbs;

    while (1) {

      # get parent
      my ($meta, $dumy) = &Foswiki::Func::readTopic($web, $topic);
      my $parentMeta = $meta->get('TOPICPARENT');
      last unless $parentMeta;
      my $parentName = $parentMeta->{name};
      last unless $parentName;
      ($web, $topic) = normalizeWebTopicName($web, $parentName);

      # check end of loop
      last
        if $topic eq $homeTopic
          || $seen{"$web.$topic"}
          || !Foswiki::Func::topicExists($web, $topic);

      # add breadcrumb
      #writeDebug("adding breadcrumb: target=$web/$topic, name=$topic");
      unshift @topicCrumbs,
        {
        target => "$web/$topic",
        name => getTopicTitle($web, $topic),
        web => $web,
        topic => $topic,
        istopic => 1
        };
      $seen{"$web.$topic"} = 1;

      # check for bailout
      last
        if $recurse->{once}
          || $recurse->{topiconce};
    }
    push @breadCrumbs, @topicCrumbs;
  }

  # add this topic if it was not covered yet
  unless ($seen{"$thisWeb.$thisTopic"} || $recurse->{topicoff} || $thisTopic eq $homeTopic) {

    #writeDebug("finally adding breadcrumb: target=$thisWeb/$thisTopic, name=$thisTopic");
    push @breadCrumbs,
      {
      target => "$thisWeb/$thisTopic",
      name => getTopicTitle($thisWeb, $thisTopic),
      web => $thisWeb,
      topic => $thisTopic,
      istopic => 1
      };
  }

  return \@breadCrumbs;
}

###############################################################################
sub escapeParameter {
  return '' unless $_[0];

  $_[0] =~ s/\$nop//g;
  $_[0] =~ s/\$n/\n/g;
  $_[0] =~ s/\$percnt/%/g;
  $_[0] =~ s/\$dollar/\$/g;
}

###############################################################################
# local version to run on legacy wiki releases
sub normalizeWebTopicName {
  my ($web, $topic) = @_;

  if ($topic =~ /^(.*)[\.\/](.*?)$/) {
    $web = $1;
    $topic = $2;
  }

  return ($web, $topic);
}

###############################################################################
sub getTopicTitle {
  my ($theWeb, $theTopic) = @_;

  # use DBCachePlugin if installed
  if (Foswiki::Func::getContext()->{'DBCachePluginEnabled'}) {
    require Foswiki::Plugins::DBCachePlugin;
    return Foswiki::Plugins::DBCachePlugin::getTopicTitle($theWeb, $theTopic);
  }

  # use core means otherwise
  my $topicTitle;

  my ($meta, $text) = Foswiki::Func::readTopic($theWeb, $theTopic);

  if ($Foswiki::cfg{SecureTopicTitles}) {
    my $wikiName = Foswiki::Func::getWikiName();
    return $theTopic
      unless Foswiki::Func::checkAccessPermission('VIEW', $wikiName, $text, $theTopic, $theWeb, $meta);
  }

  my $field = $meta->get('FIELD', 'TopicTitle');
  if ($field) {
    $topicTitle = $field->{value};
    return $topicTitle if $topicTitle;
  }

  $field = $meta->get('PREFERENCE', 'TOPICTITLE');
  if ($field) {
    $topicTitle = $field->{value};
    return $topicTitle if $topicTitle;
  }

  return $theTopic;
}

###############################################################################
sub spaceOutWikiWord {
  my ($wikiWord, $separator) = @_;

  return Foswiki::Func::spaceOutWikiWord($wikiWord, $separator)
    if $Foswiki::Plugins::VERSION >= 1.13;

  $wikiWord =~ s/([$lowerAlphaRegex])([$upperAlphaRegex$numericRegex]+)/$1$separator$2/go;
  $wikiWord =~ s/([$numericRegex])([$upperAlphaRegex])/$1$separator$2/go;

  return $wikiWord;
}

1;
