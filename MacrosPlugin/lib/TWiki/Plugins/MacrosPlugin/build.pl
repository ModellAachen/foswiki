#!/usr/bin/perl -w
#
# Build class for MacrosPlugin

BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}

use TWiki::Contrib::Build;

package MacrosPluginBuild;

@MacrosPluginBuild::ISA = ("TWiki::Contrib::Build");

sub new {
    my $class = shift;
    return bless( $class->SUPER::new("MacrosPlugin"), $class );
}

$build = new MacrosPluginBuild();

$build->build( $build->{target} );
