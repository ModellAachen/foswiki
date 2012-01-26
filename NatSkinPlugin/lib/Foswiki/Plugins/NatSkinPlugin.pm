###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
# 
# Copyright (C) 2003-2010 MichaelDaum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatSkinPlugin;
use strict;

use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Plugins::NatSkinPlugin::ThemeEngine ();
use Foswiki::Plugins::NatSkinPlugin::Utils ();
use Foswiki::Plugins::NatSkinPlugin::WebComponent ();

###############################################################################
our $baseWeb;
our $baseTopic;

our $VERSION = '$Rev$';
our $RELEASE = '4.00rc2';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = 'Theming engine for NatSkin';

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  # theme engine macros
  Foswiki::Func::registerTagHandler('SKINSTATE', \&renderSkinState);
  Foswiki::Func::registerTagHandler('KNOWNSTYLES', \&renderKnownStyles);
  Foswiki::Func::registerTagHandler('KNOWNVARIATIONS', \&renderKnownVariations);

  # REVISIONS, MAXREV, CURREV replacements
  Foswiki::Func::registerTagHandler('PREVREV', \&renderPrevRevision);
  Foswiki::Func::registerTagHandler('CURREV', \&renderCurRevision);
  Foswiki::Func::registerTagHandler('NATMAXREV', \&renderMaxRevision);
  Foswiki::Func::registerTagHandler('NATREVISIONS', \&renderRevisions);

  # skin macros
  Foswiki::Func::registerTagHandler('USERACTIONS', \&renderUserActions);
  Foswiki::Func::registerTagHandler('NATWEBLOGO', \&renderNatWebLogo);
  Foswiki::Func::registerTagHandler('NATSTYLEURL', \&renderNatStyleUrl);
  Foswiki::Func::registerTagHandler('HTMLTITLE', \&renderHtmlTitle);
  Foswiki::Func::registerTagHandler('CONTENTTYPE', \&renderContentType);
  Foswiki::Func::registerTagHandler('WEBCOMPONENT', \&renderWebComponent);

  # init modules
  Foswiki::Plugins::NatSkinPlugin::ThemeEngine::init();
  Foswiki::Plugins::NatSkinPlugin::Utils::init();
  Foswiki::Plugins::NatSkinPlugin::WebComponent::init();

  return 1;
}

###############################################################################
sub completePageHandler {

  return if defined $Foswiki::cfg{NatSkin}{CleanUpHTML} && !$Foswiki::cfg{NatSkin}{CleanUpHTML};

  $_[0] =~ s/<!--.*?-->//g;
  $_[0] =~ s/^\s*$//gms;
  $_[0] =~ s/(<\/html>).*?$/$1/gs;

  # clean up %{<verbatim>}% ...%{</verbatim>}%
  $_[0] =~ s/\%{(<pre[^>]*>)}&#37;\s*/$1/g;
  $_[0] =~ s/\s*&#37;{(<\/pre>)}\%/$1/g; 

  # remove superfluous type attributes
  $_[0] =~ s/<script +type=["']text\/javascript["']/<script/g;
  $_[0] =~ s/<style +type=["']text\/css["']/<style/g;

  # rewrite link
  $_[0] =~ s/<link (.*?rel=["']stylesheet["'].*?)\/>/_processLinkStyle($1)/ge;

}

sub _processLinkStyle {
  my $args = shift;
  $args =~ s/type=["'].*?["']//g;
  return "<link $args/>";
}

###############################################################################
sub preRenderingHandler {

  # better cite markup
  $_[0] =~ s/[\n\r](>.*?)([\n\r][^>])/handleCite($1).$2/ges;
}

sub handleCite {
  my $block = shift;

  $block =~ s/^>/<span class='foswikiCiteChar'>&gt;<\/span>/gm;
  $block =~ s/\n/<br \/>\n/g;

  my $class = ($block =~ /<br \/>/)?'foswikiBlockCite':'foswikiCite';

  return "<div class='$class'>".$block."</div>";
}

###############################################################################
sub postRenderingHandler { 
  
  # detect external links
  return unless $Foswiki::cfg{NatSkin}{DetectExternalLinks};

  require Foswiki::Plugins::NatSkinPlugin::ExternalLink;

  $_[0] =~ s/<a\s+([^>]*?href=(?:\"|\'|&quot;)?)([^\"\'\s>]+(?:\"|\'|\s|&quot;>)?)/'<a '.Foswiki::Plugins::NatSkinPlugin::ExternalLink::render($1,$2)/geoi;
}

###############################################################################
sub renderKnownStyles {
  return Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine()->renderStyles(@_);
}

###############################################################################
sub renderKnownVariations {
  return Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine()->renderVariations(@_);
}

###############################################################################
sub renderSkinState {
  return Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine()->renderSkinState(@_);
}

###############################################################################
sub renderUserActions {
  require Foswiki::Plugins::NatSkinPlugin::UserActions;
  return Foswiki::Plugins::NatSkinPlugin::UserActions::render(@_);
}

###############################################################################
sub renderWebComponent {
  return Foswiki::Plugins::NatSkinPlugin::WebComponent::render(@_);
}

###############################################################################
sub renderPrevRevision {
  return Foswiki::Plugins::NatSkinPlugin::Utils::getPrevRevision($baseWeb, $baseTopic, 1);
}

###############################################################################
sub renderCurRevision {
  return Foswiki::Plugins::NatSkinPlugin::Utils::getCurRevision($baseWeb, $baseTopic);
}

###############################################################################
sub renderMaxRevision {
  return Foswiki::Plugins::NatSkinPlugin::Utils::getMaxRevision($baseWeb, $baseTopic);
}

#############################################################################
sub renderNatStyleUrl {
  return Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine()->getStyleUrl();
}

###############################################################################
# SMELL: move this into the core
sub renderContentType {
  require Foswiki::Plugins::NatSkinPlugin::ContentType;
  return Foswiki::Plugins::NatSkinPlugin::ContentType::render(@_);;
}

###############################################################################
sub renderHtmlTitle {
  require Foswiki::Plugins::NatSkinPlugin::HtmlTitle;
  return Foswiki::Plugins::NatSkinPlugin::HtmlTitle::render(@_);;
}

#############################################################################
sub renderNatWebLogo {
  require Foswiki::Plugins::NatSkinPlugin::WebLogo;
  return Foswiki::Plugins::NatSkinPlugin::WebLogo::render(@_);
}

###############################################################################
sub renderRevisions {
  require Foswiki::Plugins::NatSkinPlugin::Revisions;
  return Foswiki::Plugins::NatSkinPlugin::Revisions::render(@_);
}

1;

