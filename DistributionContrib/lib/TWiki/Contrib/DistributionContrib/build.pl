#!/usr/bin/perl -w
#
## Usage: ./build.pl [-n] [-v] [target]
# where [target] is the optional build target (build, test,
# install, release, uninstall), test is the default.
# Two command-line options are supported:
# -n Don't actually do anything, just print commands
# -v Be verbose
#
# Read the comments at the top of lib/TWiki/Contrib/Build.pm for
# details of how the build process works, and what files you
# have to provide and where.
#
# Standard preamble
BEGIN {
    warn '$FOSWIKI_LIBS is not set' unless $ENV{FOSWIKI_LIBS};
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}
use TWiki::Contrib::Build;

use strict;
use diagnostics;

use Cwd;
my $runDir = cwd();

# Declare our build package
package DistributionContribBuild;

@DistributionContribBuild::ISA = ("TWiki::Contrib::Build");

sub new {
    my $class = shift;
    my $this = bless( $class->SUPER::new("DistributionContrib"), $class );
    return $this;
}

sub target_install {
    my $this = shift;
    $this->SUPER::target_install();
}

# Create the build object
my $builder = new DistributionContribBuild();

# Build the target on the command line, or the default target

if (@ARGV) {
    $builder->build( $builder->{target} );    #NB. Buildpm picks up from ARGV
}
else {
    $builder->build("test");
    $builder->build("build");
}

