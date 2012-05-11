#!/usr/bin/perl -w
#
# Build class for EditTablerowPlugin
# Requires the environment variable FOSWIKI_LIBS to be
# set to point at the TWiki installation
#
# Read the comments at the top of lib/TWiki/Plugins/Build.pm for
# details of how the build process works, and what files you
# have to provide and where.
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
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}

use TWiki::Contrib::Build;

# Create the build object
$build = new TWiki::Contrib::Build('EditHiddenTablePlugin');

# Build the target on the command line, or the default target
$build->build( $build->{target} );
