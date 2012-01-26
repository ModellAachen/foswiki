# See bottom of file for license and copyright information
package Foswiki::Contrib::DBCacheContrib::MemMap;
use strict;
use Foswiki::Contrib::DBCacheContrib::Map ();
our @ISA = ( 'Foswiki::Contrib::DBCacheContrib::Map' );

use Assert;

# Package-private map object that stores hashes in memory. Used with
# Storable and File archivists.

sub DESTROY {
    my $this = shift;

    # prevent recursive destruction
    return if $this->{_destroying};
    $this->{_destroying} = 1;

    # destroy sub objects
    map {
        $_->DESTROY()
          if $_
              && $_ ne $this
              && ref($_)
              && !Scalar::Util::isweak($_)
              && UNIVERSAL::can( $_, 'DESTROY' );
    } values %{ $this->{keys} };

    $this->{keys} = undef;
}

sub STORE {
    my ( $this, $key, $value ) = @_;
    $this->{keys}{$key} = $value;
    Scalar::Util::weaken( $this->{keys}{$key} )
        if ( ref($value) && $key =~ /^_/ );
}

sub FETCH {
    my ( $this, $key ) = @_;
    return $this->{keys}{$key};
}

sub FIRSTKEY {
    my $this = shift;
    return each %{ $this->{keys} };
}

sub NEXTKEY {
    my ( $this, $lastkey ) = @_;
    return each %{ $this->{keys} };
}

sub EXISTS {
    my ( $this, $key ) = @_;
    return exists $this->{keys}{$key};
}

sub DELETE {
    my ( $this, $key ) = @_;
    return delete $this->{keys}{$key};
}

sub CLEAR {
    my ($this) = @_;
    $this->{keys} = ();
}

sub SCALAR {
    my ($this) = @_;
    return scalar %{ $this->{keys} };
}

sub getKeys {
    my $this = shift;
    return keys %{ $this->{keys} };
}

sub getValues {
    my $this = shift;
    return values %{ $this->{keys} };
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
