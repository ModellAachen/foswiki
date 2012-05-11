#!/usr/bin/perl -w
#
# Build for FootNotePlugin
#
BEGIN {
    unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} );
}

use Foswiki::Contrib::Build;

# Create the build object
my $build = new Foswiki::Contrib::Build('FootNotePlugin');

# Build the target on the command line, or the default target
$build->build( $build->{target} );

