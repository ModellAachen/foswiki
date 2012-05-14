#!/usr/bin/perl -w
BEGIN { unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} ); }
use Foswiki::Contrib::Build;

# Create the build object
my $build = new Foswiki::Contrib::Build('EasyMacroPlugin');
$build->build($build->{target});

