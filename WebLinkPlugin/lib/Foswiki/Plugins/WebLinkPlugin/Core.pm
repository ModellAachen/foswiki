# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# WebLinkPlugin is Copyright (C) 2010-2012 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::WebLinkPlugin::Core;

use strict;
use warnings;

=begin TML

---+ package WebLinkPlugin::Core

=cut

use Foswiki::Func ();

our $baseWeb;
our $baseTopic;

use constant DEBUG => 0; # toggle me

=begin TML

---++ writeDebug($message(

prints a debug message to STDERR when this module is in DEBUG mode

=cut

sub writeDebug {
  print STDERR "WebLinkPlugin::Core - $_[0]\n" if DEBUG;
}

=begin TML

---++ init($baseWeb, $baseTopic)

initializer for the plugin core; called before any macro hanlder is executed

=cut

sub init {
  ($baseWeb, $baseTopic) = @_;
}

=begin TML

---++ WEBLINK($session, $params, $theTopic, $theWeb) -> $result

implementation of this macro

=cut

sub WEBLINK {
  my ($session, $params, $topic, $web) = @_;

  writeDebug("called WEBLINK()");

  # get params
  my $theWeb = $params->{_DEFAULT} || $params->{web} || $web;
  my $theName = $params->{name};
  my $theMarker = $params->{marker} || 'current';
  my $theClass = $params->{class} || 'webLink';

  my $defaultFormat =
    '<a class="'.$theClass.' $marker" href="$url" title="%ENCODE{"$tooltip" type="html"}%">$title</a>';

  my $theFormat = $params->{format} || $defaultFormat;

  #writeDebug("theFormat=$theFormat, theWeb=$theWeb");

  my $theSummary = $params->{summary} || 
    Foswiki::Func::getPreferencesValue('WEBSUMMARY', $theWeb) || 
    Foswiki::Func::getPreferencesValue('SITEMAPUSETO', $theWeb) || '';
  my $theTooltip = $params->{tooltip} || $theSummary;

  my $homeTopic = Foswiki::Func::getPreferencesValue('HOMETOPIC') 
    || $Foswiki::cfg{HomeTopicName} 
    || 'WebHome';

  my $theUrl = $params->{url} ||
    $session->getScriptUrl(0, 'view', $theWeb, $homeTopic);

  # unset the marker if this is not the current web 
  $theMarker = '' unless $theWeb eq $baseWeb;

  # normalize web name
  $theWeb =~ s/\//\./go;

  # get a good default name
  unless ($theName) {
    $theName = $theWeb;
    $theName = $2 if $theName =~ /^(.*)[\.](.*?)$/;
  }

  my $title = '';
  if ($theFormat =~ /\$title/) {
    $title = getTopicTitle($theWeb, $homeTopic);
    $title = $theName if $title eq $homeTopic;
  }

  my $result = $theFormat;
  $result =~ s/\$default/$defaultFormat/g;
  $result =~ s/\$marker/$theMarker/g;
  $result =~ s/\$url/$theUrl/g;
  $result =~ s/\$tooltip/$theTooltip/g;
  $result =~ s/\$summary/$theSummary/g;
  $result =~ s/\$name/$theName/g;
  $result =~ s/\$title/$title/g;
  $result =~ s/\$web/$theWeb/g;
  $result =~ s/\$topic/$homeTopic/g;

  #writeDebug("result=$result");
  return Foswiki::Func::decodeFormatTokens($result);
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
