# Plugin for mediawiki2foswiki
#
# Copyright (C) 2007-2012 Michael Daum http://michaeldaumconsulting.com

package EmptyMediaWiki2FoswikiPlugin;
use strict;

##############################################################################
sub registerHandlers {
  my $converter = shift;

  #$converter->writeDebug("registering callbacks");

  #$converter->registerHandler('init', \&handleInit);
  #$converter->registerHandler('before', \&handleBefore);
  #$converter->registerHandler('title', \&handleTitle);
  #$converter->registerHandler('after', \&handleAfter);
  #$converter->registerHandler('final', \&handleFinal);
}

##############################################################################
# called after the converter has been constructed
sub DISABLED_handleInit {
  my $converter = shift;
}

##############################################################################
# called when the title of a mediawiki is converted to a TopicTitle
sub DISABLED_handleTitle {
  my $converter = shift;
  my $page = shift;

  #$converter->writeDebug("called handleTitle");
  #$converter->writeDebug("before, title=$_[0]");

  # remove umlaute
  $_[0] =~ s/ä/ae/go;
  $_[0] =~ s/ö/oe/go;
  $_[0] =~ s/ü/ue/go;
  $_[0] =~ s/Ä/Ae/go;
  $_[0] =~ s/Ö/Oe/go;
  $_[0] =~ s/Ü/Ue/go;
  $_[0] =~ s/ß/ss/go;

  #$converter->writeDebug("after, title=$_[0]");
}

##############################################################################
# called before one page is converted
sub DISABLED_handleBefore {
  my $converter = shift;
  my $page = shift;

  #$converter->writeDebug("called handleBefore");
}

##############################################################################
# called after a page has been converted to a topic
sub DISABLED_handleAfter {
  my $converter = shift;
  my $page = shift;

  #$converter->writeDebug("called handleAfter");
}

##############################################################################
# called after all pages have been converted
sub DISABLED_handleFinal {
  my $converter = shift;

  #$converter->writeDebug("called handleFinal");
}

1;
