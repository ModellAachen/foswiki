#!/usr/bin/perl -w
BEGIN { unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} ); }

package BuildBuild;
use Foswiki::Contrib::Build;
our @ISA = qw( Foswiki::Contrib::Build );

use FindBin;

#use File::Find;

sub new {
    my $class = shift;
    my $this = bless( $class->SUPER::new("MathJaxPlugin"), $class );

    $this->{DEBUG} = 1;

    return $this;
}

sub target_build {
    my $this = shift;

    $this->SUPER::target_build();

    my $base_dir = $FindBin::Bin . '/../../../../pub/System/MathJaxPlugin/';
    $this->{DEBUG} && print STDERR "base_dir=[$base_dir]\n";
    chdir $base_dir or die $!;

    my $mathjax = 'MathJax-v1.1a.zip';
    my $file    = $base_dir . $mathjax;
    $this->{DEBUG} && print STDERR "file=[$file]\n";

    unless ( -e $file ) {
        system(
            wget => '-O' => $mathjax,
            'https://github.com/mathjax/MathJax/zipball/v1.1a'
        );
    }

    system( unzip => '-u' => $mathjax );
    rename( 'mathjax-MathJax-f5cd294', 'MathJax' );
}

################################################################################

package main;

# Create the build object
my $build = new BuildBuild();

$build->{UPLOADTARGETWEB}    = 'Extensions';
$build->{UPLOADTARGETPUB}    = 'http://foswiki.org/pub';
$build->{UPLOADTARGETSCRIPT} = 'http://foswiki.org/bin';
$build->{UPLOADTARGETSUFFIX} = '';

# Build the target on the command line, or the default target
$build->build( $build->{target} );

################################################################################
################################################################################
