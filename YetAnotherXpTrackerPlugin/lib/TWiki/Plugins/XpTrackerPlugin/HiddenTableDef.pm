#
# Copyright (C) Motorola 2005 - All rights reserved
#
use strict;
use integer;

use TWiki::Attrs;

# A table definition object. This encapsulates the formatting of
# a "table" object inside a topic - or at least, mostly. The
# invoked still has to know what a table looks like at the start
# so it knows when to start loading rows.
package TWiki::Plugins::XpTrackerPlugin::HiddenTableDef;

# PUBLIC
# Generate a new table def by reading topic text and extracting
# the template definition from it

## SMELL: Seems to handle [[xxx][yyy]] incorrectly:
## TeamMembersReviewer = UNDEF
sub new {
    my ( $class, $text ) = @_;

    my $this = bless( {}, $class );
    my $inBlock = 0;
    $text =~ s/\\\r?\n//go;    # remove trailing '\' and join continuation lines

    # | *Name* | *Type* | *Size* | *Value*  | *Tooltip message* | *Attributes* |
    # Tooltip and attributes are optional
    foreach ( split( /\n/, $text ) ) {
        if (/^\s*\|.*Name[^|]*\|.*Type[^|]*\|.*Size[^|]*\|/) {
            $inBlock = 1;
        }
        else {

       # Only insist on first field being present FIXME - use oops page instead?
            if ( $inBlock && s/^\s*\|//o ) {
                my ( $title, $type, $size, $vals, $tooltip, $attributes ) =
                  split(/\|/);
                if ( $title =~ /\s*\[\[.*?\]\[\s*(\w*)\s*\]\]/o ) {
                    $title = $1;
                }
                $title =~ s/\W//go;
                push( @{ $this->{fields} }, $title );
            }
            else {
                $inBlock = 0;
            }
        }
    }

    return $this;
}

# PUBLIC
# Load a single data row into an Map object, assuming
# that the columns are ordered the same as in the table
# definition.
sub loadRow {
    my ( $this, $line, $rowmaker ) = @_;

    my $row = $rowmaker->new();
    foreach my $fld ( @{ $this->{fields} } ) {
        my $val = $line->{$fld};
        $row->set( $fld, $val );
    }
    return $row;
}

1;
