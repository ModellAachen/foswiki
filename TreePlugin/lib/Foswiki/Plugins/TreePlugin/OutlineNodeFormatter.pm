#
# Copyright (C) XXXXXX 2001 - All rights reserved
#
# Foswiki:: extension XXXXX
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

package Foswiki::Plugins::TreePlugin::OutlineNodeFormatter;
use Foswiki::Plugins::TreePlugin::NodeFormatter;
our @ISA = qw( Foswiki::Plugins::TreePlugin::NodeFormatter );

use vars qw($RootOnum $OnumDelim);

$RootOnum =
  " ";    # what outline number we should assign to a web root when printing
$OnumDelim = ".";    # delmitinater between outline numbers (eg, . makes  3.4.4)

# class to format the nodes in a tree in an outline format
# for example: Node1<ul><li>Child1</li><li>Child2</li></ul>
#
# each node is appended with its children
#
#

# Constructor
sub new {
    my ($class) = @_;
    my $this = {};
    bless( $this, $class );
    return $this;
}

sub data {
    my $this = shift;
    my $key  = shift;
    return "" unless ($key);
    my $val = shift;
    return $this->{"_$key"} unless ($val);
    return $this->{"_$key"} = $val;
}

sub initNode {
    my ( $this, $node, $count ) = @_;
    $this->setOutNum( $node, $count );
}

sub setOutNum {
    my ( $this, $node, $count ) = @_;
    my $onum;

    #$count++;
    if ( ref $node->parent() ) {
        $onum = $node->parent()->onum();
        $onum .= $OnumDelim
          if ($onum);    # add delimiter only if there's a real parent outNum
        $onum .= "$count" if ($count);    # add number only if something there
    }
    else {
        $onum = "";
    }
    $node->onum($onum);
}

sub formatOutNum {
    my ( $this, $node ) = @_;
    my $onum = $node->onum();
    return ($onum) ? $onum : $RootOnum;
}

sub formatNode {
    my ( $this, $node, $count, $level ) = @_;

    return "" if ( !$this->isInsideLevelBounds($level) );

    # no formatting applied
    return &Foswiki::Plugins::TreePlugin::getLinkName($node);
}

sub formatBranch {
    my ( $this, $node, $childrenText, $count, $level ) = @_;
    return $this->formatNode( $node, $count, $level ) . $childrenText;
}

sub formatChild {
    my ( $this, $node, $count, $level ) = @_;
    $this->setOutNum( $node, $count )
      if ( !$this->isInsideLevelBounds($level) );
    return $node->toHTMLFormat( $this, $count, $level );
}

sub separator {
    my ($this) = @_;
    return $this->data('separator');
}

1;

