#!/usr/bin/perl -w
#
# Build for ExitPlugin
#
BEGIN {
    unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} );
}

use Foswiki::Contrib::Build;

# Declare our build package
package BuildBuild;
use Foswiki::Contrib::Build;
our @ISA = qw( Foswiki::Contrib::Build );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new("ExitPlugin"), $class );
}

package main;

# Create the build object
$build = new BuildBuild();

# Build the target on the command line, or the default target
$build->build( $build->{target} );

