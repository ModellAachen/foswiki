#!/usr/bin/perl -w
#
# Build class for FormQueryPlugin
# Requires the environment variable FOSWIKI_LIBS to be
# set to point at the DBCache repository

# Standard preamble
BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}
use Foswiki::Contrib::Build;

$build = new Foswiki::Contrib::Build('FormQueryPlugin');

$build->build( $build->{target} );
