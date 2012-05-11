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

package Foswiki::Plugins::NatSkinPlugin::WebComponent;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Plugins::NatSkinPlugin::ThemeEngine ();

our %seenWebComponent = (); # cache for get()

###############################################################################
sub init {

  %seenWebComponent = (); 
}


###############################################################################
sub render {
  my ($session, $params) = @_;

  my $theComponent = $params->{_DEFAULT};
  my $theLinePrefix = $params->{lineprefix};
  my $theWeb = $params->{web};
  my $theMultiple = $params->{multiple};

  my $name = lc $theComponent;

  my $themeEngine = Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine();
  return '' if $themeEngine->{skinState}{$name} && $themeEngine->{skinState}{$name} eq 'off';

  my $text;
  ($text, $theWeb, $theComponent) = getWebComponent($session, $theWeb, $theComponent, $theMultiple);

  #SL: As opposed to INCLUDE WEBCOMPONENT should render as if they were in the web they provide links to.
  #    This behavior allows for web component to be consistently rendered in foreign web using the =web= parameter. 
  #    It makes sure %WEB% is expanded to the appropriate value. 
  #    Although possible, usage of %BASEWEB% in web component topics might have undesired effect when web component is rendered from a foreign web. 
  $text = Foswiki::Func::expandCommonVariables($text, $theComponent, $theWeb);

  # ignore permission warnings here ;)
  $text =~ s/No permission to read.*//g;
  $text =~ s/[\n\r]+/\n$theLinePrefix/gs if defined $theLinePrefix;

  return $text
}

###############################################################################
# search path 
# 1. search WebTheComponent in current web
# 2. search SiteTheComponent in %USERWEB% 
# 3. search SiteTheComponent in %SYSTEMWEB%
# 4. search WebTheComponent in %SYSTEMWEB% web
# (like: TheComponent = SideBar)
sub getWebComponent {
  my ($session, $web, $component, $multiple) = @_;

  $web ||= $session->{webName}; # Default to baseWeb 
  $multiple || 0;
  $component =~ s/^(Web)//; #compatibility

  ($web, $component) = Foswiki::Func::normalizeWebTopicName($web, $component);

  #writeDebug("called getWebComponent($component)");

  # SMELL: why does preview call for components twice ???
  if ($seenWebComponent{$component} && $seenWebComponent{$component} > 2 && !$multiple) {
    return '<span class="foswikiAlert">'.
      "ERROR: component '$component' already included".
      '</span>';
  }
  $seenWebComponent{$component}++;

  # get component for web
  my $text = '';
  my $meta = '';
  my $usersWeb = $Foswiki::cfg{UsersWebName};
  my $systemWeb = $Foswiki::cfg{SystemWebName};

  my $theWeb = $web;
  my $targetWeb = $web;
  my $theComponent = 'Web'.$component;

  my $userName = Foswiki::Func::getWikiName();

  if (Foswiki::Func::topicExists($theWeb, $theComponent) &&
      Foswiki::Func::checkAccessPermission('VIEW',$userName,undef,$theComponent, $theWeb)) {
    # current
    ($meta, $text) = Foswiki::Func::readTopic($theWeb, $theComponent);
  } else {
    $theWeb = $usersWeb;
    $theComponent = 'Site'.$component;


    if (Foswiki::Func::topicExists($theWeb, $theComponent) &&
        Foswiki::Func::checkAccessPermission('VIEW',$userName,undef,$theComponent, $theWeb)) {
      # %USERWEB%
      ($meta, $text) = Foswiki::Func::readTopic($theWeb, $theComponent);
    } else {
      $theWeb = $systemWeb;

      if (Foswiki::Func::topicExists($theWeb, $theComponent) &&
          Foswiki::Func::checkAccessPermission('VIEW',$userName,undef,$theComponent, $theWeb)) {
	# %SYSTEMWEB%
	($meta, $text) = Foswiki::Func::readTopic($theWeb, $theComponent);
      } else {
	$theWeb = $systemWeb;
	$theComponent = 'Web'.$component;
	if (Foswiki::Func::topicExists($theWeb, $theComponent) &&
            Foswiki::Func::checkAccessPermission('VIEW',$userName,undef,$theComponent, $theWeb)) {
	  ($meta, $text) = Foswiki::Func::readTopic($theWeb, $theComponent);
	} else {
	  return ''; # not found
	}
      }
    }
  }

  # extract INCLUDE area
  $text =~ s/.*?%STARTINCLUDE%//gs;
  $text =~ s/%STOPINCLUDE%.*//gs;

  #writeDebug("done getWebComponent($web.$component)");

  return ($text, $theWeb, $theComponent);
}


1;
