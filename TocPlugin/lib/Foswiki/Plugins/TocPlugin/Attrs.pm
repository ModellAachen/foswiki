#
# Copyright (C) Motorola 2001 - All rights reserved
#
# Foswiki extension that adds tags for the generation of tables of contents.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#

# Class of attribute sets
package Foswiki::Plugins::TocPlugin::Attrs;

use strict;
use integer;

# Parse a standard attribute string containing name=value pairs. The
# value may be a word or a quoted string (no escapes!)
sub new {
    my ( $class, $string ) = @_;
    my $this = {};

    if ( defined($string) ) {

        # name="value" pairs
        while ( $string =~ s/([a-z]+)\s*=\s*\"([^\"]*)\"//o ) {
            $this->{$1} = $2;
        }

        # name=value pairs
        while ( $string =~ s/([a-z]+)\s*=\s*([^\s,\}]*)//o ) {
            $this->{$1} = $2;
        }

        # simple name with no value (boolean)
        while ( $string =~ s/([a-z]+)//o ) {
            $this->{$1} = 1;
        }
    }
    return bless $this, $class;
}

# PUBLIC Get an attr value; return undef if not set
sub get {
    my ( $this, $attr ) = @_;
    return $this->{$attr};
}

# PUBLIC Set an attr value; return previous value
sub set {
    my ( $this, $attr, $val ) = @_;
    my $oval = $this->get($attr);
    $this->{$attr} = $val;
    return $oval;
}

1;
