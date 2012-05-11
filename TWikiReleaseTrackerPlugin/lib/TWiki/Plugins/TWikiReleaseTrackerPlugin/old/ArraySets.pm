#! /usr/local/bin/perl -w

use strict;

package ArraySets;

sub intersection {
    my ( $allDistributionsForFilenameRef, $distributionsRef ) = @_;
    my ( $union, $intersection, $difference ) =
      ArraySets::compare( $allDistributionsForFilenameRef, $distributionsRef );
    return @{$intersection};
}

sub intersection2 {
    my ( $allDistributionsForFilenameRef, $distributionsRef ) = @_;
    my ( $listRef,                        $filterListRef )    = @_;
    my @ans;
    foreach my $element ( @{$listRef} ) {
      ELEMENT:
        foreach my $filter ( @{$filterListRef} ) {
            if ( $element =~ m/^$filter/ ) {

     # has to appear at the start to avoid problems of distro names appearing in
     # filenames
                push @ans, $element;
                next ELEMENT;
            }
        }
    }
    return @ans;
}

sub compare {

    my ( $array1ref, $array2ref ) = @_;
    my @array1 = @{$array1ref};
    my @array2 = @{$array2ref};

    my @intersection = ();
    my @difference   = ();

    my @union = @intersection = @difference = ();
    my %count = ();
    foreach my $element ( @array1, @array2 ) { $count{$element}++ }
    foreach my $element ( keys %count ) {
        push @union, $element;
        push @{ $count{$element} > 1 ? \@intersection : \@difference },
          $element;
    }

    return ( \@union, \@intersection, \@difference );
}

1;
