# See bottom of file for notices

package Foswiki::Plugins::SafeWikiPlugin::Leaf;

use strict;

sub new {
    my ( $class, $text ) = @_;

    my $this = {};

    $this->{text} = $text;

    return bless( $this, $class );
}

sub stringify {
    my ($this) = @_;
    return $this->{text};
}

sub generate {
    my ($this) = @_;
    return $this->{text};
}

sub isLeaf {
    return 1;
}

1;
__DATA__

Copyright (C) 2007-2009 C-Dot Consultants http://c-dot.co.uk
All rights reserved
Author: Crawford Currie

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html

This notice must be retained in all copies or derivatives of this
code.
