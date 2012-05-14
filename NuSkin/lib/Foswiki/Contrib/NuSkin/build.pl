#!/usr/bin/perl -w
use strict;

BEGIN { unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} ) }

use Foswiki::Contrib::Build;

# Declare our build package
package BuildBuild;
use Foswiki::Contrib::Build;
our @ISA = qw( Foswiki::Contrib::Build );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new("NuSkin"), $class );
}

# Example: Override the build target
sub target_build {
    my $this = shift;

    $this->SUPER::target_build();

    # Do other build stuff here
}

# Create the build object
my $build = new BuildBuild();

# Build the target on the command line, or the default target
$build->build( $build->{target} );

