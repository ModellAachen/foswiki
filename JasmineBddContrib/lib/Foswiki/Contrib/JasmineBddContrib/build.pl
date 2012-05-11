#!/usr/bin/perl -w
use strict;

BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}

use Foswiki::Contrib::Build;

package JSCalendarBuild;

@JSCalendarBuild::ISA = ("Foswiki::Contrib::Build");

sub new {
    my $class = shift;
    return bless( $class->SUPER::new("JasmineBddContrib"), $class );
}

my $build = new JSCalendarBuild();

$build->build( $build->{target} );
