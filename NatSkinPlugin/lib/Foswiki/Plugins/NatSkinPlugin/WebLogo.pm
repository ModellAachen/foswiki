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

package Foswiki::Plugins::NatSkinPlugin::WebLogo;
use strict;
use warnings;
use Foswiki::Func ();
use Foswiki::Plugins::NatSkinPlugin::ThemeEngine ();

###############################################################################
# returns the weblogo for the header bar.
# this will check for a couple of preferences:
#    * return %NATWEBLOGONAME% if defined
#    * return %NATWEBLOGOIMG% if defined
#    * return %WIKILOGOIMG% if defined
#    * return %WEBLOGOIMG% if defined
#    * return %WIKITOOLNAME% if defined
#    * or return 'Foswiki'
#
# the ...IMG% settings are urls to images where the following variables 
# are substituted:
#    * $style: the lower case id of the current style 
#    * $variation: the lower case id of the current variation
#
# this allows to switch the logo while switching the style and/or variation.
# 
# the *IMG cases will return a full <img src /> tag
#
sub render {
  my ($session, $params) = @_;

  my $format = $params->{format};
  $format = '<a href="$url" title="$alt">$logo</a>' unless defined $format;

  my $result = $format;
  $result =~ s/\$logo/renderLogo()/ge;
  $result =~ s/\$src/renderSrc()/ge;
  $result =~ s/\$url/renderUrl()/ge;
  $result =~ s/\$path/renderPath()/ge;
  $result =~ s/\$variation/renderVariation()/ge;
  $result =~ s/\$style/renderStyle()/ge;
  $result =~ s/\$alt/renderAlt()/ge;
  $result =~ s/\$name/renderName()/ge;
  $result =~ s/\$perce?nt/\%/go;
  $result =~ s/\$nop//go;
  $result =~ s/\$n/\n/go;
  $result =~ s/\$dollar/\$/go;

  return $result;

}

###############################################################################
sub renderName {
  return Foswiki::Func::getPreferencesValue('NATWEBLOGONAME');
}

###############################################################################
sub renderAlt {
  return
    Foswiki::Func::getPreferencesValue('NATWEBLOGOALT') || 
    Foswiki::Func::getPreferencesValue('WEBLOGOALT') || 
    Foswiki::Func::getPreferencesValue('WIKILOGOALT') || 
    Foswiki::Func::getPreferencesValue('WIKITOOLNAME') || 
    'Foswiki';
}

###############################################################################
sub renderStyle {

  my $themeEngine = Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine();
  return lc $themeEngine->{skinState}{style};
}

###############################################################################
sub renderVariation {

  my $themeEngine = Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine();
  my $variation = lc $themeEngine->{skinState}{variation};
  $variation = '' if $variation eq 'off';
  return $variation;
}

###############################################################################
sub renderPath {

  my $themeEngine = Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine();
  my $themeRecord = $themeEngine->getThemeRecord($themeEngine->{skinState}{'style'});
  return $themeRecord?$themeRecord->{path}:'';
}

###############################################################################
sub renderUrl {

  my $url = Foswiki::Func::getPreferencesValue('NATWEBLOGOURL') ||
    Foswiki::Func::getPreferencesValue('WEBLOGOURL') ||
    Foswiki::Func::getPreferencesValue('WIKILOGOURL') ||
    Foswiki::Func::getPreferencesValue('%SCRIPTURLPATH{"view"}%/%USERSWEB%/%HOMETOPIC%');

  return $url;
}

###############################################################################
sub renderSrc {

  my $wikiLogoImage = Foswiki::Func::getPreferencesValue('WIKILOGOIMG');

  my $result = 
    Foswiki::Func::getPreferencesValue('NATWEBLOGOIMG') || 
    Foswiki::Func::getPreferencesValue('WEBLOGOIMG') || 
    $wikiLogoImage;

  # HACK: override ProjectLogos with own version
  $result =~ s/\%WIKILOGOIMG%/$wikiLogoImage/g;
  if ($result =~ s/ProjectLogos/NatSkin/g) {
    $result =~ s/gif/png/;
  }

  return $result;
}

###############################################################################
sub renderLogo {

  my $result;

  my $name = renderName();

  if ($name) {
    $result = '<span class="natWebLogo natWebLogoName">$name</span>';
  } else {
    my $image = renderSrc();
    if ($image) {
      $result = '<img class="natWebLogo natWebLogoImage" src="$src" alt="$alt" border="0" />';
    } else {
      $result = '<span class="natWebLogo natWebLogoName">%WIKITOOLNAME%</span>';
    }
  }

  return $result;
}

1;
