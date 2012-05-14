#!/usr/bin/perl -w
#
# Build for FoswikiInstallerContrib
#
BEGIN {
    unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} );
}

use Foswiki::Contrib::Build;

# Create the build object
$build = new Foswiki::Contrib::Build('FoswikiInstallerContrib');

# Build the target on the command line, or the default target
$build->build( $build->{target} );

