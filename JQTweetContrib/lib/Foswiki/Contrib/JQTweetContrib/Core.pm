package Foswiki::Contrib::JQTweetContrib::Core;

use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

sub new {
  my $class = shift;

  my $this = bless(
    $class->SUPER::new(
      name => 'Tweet',
      version => '95445312de',
      author => 'Todd Matthews & Steve Purcell',
      homepage => 'http://tweet.seaofclouds.com/',
      css => ['jquery.tweet.css'],
      javascript => ['jquery.tweet.js', 'jquery.tweet.init.js'],
      documentation => 'JQTweetContrib',
      puburl => '%PUBURLPATH%/%SYSTEMWEB%/JQTweetContrib',
      dependencies => ['metadata'],
    ),
    $class
  );

  return $this;
}

1;
