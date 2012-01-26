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

package Foswiki::Plugins::ImagePlugin::IMAGETOOLTIP;
use strict;

use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::ImagePlugin::IMAGETOOLTIP

This is the perl stub for the jquery.imagetooltip plugin.

=cut

=begin TML

---++ ClassMethod new( $class, $session, ... )

Constructor

=cut

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = bless($class->SUPER::new( 
    $session,
    name => 'ImageTooltip',
    version => '1.0',
    author => 'Michael Daum',
    homepage => 'http://foswiki.org/Extensions/ImagePlugin',
    puburl => '%PUBURLPATH%/%SYSTEMWEB%/ImagePlugin',
    documentation => "$Foswiki::cfg{SystemWebName}.ImagePlugin",
    javascript => ['jquery.imagetooltip.js'],
    dependencies => ['metadata', 'livequery', 'tooltip'], 
  ), $class);

  return $this;
}

1;

