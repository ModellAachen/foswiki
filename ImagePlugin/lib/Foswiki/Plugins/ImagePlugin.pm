# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 Craig Meyer, meyercr@gmail.com
# Copyright (C) 2006-2012 Michael Daum http://michaeldaumconsulting.com
#
# Based on ImgPlugin
# Copyright (C) 2006 Meredith Lesly, msnomer@spamcop.net
#
# and Foswiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
#
# For licensing info read LICENSE file in the Foswiki root.

package Foswiki::Plugins::ImagePlugin;

use strict;
use vars qw( 
  $VERSION $RELEASE $imageCore $baseWeb $baseTopic
  $origRenderExternalLink $doneRegisterJQueryPlugin
  $NO_PREFS_IN_TOPIC
);

$VERSION = '$Rev$';
$RELEASE = '2.41';
$NO_PREFS_IN_TOPIC = 1;

use Foswiki::Plugins ();
use Foswiki::Render ();

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  # check for Plugins.pm versions
  if( $Foswiki::Plugins::VERSION < 1.026 ) {
    Foswiki::Func::writeWarning( "Version mismatch between ImagePlugin and Plugins.pm" );
    return 0;
  }

  Foswiki::Func::addToZone("head", "IMAGEPLUGIN::META", <<"HERE");
<meta name='foswiki.ImagePluginEnabled' content='true' />
HERE

  # init plugin variables
  $imageCore = undef;
  $doneRegisterJQueryPlugin = 0;

  # register the tag handlers
  Foswiki::Func::registerTagHandler( 'IMAGE', sub {
    getCore($baseWeb, $baseTopic, shift)->handleIMAGE(@_); 
  });

  # register rest handler
  Foswiki::Func::registerRESTHandler('resize', sub {
    getCore($baseWeb, $baseTopic, shift)->handleREST(@_); 
  });


  # SMELL: monkey-patching Foswiki::Render::_externalLink()
  if ($Foswiki::cfg{ImagePlugin}{RenderExternalImageLinks}) {
    unless ($origRenderExternalLink) {
      no warnings 'redefine';
      $origRenderExternalLink = \&Foswiki::Render::_externalLink;
      *Foswiki::Render::_externalLink = \&renderExternalLink;
    }
  }

  # register jquery.imagetooltip plugin if jquery is isntalled
  if ($Foswiki::cfg{Plugins}{JQueryPlugin}{Enabled}) {
    require Foswiki::Plugins::JQueryPlugin;
    Foswiki::Plugins::JQueryPlugin::registerPlugin("ImageTooltip",
      'Foswiki::Plugins::ImagePlugin::IMAGETOOLTIP');
  }

  # Plugin correctly initialized
  return 1;
} 

###############################################################################
# lazy initializer
sub getCore {
  return $imageCore if $imageCore;

  Foswiki::Func::addToZone("head", "IMAGEPLUGIN", <<'HERE');
<link rel="stylesheet" href="%PUBURL%/%SYSTEMWEB%/ImagePlugin/style.css" type="text/css" media="all" />
HERE

  require Foswiki::Plugins::ImagePlugin::Core;
  $imageCore = new Foswiki::Plugins::ImagePlugin::Core(@_);
  return $imageCore;
}

###############################################################################
sub renderExternalLink {
  my ($this, $url, $text) = @_;

  my $href = '';
  my $title = $url;
  $text ||= '';

  #print STDERR "called renderExternalLink($url, $text)\n";

  # also render an image tag for links that have an external image link as a text
  if ($text =~ /^(https?:).*\.(gif|jpg|jpeg|png)$/i) {
    $href = $url;
    $title = $url;
    $url = $text;
    $text = '';
  }

  if ($url =~ /^(https?:).*\.(gif|jpg|jpeg|png)/i && !$text) {
    my $pubUrl = $this->{session}->getPubUrl(1);
    # skip "external links" to self and to any other excluded url
    my $excludePattern = $Foswiki::cfg{ImagePlugin}{Exclude};
    if ($url !~ /^$pubUrl/ && 
        (!$excludePattern || $url !~ /^$excludePattern()/)) { 

      # untaint url, check above
      $url = Foswiki::Sandbox::untaintUnchecked($url);
      $url =~ s/\?.*$//;

      my $params = {
	_DEFAULT => "$url",
	href => $href,
	title => $title,
	type => 'simple',
      };

      return getCore($baseWeb, $baseTopic)->handleIMAGE($params, $baseTopic, $baseWeb);
    } else {
      #print STDERR "normal handling of $url\n";
    }
  }

  # normal
  return &{$origRenderExternalLink}($this, $url, $text);
}

1;

