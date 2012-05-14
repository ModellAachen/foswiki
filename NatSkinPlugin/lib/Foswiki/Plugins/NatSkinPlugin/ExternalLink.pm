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

package Foswiki::Plugins::NatSkinPlugin::ExternalLink;
use strict;
use warnings;

use Foswiki::Func ();

###############################################################################
sub render {
  my ($thePrefix, $theUrl) = @_;

  my $addClass = 0;
  my $text = $thePrefix.$theUrl;
  my $urlHost = Foswiki::Func::getUrlHost();
  my $httpsUrlHost = $urlHost;
  $httpsUrlHost =~ s/^http:\/\//https:\/\//go;

  $theUrl =~ /^http/i && ($addClass = 1); # only for http and hhtps
  $theUrl =~ /^$urlHost/i && ($addClass = 0); # not for own host
  $theUrl =~ /^$httpsUrlHost/i && ($addClass = 0); # not for own host
  $thePrefix =~ /class="[^"]*\bnop\b/ && ($addClass = 0); # prevent adding it 
  $thePrefix =~ /class="natExternalLink"/ && ($addClass = 0); # prevent adding it twice

  if ($addClass) {
    #writeDebug("called renderExternalLink($thePrefix, $theUrl)");
    $text = "class='natExternalLink' $thePrefix$theUrl";
    #writeDebug("text=$text");
  }

  return $text;
}


1;
