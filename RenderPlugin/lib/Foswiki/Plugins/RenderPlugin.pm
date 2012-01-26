# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

# Copyright (C) 2008-2012 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::RenderPlugin;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Sandbox() ;
use Encode ();

our $VERSION = '$Rev$';
our $RELEASE = '3.1';
our $SHORTDESCRIPTION = 'Render <nop>WikiApplications asynchronously';
our $NO_PREFS_IN_TOPIC = 1;

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR '- RenderPlugin - '.$_[0]."\n" if DEBUG;
}


###############################################################################
sub initPlugin {
  my ($topic, $web, $user, $installWeb) = @_;

  Foswiki::Func::registerRESTHandler('tag', \&restTag);
  Foswiki::Func::registerRESTHandler('template', \&restTemplate);
  Foswiki::Func::registerRESTHandler('expand', \&restExpand);
  Foswiki::Func::registerRESTHandler('render', \&restRender);

  return 1;
}

###############################################################################
sub restRender {
  my ($session, $subject, $verb) = @_;

  my $query = Foswiki::Func::getCgiQuery();
  my $theTopic = $query->param('topic') || $session->{topicName};
  my $theWeb = $query->param('web') || $session->{webName};
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  return Foswiki::Func::renderText(restExpand($session, $subject, $verb), $web);
}

###############################################################################
sub restExpand {
  my ($session, $subject, $verb) = @_;

  # get params
  my $query = Foswiki::Func::getCgiQuery();
  my $theText = $query->param('text') || '';

  return ' ' unless $theText; # must return at least on char as we get a
                              # premature end of script otherwise

  my $theTopic = $query->param('topic') || $session->{topicName};
  my $theWeb = $query->param('web') || $session->{webName};
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  # and render it
  return Foswiki::Func::expandCommonVariables($theText, $topic, $web) || ' ';
}

###############################################################################
sub restTemplate {
  my ($session, $subject, $verb) = @_;

  my $query = Foswiki::Func::getCgiQuery();
  my $theTemplate = $query->param('name');
  return '' unless $theTemplate;

  my $theExpand = $query->param('expand');
  return '' unless $theExpand;

  my $theTopic = $query->param('topic') || $session->{topicName};
  my $theWeb = $query->param('web') || $session->{webName};
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  Foswiki::Func::loadTemplate($theTemplate);

  require Foswiki::Attrs;
  my $attrs = new Foswiki::Attrs($theExpand);

  my $tmpl = $session->templates->tmplP($attrs);

  # and render it
  my $result = Foswiki::Func::expandCommonVariables($tmpl, $topic, $web) || ' ';

  my $theRender = Foswiki::Func::isTrue($query->param('render'),  0);
  if ($theRender) {
    $result = Foswiki::Func::renderText($result, $web);
  }

  return $result;
}

###############################################################################
sub restTag {
  my ($session, $subject, $verb) = @_;

  #writeDebug("called restTag($subject, $verb)");

  # get params
  my $query = Foswiki::Func::getCgiQuery();

  my $theTag = $query->param('name') || 'INCLUDE';
  my $theDefault = $query->param('param') || '';
  my $theRender = $query->param('render') || 0;

  $theRender = ($theRender =~ /^\s*(1|on|yes|true)\s*$/) ? 1:0;

  my $theTopic = $query->param('topic') || $session->{topicName};
  my $theWeb = $query->param('web') || $session->{webName};
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  # construct parameters for tag
  my $params = $theDefault?'"'.$theDefault.'"':'';
  foreach my $key ($query->param()) {
    next if $key =~ /^(name|param|render|topic|XForms:Model)$/;
    my $value = $query->param($key);
    $params .= ' '.$key.'="'.$value.'" ';
  }

  # create TML expression
  my $tml = '%'.$theTag;
  $tml .= '{'.$params.'}' if $params;
  $tml .= '%';

  #writeDebug("tml=$tml");

  # and render it
  my $result = Foswiki::Func::expandCommonVariables($tml, $topic, $web) || ' ';
  if ($theRender) {
    $result = Foswiki::Func::renderText($result, $web);
  }

  #writeDebug("result=$result");

  return $result;
}

1;
