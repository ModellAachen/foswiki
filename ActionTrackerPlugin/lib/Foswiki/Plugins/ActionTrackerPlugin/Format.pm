# See bottom of file for license and copyright information

# Object that represents a header and fields format
# This is where all formatting should be done; there should
# be no HTML tags anywhere else in the code!
# Formats objects that implement the following contract:
# 1. They provide a "getType" method, that returns a type
#    structure as per Action.pm
# 2. For each of the types they provide a _format_$type
#    method that returns the string representation of the type.
# 3. For each of their fields that require special formatting
#    they provide a _format_$field method that returns a string
#    representation of the field. Field methods override type
#    methods. The function must return a tuple of ( text, colour ).
#    The colour may be undefined.
package Foswiki::Plugins::ActionTrackerPlugin::Format;

use strict;
use integer;

use Foswiki::Func ();

# PUBLIC Constructor
# $header is the format of the HTML table header representation
# $fields is the format of the HTML table body representation
# $textform is the format of the text representation
# $changeFields is the comma-separated list of fields to detect changes
# in.
# $orient is the orientation of generated tables; "rows" gives
# data in rows, anything else gives data in columns.
sub new {
    my ( $class, $header, $fields, $footer, $orient, $textform, $changeFields ) = @_;

    my $this = {};
    $header ||= '';
    $header =~ s/^\s*\|//so;
    $header =~ s/\|\s*$//so;
    my @heads = split( /\|/, $header );

    $fields ||= '';
    $fields =~ s/^\s*\|//so;
    $fields =~ s/\|\s*$//so;
    my @bodies = split( /\|/, $fields );
    
    $footer ||= '';
    $footer =~ s/^\s*\|//so;
    $footer =~ s/\|\s*$//so;
    my @foots = split( /\|/, $footer );

    while ( $#bodies < $#heads ) {
        push( @bodies, "&nbsp;" );
    }

    while ( $#heads < $#bodies ) {
        push( @heads, "&nbsp;" );
    }
    
   # while ( $#foots < $#bodies ) {
   #     push( @heads, "&nbsp;" );
   # }

    @{ $this->{HEADINGS} } = @heads;
    @{ $this->{FIELDS} }   = @bodies;
    @{ $this->{FOOTERS} }   = @foots;

    $this->{TEXTFORM} = $textform;

    if ($changeFields) {
        $changeFields =~ s/\s//go;
        $changeFields =~ s/\$//go;
        @{ $this->{CHANGEFIELDS} } = split( /,\s*/, $changeFields );
    }

    if ( $orient && $orient eq "rows" ) {
        $this->{ORIENTATION} = "rows";
    }
    else {
        $this->{ORIENTATION} = "cols";
    }

    return bless( $this, $class );
}

# PUBLIC return the headers in a format suitable for feeding
# back to new.
sub getHeaders {
    my $this = shift;
    return "|" . join( "|", @{ $this->{HEADINGS} } ) . "|";
}

# PUBLIC return the footers in a format suitable for feeding
# back to new.
sub getFooters {
    my $this = shift;
    return "|" . join( "|", @{ $this->{FOOTERS} } ) . "|";
}

# PUBLIC return the fields in a format suitable for feeding
# back to new.
sub getFields {
    my $this = shift;
    return "|" . join( "|", @{ $this->{FIELDS} } ) . "|";
}

# PUBLIC get the text form of the format
sub getTextForm {
    my $this = shift;
    return $this->{TEXTFORM};
}

# PUBLIC get the change fields as a comma-separated list
sub getChangeFields {
    my $this = shift;
    if ( defined( $this->{CHANGEFIELDS} ) ) {
        return join( ",", @{ $this->{CHANGEFIELDS} } );
    }
    return "";
}

# PUBLIC get the table orientation
sub getOrientation {
    my $this = shift;
    return $this->{ORIENTATION};
}

# PUBLIC return the format as attributes
sub stringify() {
    my $this         = shift;
    my $hdrs         = $this->getHeaders();
    my $flds         = $this->getFields();
    my $tform        = $this->getTextForm();
    my $changeFields = $this->getChangeFields();
    my $orient       = $this->getOrientation();
    return
        "header=\"$hdrs\" format=\"$flds\" "
      . "textform=\"$tform\" changefields=\"$changeFields\" "
      . "orientation=\"$orient\"";
}

# PRIVATE expand a var using one of:
# a function called $object->_format_$var()
# the field $object->{$var}
# or return the name of the var
# The function returns a tuple of ( text, colour ). The value 0 is
# treated as the default colour.
sub _expandVar {
    my $object = shift;
    my $vbl    = shift;
    my $args   = shift;
    my $asHTML = shift;
    my $fn     = "_formatField_$vbl";
    if ( $object->can($fn) ) {

        # special format for this field
        return $object->$fn( $args, $asHTML, @_ );
    }
    my $type = $object->getType($vbl);
    if ($type) {
        my $typename = $type->{type};
        $fn = "_formatType_$typename";
        if ( $object->can($fn) ) {

            # special format for this type
            return $object->$fn( $vbl, $args, $asHTML, @_ );
        }
    }
    if ( defined( $object->{$vbl} ) && !defined($args) ) {

        # just expand as a string
        return $object->{$vbl};
    }

    if ($asHTML) {
        return '&nbsp;';
    }
    else {
        return '';
    }
}

