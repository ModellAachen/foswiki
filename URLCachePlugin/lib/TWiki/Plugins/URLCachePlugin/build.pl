#!/usr/bin/perl -w
#
# Build for URLCachePlugin
#
BEGIN {
    unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} );
}

use TWiki::Contrib::Build;

# Create the build object
$build = new TWiki::Contrib::Build('URLCachePlugin');

# Build the target on the command line, or the default target
$build->build( $build->{target} );

