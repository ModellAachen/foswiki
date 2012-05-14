#
# Copyright (C) Slava Kozlov 2002 - All rights reserved
#
# Foswiki:: extension  Foswiki::Plugins::TreePlugin::NodeFormatter
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

package Foswiki::Plugins::TreePlugin::NodeFormatter;

=pod

Superclass for node types. Formatting functions are implemented by subclasses.

=cut

sub new { }

sub separator { return ""; }    #no separator by default

sub initNode { _unimplemented( "initNode", @_ ); }

sub formatNode { _unimplemented( "formatNode", @_ ); }

sub formatChild { _unimplemented( "formatChild", @_ ); }

sub formatBranch { _unimplemented( "formatBranch", @_ ); }

sub closeBranch {
    my ( $this, $text ) = @_;
    return $text;
}

sub _unimplemented {
    my $routine = shift;
    my $class   = shift;
    die "$routine not implemented for $class with params ("
      . join( ", ", @_ ) . ")";
}

=pod

Checks if the current level is within bounds set by startlevel and stoplevel.

=cut

sub isInsideLevelBounds {
    my ( $this, $level ) = @_;

    return 1 if not defined $level;

    return 0 if ( $level < $this->data("startlevel") );

    return 0 if ( $level > $this->data("stoplevel") );

    return 1;
}

=pod

Checks if the current level is within one count to bounds set by startlevel and stoplevel. Used to properly close lists.

Might not be the best way to solve this problem.

=cut

sub isOneOffLevelBounds {
    my ( $this, $level ) = @_;

    return 1 if not defined $level;

    return 0 if ( $level < ( $this->data("startlevel") - 1 ) );

    return 0 if ( $level > ( $this->data("stoplevel") + 1 ) );

    return 1;
}

1;