# PUBLIC format a list of actions into a table
sub formatHTMLTable {
    my $this      = shift;
    my $data      = shift;
    my $jump      = shift; # 'name' for plain text, or 'href' for a link
    my $class     = shift;
    my $a         = {};
    $a->{class} = $class if $class;
    my $i;
    my @rows;

    # make a 2D array of cells
    foreach my $object (@$data) {
        my $anchored = ( $jump ne "name" );
        my @cols;
        foreach $i ( @{ $this->{FIELDS} } ) {
            my $c;
            my $entry = $i;
            $entry = Foswiki::Func::decodeFormatTokens($entry);
            $entry =~ s/\$(\w+)(?:\((.*?)\))?/
              _expandVar( $object, $1, $2, 1, $jump )/ges;
            if ( !$anchored ) {
                $entry = CGI::a( { name => $object->getAnchor() } ) . $entry;
                $anchored = 1;
            }
            $entry = CGI::td($entry);
            $entry ||= '&nbsp;';
            push @cols, $entry;
        }
        push @rows, \@cols;
    }

    return $this->_generateHTMLTable( \@rows, $class );
}

# PRIVATE generate an HTML table from a 2D-array of rows and
# an optional list of anchors, one for each row. The anchors
# are only useful if the table is oriented as rows.
sub _generateHTMLTable {
    my ( $this, $rows, $class ) = @_;
    $class ||= 'atpSearch';
    $class .= ' atpOrient'.ucfirst($this->{ORIENTATION});
    my $text = CGI::start_table( { class => $class } );
    my $i;

    if ( $this->{ORIENTATION} eq 'rows' ) {
        for ( $i = 0 ; $i <= $#{ $this->{HEADINGS} } ; $i++ ) {
            my $head = ${ $this->{HEADINGS} }[$i];
            my $row = CGI::th($head );
            foreach my $col (@$rows) {
                my $datum = @$col[$i];
                $row .= $datum;
            }
            $text .= CGI::Tr($row) . "\n";
        }
    }
    else {
        my $row = '';
        foreach $i ( @{ $this->{HEADINGS} } ) {
            $row .= CGI::th($i);
        }
        $text .= CGI::Tr($row);
        foreach my $r (@$rows) {
            $text .= CGI::Tr( join( '', @$r ) );
        }
    }
    $text .= CGI::end_table();

    return $text;
}

# PUBLIC format a list of actions into a table
sub formatStringTable {
    my $this = shift;
    my $data = shift;
    my $text = '';
    foreach my $row (@$data) {
        my $fmt = $this->{TEXTFORM} || '';
        $fmt = Foswiki::Func::decodeFormatTokens($fmt);
        $fmt =~ s/\$(\w+\b)(?:\((.*?)\))?/
          _expandVar( $row, $1, $2, 0, @_ )/geos;
        $text .= $fmt . "\n";
    }
    return $text;
}

# PUBLIC Get the changes in the selected change fields between
# the old object and the new object.
sub formatChangesAsHTML {
    my ( $this, $old, $new ) = @_;
    my $tbl = "";
    my $a = { class => 'atpChanges' };
    foreach my $field ( @{ $this->{CHANGEFIELDS} } ) {
        my $row = '';
        if ( defined( $old->{$field} ) && defined( $new->{$field} ) ) {
            my $oldval = _expandVar( $old, $field, undef, 1 );
            my $newval = _expandVar( $new, $field, undef, 1 );
            if ( $oldval ne $newval ) {
                $row =
                    CGI::td( $a, $field )
                  . CGI::td( $a, $oldval )
                  . CGI::td( $a, $newval );
            }
        }
        elsif ( defined( $old->{$field} ) ) {
            my $oldval = _expandVar( $old, $field, undef, 1 );
            $row =
                CGI::td( $a, $field )
              . CGI::td( $a, $oldval )
              . CGI::td( $a, ' *removed* ' );
        }
        elsif ( defined( $new->{$field} ) ) {
            my $newval = _expandVar( $new, $field, undef, 1 );
            $row =
                CGI::td( $a, $field )
              . CGI::td( $a, ' *missing* ' )
              . CGI::td( $a, $newval );
        }
        $tbl .= CGI::Tr( $a, $row ) if $row;
    }
    if ( $tbl ne "" ) {
        return CGI::start_table($a)
          . CGI::Tr( $a,
                CGI::th( $a, 'Attribute' )
              . CGI::th( $a, 'Old' )
              . CGI::th( $a, 'New' )
              . $tbl
              . CGI::end_table() );
    }
    return $tbl;
}

