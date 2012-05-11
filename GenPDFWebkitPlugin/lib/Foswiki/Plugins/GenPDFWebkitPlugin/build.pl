#!/usr/bin/perl -w
BEGIN {
  foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use Foswiki::Contrib::Build;

package BuildBuild;

@BuildBuild::ISA = ( "Foswiki::Contrib::Build" );

sub new {
  my $class = shift;
  return bless( $class->SUPER::new( "GenPDFWebkitPlugin" ), $class );
}

$build = new BuildBuild();

$build->build($build->{target});
