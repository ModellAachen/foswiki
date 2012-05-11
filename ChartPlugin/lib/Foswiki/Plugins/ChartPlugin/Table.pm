# ChartPlugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004-2006 Peter Thoeny, Peter@Thoeny.org
# Plugin written by http://TWiki.org/cgi-bin/view/Main/TaitCyrus
# Copyright (C) 2008-2011 Foswiki Contributors
#
# For licensing info read LICENSE file in the Foswiki root.
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
# As per the GPL, removal of this notice is prohibited.
#
# =========================
#
# This file contains routines for dealing with Foswiki tables.
#
# Access is via object oriented Perl and is as follows.
#
# Constructor
#    new($topicContents)        - Create a 'Table' object from topic contents
# Getters/Setters
#    checkTableExists($name)        - Check if the specified table name exists
#    getTable($num)                - Return the specified table
#    getTableInfo                - DEBUG purposes only.  Print out contents
#                                      of tables in table object
#    getRow($row,$c1,$c2)        - Return the data at the specified row
#                                      starting at column 1 and ending at column 2
#    getData($tblnum,$range)        - Return the data at the specified range.
#                                      If a single row or single column, then
#                                      return the data.  If multiple
#                                      rows/columns, then return the data in row
#                                      format.
#    getRowColumnCount($range)        - Return the number of rows/columns
#                                      specified in the range

# =========================
package Foswiki::Plugins::ChartPlugin::Table;

use strict;

sub new {
    my ( $class, $topicContents ) = @_;
    my $this = {};
    bless $this, $class;
    $this->_parseOutTables($topicContents);
    return $this;
}

sub getNumberOfTables { my ($this) = @_; return $$this{NUM_TABLES}; }

# Check to make sure that the specified table (either by name or number)
# exists.
sub checkTableExists {
    my ( $this, $tableName ) = @_;
    return 1 if defined( $$this{"TABLE_$tableName"} );
    return 0;
}

sub getTable {
    my ( $this, $tableName ) = @_;
    my $table = $$this{"TABLE_$tableName"};
    return @$table if defined($table);
    return ();
}

sub getNumRowsInTable {
    my ( $this, $tableName ) = @_;
    my $table = $$this{"TABLE_$tableName"};
    my $nRows = 0;
    $nRows = @$table if defined($table);
    return $nRows;
}

sub getNumColsInTable {
    my ( $this, $tableName ) = @_;
    my $nCols = $$this{"NCOLS_$tableName"} || 0;
    return $nCols;
}

# Parse a spreadsheet-style range specification to get an array
# of normalised data ranges
sub getTableRanges {
    my ( $this, $tableName, $str ) = @_;

    my @sets = ();
    foreach my $dataSet ( split( /\s*,\s*/, $str ) ) {
        my @set = ();
        foreach my $range ( split( /\s*\+\s*/, $dataSet ) ) {
            if ( $range =~ /^R(\d+)\:C(\d+)\s*(\.\.+\s*R(\d+)\:C(\d+))?$/ ) {
                my $r1 = $1 - 1;
                my $c1 = $2 - 1;
                my $r2 = $4 ? ( $4 - 1 ) : $r1;
                my $c2 = $5 ? ( $5 - 1 ) : $c1;

                # trim range to actual table size
                my $maxRow = $this->getNumRowsInTable($tableName) - 1;
                my $maxCol = $this->getNumColsInTable($tableName) - 1;
                $r1 = $maxRow if ( $r1 > $maxRow );
                $c1 = $maxCol if ( $c1 > $maxCol );
                $r2 = $maxRow if ( $r2 > $maxRow );
                $c2 = $maxCol if ( $c2 > $maxCol );
                push( @set,
                    { top => $r1, left => $c1, bottom => $r2, right => $c2 } );
            }
        }
        push( @sets, \@set ) if scalar(@set);
    }
    return @sets;
}

# This routine is only intended for debug purposes.  All it does is to
# output the contents of the table object to the Foswiki debug.txt file.
sub getTableInfo {
    my ($this) = @_;

    foreach my $table ( 1 .. $this->getNumberOfTables() ) {
        my @t = $this->getTable($table);
        &Foswiki::Func::writeDebug(
            "- Foswiki::Plugins::ChartPlugin::TABLE[$table][@t]");
        foreach my $row (@t) {
            my @col = @$row;
            &Foswiki::Func::writeDebug(
                "- Foswiki::Plugins::ChartPlugin::ROW[$row][@col]");
        }
    }
}

