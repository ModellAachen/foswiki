#!/usr/bin/perl -w
#
# Build for NetgrepPlugin
#
BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}

use Foswiki::Contrib::Build;

# Create the build object
$build = new Foswiki::Contrib::Build('NetgrepPlugin');

# Build the target on the command line, or the default target
$build->build( $build->{target} );

