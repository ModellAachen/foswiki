#!/usr/bin/perl -w
BEGIN {
    unshift @INC, split( /:/, $ENV{TWIKI_LIBS} );
}
use Foswiki::Contrib::Build;

# Create the build object
$build = new Foswiki::Contrib::Build('SetVariablePlugin');

# Build the target on the command line, or the default target
$build->build($build->{target});
