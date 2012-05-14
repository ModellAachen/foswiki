# FootNotePlugin for Foswiki Collaboration Platform, http://foswiki.org/
#
# Copyright (C) 2009 Ian Bygrave, ian@bygrave.me.uk
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

# Footnote labelling formats.

package Foswiki::Plugins::FootNotePlugin::LabelFormat;

# Function that maps a positive integer to a label.
my %formatters = ();

# Arabic numerals
$formatters{1} = sub { return "$_[0]"; };

# Alphabet
$formatters{a} = sub { return chr( ( ord 'a' ) + ( $_[0] - 1 ) ); };
$formatters{A} = sub { return chr( ( ord 'A' ) + ( $_[0] - 1 ) ); };

# Roman numerals
eval { require Roman };
unless ($@) {
    import Roman;
    $formatters{i} = sub { return Roman::roman( $_[0] ); };
    $formatters{I} = sub { return Roman::Roman( $_[0] ); };
}

# Hexadecimal
$formatters{x} = sub { return sprintf( "0x%x", $_[0] ); };
$formatters{X} = sub { return sprintf( "0X%X", $_[0] ); };

# Create a new label formatter.
sub new {

    # $format is the name of the label format requested
    # %otherformats is the other label formats in use
    # on the same page.
    my ( $class, $format, %otherformats ) = @_;

    return undef() unless exists $formatters{$format};

    my $this = {
        n         => 1,
        formatter => $formatters{$format},
    };

    bless( $this, $class );

    return $this;
}

# Return the next label in the sequence.
sub makelabel {
    my ($this) = @_;

    my $label = &{ $this->{"formatter"} }( $this->{"n"} );

    $this->{"n"} += 1;

    return $label;
}

# end of class LabelFormat

1;

# vim:ts=2:sts=2:sw=2:et
