# See bottom of file for license and copyright information

package Foswiki::Contrib::DBCacheContrib::MemArray;
use strict;

use Foswiki::Contrib::DBCacheContrib::Array ();
our @ISA = ( 'Foswiki::Contrib::DBCacheContrib::Array' );

use Assert;

# Package-private array object that stores arrays in memory. Used with
# Storable and File archivists.

sub DESTROY {
    my $this = shift;

    # prevent recursive destruction
    return if $this->{_destroying};
    $this->{_destroying} = 1;

    # destroy sub objects
    foreach my $value ( @{ $this->{values} } ) {
        if (   $value
            && ref($value)
            && UNIVERSAL::can( $_, 'DESTROY' ) )
        {
            $value->DESTROY();
        }
    }
    $this->{values} = undef;
}

sub FETCH {
    my ( $this, $key ) = @_;
    return $this->{values}[$key];
}

sub FETCHSIZE {
    my $this = shift;
    return 0 unless defined $this->{values};
    return scalar( @{ $this->{values} } );
}

sub STORE {
    my ( $this, $index, $value ) = @_;
    $this->{values}[$index] = $value;
}

sub STORESIZE {
    my ( $this, $count ) = @_;
    $#{ $this->{values} } = $count - 1;
}

sub EXISTS {
    my ( $this, $index ) = @_;
    return $index < scalar( @{ $this->{values} } );
}

sub DELETE {
    my ( $this, $index ) = @_;
    return delete( $this->{values}[$index] );
}

sub CLEAR {
    my $this = shift;
    $this->{values} = undef;
}

sub PUSH {
    my $this = shift;
    return push( @{ $this->{values} }, @_ );
}

sub POP {
    my $this = shift;
    return pop @{ $this->{values} };
}

sub SHIFT {
    my $this = shift;
    return shift @{ $this->{values} };
}

sub UNSHIFT {
    my $this = shift;
    return unshift( @{ $this->{values} }, @_ );
}

sub getValues {
    my $this = shift;
    return @{ $this->{values} };
}

1;
__END__

Copyright (C) Crawford Currie 2004-2009, http://c-dot.co.uk
and Foswiki Contributors. Foswiki Contributors are listed in the
AUTHORS file in the root of this distribution. NOTE: Please extend
that file, not this notice.

Additional copyrights apply to some or all of the code in this module
as follows:
   * Copyright (C) Motorola 2003 - All rights reserved

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
