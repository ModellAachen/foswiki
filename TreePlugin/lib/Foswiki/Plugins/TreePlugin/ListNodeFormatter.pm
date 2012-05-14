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

package Foswiki::Plugins::TreePlugin::ListNodeFormatter;
use Foswiki::Plugins::TreePlugin::NodeFormatter;
our @ISA = qw( Foswiki::Plugins::TreePlugin::NodeFormatter );

#  class to format the nodes in a tree in a HTML list manner
# for example: Node1<ul><li>Child1</li><li>Child2</li></ul>
#
# each node is appended with its children
#
# node  nodeBeg
#         childBeg child childEnd
#         childBeg child childEnd
#         childBeg child childEnd
#         ....
#       endBeg
#

# Constructor
sub new {
    my ( $class, $nodeBeg, $nodeEnd, $childBeg, $childEnd ) = @_;
    my $this = {};
    $this->{_data} = ();
    bless( $this, $class );
    $this->data( "nodeBeg",  $nodeBeg  || "\n<ul> " );
    $this->data( "nodeEnd",  $nodeEnd  || " \n</ul>" );
    $this->data( "childBeg", $childBeg || "\n<li> " );
    $this->data( "childEnd", $childEnd || " </li>" );
    return $this;
}

sub initNode { }

# the data, set/get data hash values
sub data {
    my $this = shift;
    my $key  = shift;
    return $this->{_data} unless ($key);
    my $val = shift;
    return $this->{_data}->{$key} unless ($val);
    return $this->{_data}->{$key} = $val;
}

sub formatNode {
    my ( $this, $node, $count, $level ) = @_;

    return "" if ( !$this->isInsideLevelBounds($level) );

    my $link  = &Foswiki::Plugins::TreePlugin::getLinkName($node);
    my $label = $node->data('topic');
    return "[[$link][$label]]";
}

sub formatBranch {
    my ( $this, $node, $childrenText, $count, $level ) = @_;

    return if ( $childrenText eq '' );

    return $this->formatNode( $node, $count, $level ) unless $childrenText;

    # $childrenText not empty
    my $insideLevelBounds = $this->isOneOffLevelBounds($level);
    my $formattedText = $this->formatNode( $node, $count, $level );
    return ($insideLevelBounds)
      ? $formattedText . $this->closeBranch($childrenText)
      : $formattedText . $childrenText;
}

sub closeBranch {
    my ( $this, $text ) = @_;

    return $this->data("nodeBeg") . $text . $this->data("nodeEnd");

}

sub formatChild {
    my ( $this, $node, $count, $level ) = @_;

    my $res = $node->toHTMLFormat( $this, $count, $level );
    return "" if ( $res eq '' );

    my $withinBounds = $this->isInsideLevelBounds($level);

    my $formattedText = "";
    $formattedText .= $this->data("childBeg") if ($withinBounds);
    $formattedText .= $res;
    $formattedText .= $this->data("childEnd") if ($withinBounds);
    return $formattedText;
}

1;

