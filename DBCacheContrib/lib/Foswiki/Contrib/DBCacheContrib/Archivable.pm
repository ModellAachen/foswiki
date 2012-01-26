# See bottom of file for license and copyright information

# Package-private mixin to add archivability to a collection object.

package Foswiki::Contrib::DBCacheContrib::Archivable;
use strict;
use Scalar::Util ();

sub setArchivist {
    my $this      = shift;
    my $archivist = shift;
    my $done      = shift;

    $done ||= {};
    if ($archivist) {
        $this->{archivist} = $archivist;
        Scalar::Util::weaken( $this->{archivist} );
    }
    else {
        delete $this->{archivist};
    }
    $done->{$this} = 1;
}

sub getArchivist {
    my $this = shift;
    return $this->{archivist};
}

1;
__END__

Copyright (C) Crawford Currie 2009, http://c-dot.co.uk
and Foswiki Contributors. Foswiki Contributors are listed in the
AUTHORS file in the root of this distribution. NOTE: Please extend
that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
