#! /usr/local/bin/perl -w

# from http://perl.active-venture.com/pod/perlfaq4-dataarrays.html

use strict;
use diagnostics;

my @array1 = ("localInstallation");
my @array2 = ( "distro1", "distro2", "distro3", "localInstallation" );

use ArraySets;
my ( $union, $intersection, $difference ) =
  ArraySets::compare( \@array1, \@array2 );

print_array( "1",            @array1 );
print_array( "2",            @array1 );
print_array( "union",        @{$union} );
print_array( "intersection", @{$intersection} );
print_array( "difference",   @{$difference} );

sub print_array {
    my ( $n, @arr ) = @_;
    print "$n:\t" . join( "\n\t", @arr ) . "\n";
}
