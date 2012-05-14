package Foswiki::Contrib::JQTweetContrib;

use strict;
use warnings;

our $VERSION = '$Rev$';
our $RELEASE = '1.0';
our $SHORTDESCRIPTION = 'Put twitter on your website';
our $NO_PREFS_IN_TOPIC = 1;

sub init {
  require Foswiki::Plugins::JQueryPlugin ();
  Foswiki::Plugins::JQueryPlugin::registerPlugin("tweet", "Foswiki::Contrib::JQTweetContrib::Core");
}

1;