# PUBLIC Get the changes in the change fields between the old object and
# the new object.
sub formatChangesAsString {
    my ( $this, $old, $new ) = @_;
    my $tbl = "";
    foreach my $field ( @{ $this->{CHANGEFIELDS} } ) {
        if ( defined( $old->{$field} ) && defined( $new->{$field} ) ) {
            my $oldval = _expandVar( $old, $field, undef, 0 );
            my $newval = _expandVar( $new, $field, undef, 0 );
            if ( $oldval ne $newval ) {
                $tbl .=
"\t- Attribute \"$field\" changed, was \"$oldval\", now \"$newval\"\n";
            }
        }
        elsif ( defined( $old->{$field} ) ) {
            my $oldval = _expandVar( $old, $field, undef, 0 );
            $tbl .= "\t- Attribute \"$field\" was \"$oldval\" now removed\n";
        }
        elsif ( defined( $new->{$field} ) ) {
            my $newval = _expandVar( $new, $field, undef, 0 );
            $tbl .= "\t- Attribute \"$field\" added with value \"$newval\"\n";
        }
    }
    return $tbl;
}

# Format the editable fields of $object for editing.
sub formatEditableFields {
    my ( $this, $object, $expanded ) = @_;

    # for each of the fields in EDITFORMAT, create an appropriate
    # parameter.
    my @fields;
    foreach my $col ( @{ $this->{FIELDS} } ) {
        my $entry = $col;
        $entry =~ s/\$(\w+\b)(?:\((.*?)\))?/
          _expandEditField( $this, $object, $1, $2, $expanded )/geos;
        $entry = CGI::td( { class => 'atpEdit' }, $entry );
        push @fields, $entry;
    }
    my @rows;
    push @rows, \@fields;

    return $this->_generateHTMLTable( \@rows, 'atpEdit' );
}

# PRIVATE STATIC fill in variable expansions. If any of the expansions
# returns a non-zero color, then fill in the passed-by-reference color
# variable $col with the value returned.
sub _expandEditField {
    my ( $this, $object, $var, $args, $expanded ) = @_;

    # record the fact that we expanded this field, so it doesn't get
    # generated as a hidden
    $expanded->{$var} = 1;

    if ( $var eq "dollar" ) {
        return "\$";
    }
    elsif ( $var eq "nop" ) {
        return "";
    }
    elsif ( $var eq "n" ) {
        return CGI::br();
    }
    elsif ( $var eq "percnt" ) {
        return "%";
    }
    elsif ( $var eq "quot" ) {
        return "\"";
    }

    return $this->_formatFieldForEdit( $object, $var );
}

# PRIVATE format the given attribute for edit, using values given
# in
sub _formatFieldForEdit {
    my ( $this, $object, $attrname ) = @_;
    my $type = $object->getType($attrname);
    return $attrname unless ( defined($type) );
    my $size = $type->{size};
    if ( $type->{type} eq 'select' ) {
        my $fields = '';
        foreach my $option ( @{ $type->{values} } ) {
            my @extras = ();
            if ( defined( $object->{$attrname} )
                && $object->{$attrname} eq $option )
            {
                push( @extras, selected => "selected" );
            }
            $fields .= CGI::option( { value => $option, @extras }, $option );
        }
        return CGI::Select( { name => $attrname, size => $size }, $fields );
    }
    elsif ( $type->{type} !~ m/noload/ ) {
        my $val     = _expandVar( $object, $attrname, undef, 0 );
        my $content = '';
        my @extras  = ();
        if ( $type->{type} eq 'date' ) {
            $val =~ s/ \(LATE\)//o;
        }
        if ( $type->{type} eq 'date' ) {

            # make sure JSCalendar is there
            eval 'use Foswiki::Contrib::JSCalendarContrib';
            unless ($@) {
                my $dateformat = Foswiki::Func::getPreferencesValue('JSCALENDARCONTRIB_FORMAT') ||
                                 $Foswiki::cfg{JSCalendarContrib}{format} ||
                                 '%e %B %Y';
                @extras = ( id => "date_$attrname" );
                $content = CGI::image_button(
                    -name => 'calendar',
                    -onclick =>
                      "return showCalendar('date_$attrname','$dateformat')",
                    -src => Foswiki::Func::getPubUrlPath() . '/'
                      . $Foswiki::cfg{SystemWebName}
                      . '/JSCalendarContrib/img.gif',
                    -alt   => 'Calendar',
                    -align => 'middle'
                );
            }
        }
        return CGI::textfield(
            {
                name  => $attrname,
                value => $val,
                size  => $size,
                @extras
            }
        ) . $content;
    }
    return $attrname;
}

# PUBLIC generate and return a hidden editable field
sub formatHidden {
    my ( $this, $object, $attrname ) = @_;

    my $v = _expandVar( $object, $attrname, undef, 0 );
    if ( defined($v) ) {
        return CGI::hidden( { name => $attrname, value => $v } );
    }
    return "";
}

1;
__END__
Copyright (C) Motorola 2002 - All rights reserved
Copyright (C) 2004-2011 Crawford Currie http://c-dot.co.uk

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html
