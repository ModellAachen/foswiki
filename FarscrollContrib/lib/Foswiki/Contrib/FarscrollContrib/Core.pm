package Foswiki::Contrib::FarscrollContrib::Core;

use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

sub new {
  my $class = shift;

  my $this = bless(
    $class->SUPER::new(
      name => 'Farscroll',
      version => '0.1.0',
      author => 'Sebastian Senf',
      homepage => 'https://github.com/mustardamus/farscroll-plugin',
      javascript => ['jquery.farscroll.js'],
      documentation => 'FarscrollContrib',
      puburl => '%PUBURLPATH%/%SYSTEMWEB%/FarscrollContrib',
    ),
    $class
  );

  return $this;
}

1;
