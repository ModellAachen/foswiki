#!/usr/bin/perl -w
#
# Build file for JHot Draw Plugin
#
# Standard preamble
BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}

use Foswiki::Contrib::Build;

# Declare our build package
package JHotDrawPluginBuild;
use Foswiki::Contrib::Build;
our @ISA = qw( Foswiki::Contrib::Build );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new("JHotDrawPlugin"), $class );
}

# Override the build target to build the java code
sub target_build {
    my $this = shift;

    $this->SUPER::target_build();

    $this->pushd( $this->{basedir} . "/lib/Foswiki/Plugins/JHotDrawPlugin" );
    $this->sys_action( "ant", "-f", "build.xml", "build" );
    $this->popd();
}

# Create the build object
$build = new JHotDrawPluginBuild();

# Build the target on the command line, or the default target

$build->build( $build->{target} );

