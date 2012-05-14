#!/usr/bin/perl -w
#
# Build for GenPDFLatexAddOn
#
BEGIN {
    unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} );
}

use Foswiki::Contrib::Build;

# Create the build object
$build = new Foswiki::Contrib::Build('GenPDFLatexAddOn');

# Build the target on the command line, or the default target
$build->build( $build->{target} );

