#!/usr/bin/perl -w
#
# Build file
#
package BugsContribBuild;

BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}

use Foswiki::Contrib::Build;
our @ISA = qw( Foswiki::Contrib::Build );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new("BugsContrib"), $class );
}

$build = new BugsContribBuild();
$build->build( $build->{target} );
