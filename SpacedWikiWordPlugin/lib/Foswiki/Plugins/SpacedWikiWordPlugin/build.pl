#!/usr/bin/perl -w
#
# Example build class. Copy this file to the equivalent place in your
# plugin or contrib and edit.
#
# Read the comments at the top of lib/Foswiki/Contrib/Build.pm for
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

package SpacedWikiWordPluginBuild;

# Standard preamble
BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}

use Foswiki::Contrib::Build;
our @ISA = qw( Foswiki::Contrib::Build );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new("SpacedWikiWordPlugin"), $class );
}

$build = new SpacedWikiWordPluginBuild();
$build->build( $build->{target} );
