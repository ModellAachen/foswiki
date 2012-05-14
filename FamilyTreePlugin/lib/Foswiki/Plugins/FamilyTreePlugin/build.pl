#!/usr/bin/perl -w
#
package FamilyTreePluginBuild;

BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} || '' ) ) {
        unshift @INC, $pc;
    }
}
use Foswiki::Contrib::Build;

$build = new Foswiki::Contrib::Build("FamilyTreePlugin");
$build->build( $build->{target} );
