#!/usr/bin/perl -w
BEGIN {
    unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} );
}
use Foswiki::Contrib::Build;

# Create the build object
$build = new Foswiki::Contrib::Build('RatingContrib');

$build->build( $build->{target} );

