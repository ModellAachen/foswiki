# See bottom of file for license and copyright information

package ChartPluginTests;

use strict;
use warnings;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );
use Error ':try';

use Foswiki;
use Foswiki::Plugins::ChartPlugin;
use Foswiki::Plugins::ChartPlugin::Chart;
use Foswiki::Plugins::ChartPlugin::Table;

use CGI;

our $data = <<STUFF;
%TABLE{name="one"}%
| 111 | 112 | 113 | 114 |
| 121 | 122 | 123 | 124 |
| 131 | 132 | 133 | 134 |

%TABLE{name="two"}%
| 211 | 212 | 213 |
| 221 | 222 | 223 |
| 231 | 232 | 233 |
| 241 | 242 | 243 |
STUFF

sub test_table_basics {
    my $this = shift;

    my $t = Foswiki::Plugins::ChartPlugin::Table->new($data);
    $this->assert( $t->checkTableExists("one") );
    $this->assert( $t->checkTableExists("two") );
    $this->assert( !$t->checkTableExists("zero") );

    $this->assert_num_equals( 3, $t->getNumRowsInTable("one") );
    $this->assert_num_equals( 4, $t->getNumRowsInTable("two") );
    $this->assert_num_equals( 4, $t->getNumColsInTable("one") );
    $this->assert_num_equals( 3, $t->getNumColsInTable("two") );
}

sub test_getTableRanges {
    my $this = shift;
    my $t    = Foswiki::Plugins::ChartPlugin::Table->new($data);

    my @r = $t->getTableRanges( "one", "R1:C1..R3:C4" );
    $this->assert_deep_equals(
        [
            [
                {
                    left   => 0,
                    right  => 3,
                    top    => 0,
                    bottom => 2
                }
            ]
        ],
        \@r
    );
    @r = $t->getTableRanges( "one", "R3:C4..R1:C1" );
    $this->assert_deep_equals(
        [
            [
                {
                    left   => 3,
                    right  => 0,
                    top    => 2,
                    bottom => 0
                }
            ]
        ],
        \@r
    );
    @r = $t->getTableRanges( "one", "R1:C1..R3:C2+R3:C4..R1:C3" );
    $this->assert_deep_equals(
        [
            [
                {
                    left   => 0,
                    right  => 1,
                    top    => 0,
                    bottom => 2
                },
                {
                    left   => 3,
                    right  => 2,
                    top    => 2,
                    bottom => 0
                }
            ]
        ],
        \@r
    );
}

sub test_getData {
    my $this = shift;
    my $t    = Foswiki::Plugins::ChartPlugin::Table->new($data);

    # Simple range
    my @r = $t->getData( "one", "R1:C1..R3:C4", 0 );
    $this->assert_deep_equals(
        [
            [ 111, 112, 113, 114 ],
            [ 121, 122, 123, 124 ],
            [ 131, 132, 133, 134 ]
        ],
        \@r
    );

    # Two ranges - continuous data
    @r = $t->getData( "one", "R1:C1..R3:C2+R1:C3..R3:C4", 0 );
    $this->assert_deep_equals(
        [
            [ 111, 112, 113, 114 ],
            [ 121, 122, 123, 124 ],
            [ 131, 132, 133, 134 ]
        ],
        \@r
    );

    # Two ranges - discontinuous data
    @r = $t->getData( "one", "R1:C1..R3:C2+R1:C4..R3:C4", 0 );
    $this->assert_deep_equals(
        [ [ 111, 112, 114 ], [ 121, 122, 124 ], [ 131, 132, 134 ] ], \@r );

    # Two ranges, reversed data
    @r = $t->getData( "one", "R1:C1..R3:C2+R1:C4..R3:C3", 0 );
    $this->assert_deep_equals(
        [
            [ 111, 112, 114, 113 ],
            [ 121, 122, 124, 123 ],
            [ 131, 132, 134, 133 ]
        ],
        \@r
    );

    # Two ranges, transposed second range
    @r = $t->getData( "one", "R1:C1..R3:C2+R3:C4..R1:C3", 0 );
    $this->assert_deep_equals(
        [
            [ 111, 112, 134, 133 ],
            [ 121, 122, 124, 123 ],
            [ 131, 132, 114, 113 ]
        ],
        \@r
    );

    # Transposed simple range
    @r = $t->getData( "one", "R1:C1..R3:C4", 1 );
    $this->assert_deep_equals(
        [
            [ 111, 121, 131 ],
            [ 112, 122, 132 ],
            [ 113, 123, 133 ],
            [ 114, 124, 134 ]
        ],
        \@r
    );
}

sub test_transpose {
    my $this = shift;
    my $untx =
      [ [ 111, 112, 113, 114 ], [ 121, 122, 123, 124 ],
        [ 131, 132, 133, 134 ] ];
    my $tx = [
        [ 111, 121, 131 ],
        [ 112, 122, 132 ],
        [ 113, 123, 133 ],
        [ 114, 124, 134 ]
    ];
    $this->assert_deep_equals( $tx,
        [ Foswiki::Plugins::ChartPlugin::Table::transpose(@$untx) ] );
}

sub test_getRowColumnCount {
    my $this = shift;
    my $t    = Foswiki::Plugins::ChartPlugin::Table->new($data);

    # Simple range
    my ( $r, $c ) = $t->getRowColumnCount( "one", "R1:C1..R3:C4" );
    $this->assert_num_equals( 3, $r );
    $this->assert_num_equals( 4, $c );

    ( $r, $c ) = $t->getRowColumnCount( "two", "R1:C1..R4:C3" );
    $this->assert_num_equals( 4, $r );
    $this->assert_num_equals( 3, $c );

    # Two ranges - continuous data
    ( $r, $c ) = $t->getRowColumnCount( "one", "R1:C1..R3:C2+R1:C3..R3:C4", 0 );
    $this->assert_num_equals( 3, $r );
    $this->assert_num_equals( 4, $c );

    # Two ranges - discontinuous data
    ( $r, $c ) = $t->getRowColumnCount( "one", "R1:C1..R3:C2+R1:C4..R3:C4", 0 );
    $this->assert_num_equals( 3, $r );
    $this->assert_num_equals( 3, $c );

    # Two ranges, reversed data
    ( $r, $c ) = $t->getRowColumnCount( "one", "R1:C1..R3:C2+R1:C4..R3:C3", 0 );
    $this->assert_num_equals( 3, $r );
    $this->assert_num_equals( 4, $c );

    # Two ranges, transposed second range
    ( $r, $c ) = $t->getRowColumnCount( "one", "R1:C1..R3:C2+R3:C4..R1:C3", 0 );
    $this->assert_num_equals( 3, $r );
    $this->assert_num_equals( 4, $c );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
