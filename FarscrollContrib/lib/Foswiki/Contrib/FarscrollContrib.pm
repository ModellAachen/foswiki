package Foswiki::Contrib::FarscrollContrib;

use strict;
use warnings;

our $VERSION = '$Rev$';
our $RELEASE = '1.0.0';
our $SHORTDESCRIPTION = 'Clone a scrollbar far away';
our $NO_PREFS_IN_TOPIC = 1;

sub init {
  require Foswiki::Plugins::JQueryPlugin ();
  Foswiki::Plugins::JQueryPlugin::registerPlugin("Farscroll", "Foswiki::Contrib::FarscrollContrib::Core");
}

1;
