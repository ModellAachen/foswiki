#!/usr/bin/perl -w
#
# Build for PeerPlugin
#
BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}

use TWiki::Contrib::Build;

# Create the build object
$build = new TWiki::Contrib::Build('PeerPlugin');

# Build the target on the command line, or the default target
$build->build( $build->{target} );

