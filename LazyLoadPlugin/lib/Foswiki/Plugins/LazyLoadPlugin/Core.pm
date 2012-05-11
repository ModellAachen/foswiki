package Foswiki::Plugins::LazyLoadPlugin::Core;

use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = bless(
    $class->SUPER::new(
      $session,
      name => 'LazyLoad',
      version => '1.7.2',
      author => 'Mika Tuupola',
      homepage => 'http://www.appelsiini.net/projects/lazyload',
      javascript => ['jquery.lazyload.js', 'jquery.lazyload.init.js'], 
      documentation => 'LazyLoadPlugin',
      puburl => '%PUBURLPATH%/%SYSTEMWEB%/LazyLoadPlugin',
      dependencies => ["metadata"],
    ),
    $class
  );

  return $this;
}

1;
