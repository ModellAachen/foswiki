#!/usr/bin/perl -w

# Standard preamble
BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}

use Foswiki::Contrib::Build;

# Declare our build package
{

    package CalendarPluginBuild;

    @CalendarPluginBuild::ISA = ("Foswiki::Contrib::Build");

    sub new {
        my $class = shift;
        return bless( $class->SUPER::new("CalendarPlugin"), $class );
    }

    # Example: Override the build target
    sub target_build {
        my $this = shift;

        $this->SUPER::target_build();

        # Do other build stuff here
    }
}

# Create the build object
$build = new CalendarPluginBuild();

# Build the target on the command line, or the default target
$build->build( $build->{target} );

