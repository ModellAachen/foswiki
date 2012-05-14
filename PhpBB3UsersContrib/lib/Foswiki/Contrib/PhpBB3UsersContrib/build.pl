#!/usr/bin/perl -w
use strict;

# Standard preamble
BEGIN { unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} ) }

use Foswiki::Contrib::Build;

my $build = new Foswiki::Contrib::Build('PhpBB3UsersContrib');
$build->build( $build->{target} );
