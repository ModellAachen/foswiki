#!/usr/bin/perl -w
#
# Build file
#
package MailPageAddOnBuild;

BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}

use TWiki::Contrib::Build;

@MailPageAddOnBuild::ISA = ("TWiki::Contrib::Build");

sub new {
    my $class = shift;
    return bless( $class->SUPER::new("MailPageAddOn"), $class );
}

$build = new MailPageAddOnBuild();
$build->build( $build->{target} );
