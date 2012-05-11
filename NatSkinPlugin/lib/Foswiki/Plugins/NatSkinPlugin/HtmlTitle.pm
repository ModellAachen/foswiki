###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
# 
# Copyright (C) 2003-2012 MichaelDaum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatSkinPlugin::HtmlTitle;
use strict;
use warnings;

use Foswiki::Func ();

sub render {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $theSep = $params->{separator} || ' - ';
  my $theWikiToolName = $params->{wikitoolname} || 'on';

  if ($theWikiToolName eq 'on') {
    $theWikiToolName = Foswiki::Func::getPreferencesValue("WIKITOOLNAME") || 'Wiki';
    $theWikiToolName = $theSep.$theWikiToolName;
  } elsif ($theWikiToolName eq 'off') {
    $theWikiToolName = '';
  } else {
    $theWikiToolName = $theSep.$theWikiToolName;
  }

  my $theFormat = $params->{_DEFAULT};
  $theFormat = $params->{format} unless defined $theFormat;

  unless (defined $theFormat) {
    my $htmlTitle = Foswiki::Func::getPreferencesValue("HTMLTITLE");
    return $htmlTitle if $htmlTitle;
  }

  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $params->{topic} || $theTopic);
  my $webTitle = join($theSep, reverse split(/[\.\/]/, $web));

  my $topicTitle = $params->{title};
  $topicTitle = getTopicTitle($web, $topic) unless defined $topicTitle;

  $theFormat = '$title$sep$webtitle$wikitoolname' unless defined $theFormat;
  $theFormat =~ s/\$sep\b/$theSep/g;
  $theFormat =~ s/\$wikitoolname\b/$theWikiToolName/g;
  $theFormat =~ s/\$webtitle\b/$webTitle/g;
  $theFormat =~ s/\$web\b/$web/g;
  $theFormat =~ s/\$title\b/$topicTitle/g;

  return Foswiki::Func::decodeFormatTokens($theFormat);
}

sub getTopicTitle {
  my ($web, $topic) = @_;

  if (Foswiki::Func::getContext()->{DBCachePluginEnabled}) {
    #print STDERR "using DBCachePlugin\n";
    require Foswiki::Plugins::DBCachePlugin;
    return Foswiki::Plugins::DBCachePlugin::getTopicTitle($web, $topic);
  } 

  #print STDERR "using foswiki core means\n";

  my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);

  if ($Foswiki::cfg{SecureTopicTitles}) {
    my $wikiName = Foswiki::Func::getWikiName();
    return $topic
      unless Foswiki::Func::checkAccessPermission('VIEW', $wikiName, $text, $topic, $web, $meta);
  }

  # read the formfield value
  my $title = $meta->get('FIELD', 'TopicTitle');
  $title = $title->{value} if $title;

  # read the topic preference
  unless ($title) {
    $title = $meta->get('PREFERENCE', 'TOPICTITLE');
    $title = $title->{value} if $title;
  }

  # read the preference
  unless ($title)  {
    Foswiki::Func::pushTopicContext($web, $topic);
    $title = Foswiki::Func::getPreferencesValue('TOPICTITLE');
    Foswiki::Func::popTopicContext();
  }

  # default to topic name
  $title ||= $topic;

  $title =~ s/\s*$//;
  $title =~ s/^\s*//;

  return $title;
} 

1;

