#!/usr/bin/perl -w
#
# Requires the environment variable FOSWIKI_LIBS (a colon-separated path
# list) to be set to point at the build system and any required dependencies.
# Usage: ./build.pl [-n] [-v] [target]
# where [target] is the optional build target (build, test,
# install, release, uninstall), test is the default.
# Two command-line options are supported:
# -n Don't actually do anything, just print commands
# -v Be verbose
#

# Standard preamble
BEGIN {
    unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} );
}

use Foswiki::Contrib::Build;

# Create the build object
$build = new Foswiki::Contrib::Build('EditSyntaxPlugin');

# Build the target on the command line, or the default target
$build->build( $build->{target} );
