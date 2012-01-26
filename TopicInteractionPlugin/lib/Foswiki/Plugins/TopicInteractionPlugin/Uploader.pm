# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2010-2012 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::TopicInteractionPlugin::Uploader;
use strict;

use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Plugins::JQueryPlugin::Plugin;

our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::TopicInteractionPlugin::Uploader

This is the perl stub for the jquery.uploader plugin.

=cut

=begin TML

---++ ClassMethod new( $class, ... )

Constructor

=cut

sub new {
  my $class = shift;

  my $this = bless($class->SUPER::new( 
    $Foswiki::Plugins::SESSION,
    name => 'Uploader',
    version => '1.0.0',
    author => 'Michael Daum',
    homepage => 'http://foswiki.org/Externsions/TopicInteractionPlugin',
    puburl => '%PUBURLPATH%/%SYSTEMWEB%/TopicInteractionPlugin',
    documentation => "$Foswiki::cfg{SystemWebName}.TopicInteractionPlugin",
    javascript => ['jquery.uploader.js'],
    css => ['jquery.uploader.css'],
    dependencies => ['blockui', 'scrollto', 'button', 'livequery', 'metadata', 'simplemodal', 'JavaScriptFiles/foswikiPref', 'JQUERYPLUGIN::UPLOADER::ENGINES'], 
    @_
  ), $class);

  return $this;
}

=begin TML

---++ ClassMethod init( $this )

Initialize this plugin by adding the required static files to the page

=cut

sub init {
  my $this = shift;

  $this->SUPER::init();

  my $attachFileSizeLimit = Foswiki::Func::getPreferencesValue("ATTACHFILESIZELIMIT") || 0;

  my $engines = $Foswiki::cfg{TopicInteractionPlugin}{UploadEngines} || 'html5, flash, silverlight, gears, browserplus, html4';
  my @engines = split(/\s*,\s*/, $engines);
  my %enabled = map {lc($_), 1} @engines;

  # get meta configuration
  my @meta = ();

  push @meta, '<meta name="foswiki.TopicInteractionPlugin.attachFileSizeLimit" content="'.$attachFileSizeLimit.'" />';
  push @meta, '<meta name="foswiki.TopicInteractionPlugin.Runtimes" content="'.$engines.'" />';

  # add flash config
  push @meta, '<meta name="foswiki.TopicInteractionPlugin.flashUrl" content="%PUBURLPATH%/%SYSTEMWEB%/TopicInteractionPlugin/plupload.flash.swf" />'
    if $enabled{flash};

  # add silverlight config
  push @meta, '<meta name="foswiki.TopicInteractionPlugin.silverlightUrl" content="%PUBURLPATH%/%SYSTEMWEB%/TopicInteractionPlugin/plupload.silverlight.xap" />'
    if $enabled{silverlight};

  Foswiki::Func::addToZone("head", "JQUERYPLUGIN::UPLOADER::META", join("\n", @meta));

  my $js = $this->renderJS("plupload.js");

  # get js for runtime engines
  foreach my $engine (@engines) {
    $js .= $this->renderJS("$engine.init.js") if $engine =~ /browserplus|gears/;
    $js .= $this->renderJS("plupload.$engine.js");
  }

  Foswiki::Func::addToZone("script", "JQUERYPLUGIN::UPLOADER::ENGINES", $js, 'JQUERYPLUGIN::UPLOADER');
}

1;