# The guts of this routine was initially copied from SpreadSheetPlugin.pm,
# but has been modified to support the functionality needed by the
# ChartPlugin.  A major change is supporting the notion of multiple tables
# in a topic page and allowing the user to reference the specific table
# they want.
#
# This routine basically returns an array of hashes where each hash
# contains the information for a single table.  Thus the first hash in the
# array represents the first table found on the topic page, the second hash
# in the array represents the second table found on the topic page, etc.
sub _parseOutTables {
    my ( $this, $topic ) = @_;
    my $tableNum  = 1;     # Index in the same way users will ref tables
    my $tableName = "";    # If a named table.
    my @tableMatrix;       # Currently parsed table.
    my $nCols = 0;         # Number of columns in current table

    my $result      = "";
    my $insidePRE   = 0;
    my $insideTABLE = 0;
    my $line        = "";
    my @row         = ();

    $topic =~ s/\r//go;
    $topic =~ s/\\\n//go;    # Join lines ending in "\"
    $topic .= '\n';    # Make sure we also discover a table at bottom of topic
    foreach ( split( /\n/, $topic ) ) {

        # change state:
        m|<pre>|i       && ( $insidePRE = 1 );
        m|<verbatim>|i  && ( $insidePRE = 1 );
        m|</pre>|i      && ( $insidePRE = 0 );
        m|</verbatim>|i && ( $insidePRE = 0 );

        if ( !($insidePRE) ) {

            if (/%TABLE{.*name="(.*?)".*}%/) {
                $tableName = $1;
            }
            if (/^\s*\|.*\|\s*$/) {

                # inside | table |
                $insideTABLE = 1;
                $line        = $_;
                $line =~ s/^(\s*\|)(.*)\|\s*$/$2/o;    # Remove starting '|'
                @row = split( /\|/o, $line, -1 );
                _trim( \@row );
                push( @tableMatrix, [@row] );
                $nCols = @row if ( @row > $nCols );

            }
            else {

                # outside | table |
                if ($insideTABLE) {

                    # We were inside a table and are now outside of it so
                    # save the table info into the Table object.
                    $insideTABLE = 0;
                    if ( @tableMatrix != 0 ) {

                        # Save the table via its table number
                        $$this{"TABLE_$tableNum"} = [@tableMatrix];
                        $$this{"NCOLS_$tableNum"} = $nCols;

                        # Deal with a 'named' table also.
                        if ($tableName) {
                            $$this{"TABLE_$tableName"} = [@tableMatrix];
                            $$this{"NCOLS_$tableName"} = $nCols;
                        }
                        $tableNum++;
                        $tableName = "";
                    }
                    undef @tableMatrix;    # reset table matrix
                    $nCols = 0;
                }
            }
        }
        $result .= "$_\n";
    }
    $$this{NUM_TABLES} = $tableNum;
}

# Trim any leading and trailing white space and/or '*'.
sub _trim {
    my ($totrim) = @_;
    for my $element (@$totrim) {
        $element =~ s/^[\s\*]+//;    # Strip of leading white/*
        $element =~ s/[\s\*]+$//;    # Strip of trailing white/*
    }
}

# Given a table name and a range of Foswiki table data (in
# SpreadSheetPlugin format), return the specified data.  Assume that the
# data is row oriented unless only a single column is specified.
# NOTE: All data is returned as a 2 dimensional array even in the case of a
# single row/column of data. Discontinuous ranges are collapsed into
# contiguous rows, left aligned and zero-padded i.e.
# R1:C1..R2:C2,R6:C3..R7:C4 gets returned as:
# R1C1 R1C2 0
# R2C1 R2C2 0
# R6C3 R6C4 R6C5
# R7C3 R7C5 R7C5
sub getData {
    my ( $this, $tableName, $spreadSheetSyntax, $transpose ) = @_;
    my @selectedTable = $this->getTable($tableName);
    my @ranges = $this->getTableRanges( $tableName, $spreadSheetSyntax );

    my @rows    = ();
    my $rowbase = 0;

    foreach my $set (@ranges) {
        my $rh = 0;    # Height of this dataset, in rows

        # For each range within the dataset
        foreach my $range (@$set) {

            # $out_* are the control vars for the outer loop
            # $in_* are the control vars for the inner loop
            my ( $out_l, $out_h, $out_i, $in_l, $in_h, $in_i );
            if ($transpose) {
                ( $out_l, $out_h, $in_l, $in_h ) = (
                    $range->{left}, $range->{right},
                    $range->{top},  $range->{bottom}
                );
            }
            else {
                ( $out_l, $out_h, $in_l, $in_h ) = (
                    $range->{top},  $range->{bottom},
                    $range->{left}, $range->{right}
                );
            }
            $out_i = ( $out_l > $out_h ? -1 : 1 );
            $in_i  = ( $in_l > $in_h   ? -1 : 1 );

            my $rs = 0;
            for ( my $out = $out_l ; $out != $out_h + $out_i ; $out += $out_i )
            {
                for ( my $in = $in_l ; $in != $in_h + $in_i ; $in += $in_i ) {
                    my $value = (
                          $transpose
                        ? $selectedTable[$in][$out]
                        : $selectedTable[$out][$in]
                    );
                    if ( defined $value ) {
                        push( @{ $rows[ $rowbase + $rs ] }, $value );
                    }
                }
                $rs++;
            }

            # Does this range contribute the most rows to the dataset?
            $rh = $rs if ( $rs > $rh );
        }

        # Start the next dataset on a new row
        $rowbase += $rh;
    }

    # Remove empty rows
    my @result;
    foreach my $row (@rows) {
        push( @result, $row ) if $row && scalar(@$row);
    }

    return @result;
}

# Transpose an array
sub transpose {
    my @a = @_;
    my @b;
    foreach my $row (@a) {
        my $r = 0;
        foreach my $col (@$row) {
            push( @{ $b[ $r++ ] }, $col );
        }
    }
    return @b;
}

sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Given a range of Foswiki table data (in SpreadSheetPlugin format), return
# an array containing the number of rows/columns specified by the range.
sub getRowColumnCount {
    my ( $this, $tableName, $spreadSheetSyntax ) = @_;
    my @ranges = $this->getTableRanges( $tableName, $spreadSheetSyntax );
    my $rows   = 0;
    my $cols   = 0;
    foreach my $set (@ranges) {
        my $r = 0;
        my $c = 0;
        foreach my $range (@$set) {
            $r = max( $r, abs( $range->{bottom} - $range->{top} ) + 1 );
            $c += abs( $range->{right} - $range->{left} ) + 1;
        }
        $rows += $r;
        $cols = $c if $c > $cols;
    }
    return ( $rows, $cols );
}

1;
