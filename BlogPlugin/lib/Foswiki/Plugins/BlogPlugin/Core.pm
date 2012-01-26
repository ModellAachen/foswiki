# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2011 Michael Daum http://michaeldaumconsulting.com
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
package Foswiki::Plugins::BlogPlugin::Core;

use strict;
use warnings;

use Foswiki::Plugins::DBCachePlugin ();

our $debug = 0; # toggle me

###############################################################################
# static
sub inlineError {
  return "<span class='foswikiAlert'>" . $_[0] . "</span>" ;
}

###############################################################################
# static
sub writeDebug {
  #Foswiki::Func::writeDebug('- BlogPlugin - ' . $_[0]) if $debug;
  print STDERR "- BlogPlugin - $_[0]\n" if $debug;
}


###############################################################################
sub new {
  my ($class, $baseWeb, $baseTopic) = @_;

  my $this = bless({}, $class);

  $this->{baseWeb} = $baseWeb;
  $this->{baseTopic} = $baseTopic;

  return $this;
}

1;
