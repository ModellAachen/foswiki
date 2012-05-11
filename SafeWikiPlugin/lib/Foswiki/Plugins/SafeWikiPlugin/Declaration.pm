# See bottom of file for notices

=pod

---+ package Foswiki::Plugins::SafeWikiPlugin::Declaration

A declaration node in an HTML parse tree

=cut

package Foswiki::Plugins::SafeWikiPlugin::Declaration;

use strict;
use Assert;

sub new {
    my ( $class, $text ) = @_;

    my $this = { text => $text };
    $this->{children} = [];
    return bless( $this, $class );
}

# debug generate the parse tree as HTML
sub stringify {
    my ($this) = @_;
    my $r = $this->{text};
    foreach my $kid ( @{ $this->{children} } ) {
        $r .= $kid->stringify();
    }
    return $r;
}

sub isLeaf {
    return 0;
}

# Called by the parser
sub addChild {
    my ( $this, $node ) = @_;
    push( @{ $this->{children} }, $node );
}

# generate the parse tree, applying filters
sub generate {
    my ( $this, $filterURI, $filterHandler, $filterInline ) = @_;
    my $text = $this->{text};
    foreach my $kid ( @{ $this->{children} } ) {
        $text .= $kid->generate( $filterURI, $filterHandler, $filterInline );
    }
    return $text;
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
