# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2011 http://michaeldaumconsulting.com
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
package Foswiki::Plugins::BlogPlugin;

use strict;
use warnings;
use Error qw(:try);

our $core;
our $VERSION = '$Rev$';
our $RELEASE = '2.00';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = 'Basic blogging features used to implement the BlogApp <nop>WikiApplication';
our $baseTopic;
our $baseWeb;

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  $core = undef;

  Foswiki::Func::registerRESTHandler('blogconvert', \&handleBlogConvert);

  return 1;
}

###############################################################################
sub handleBlogConvert {

  require Foswiki::Plugins::BlogPlugin::Converter;
  my $converter = new Foswiki::Plugins::BlogPlugin::Converter;

  my @params = @_;

  try {
    $converter->convert(@params);
  }
  catch Error::Simple with {
    my $error = shift;

    print STDERR "ERROR: " . $error->{-text} . "\n";
  };

  return "";
}

1;

