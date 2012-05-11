#!/usr/bin/perl -w
#
# Build file for Action Tracker Plugin
#
package WebPermissionsPluginBuild;

BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}

use Foswiki::Contrib::Build;

@WebPermissionsPluginBuild::ISA = ("Foswiki::Contrib::Build");

sub new {
    my $class = shift;
    return bless( $class->SUPER::new("WebPermissionsPlugin"), $class );
}

$build = new WebPermissionsPluginBuild();
$build->build( $build->{target} );
