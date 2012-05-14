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

package Foswiki::Plugins::TreePlugin::FormatOutlineNodeFormatter;
use Foswiki::Plugins::TreePlugin::OutlineNodeFormatter;
our @ISA = qw( Foswiki::Plugins::TreePlugin::OutlineNodeFormatter );

use strict;
use warnings;

use Foswiki::Plugins::TreePlugin::FormatHelper
  qw(spaceTopic loopReplaceRefData);

use Foswiki::Func;

# class to format the nodes in a tree in a formatted outline
#

# Constructor
sub new {
    my ( $class, $format ) = @_;
    my $this = {};
    bless( $this, $class );
    $this->data( "format", $format );

    #Foswiki:::Func::writeDebug("format: ".$);

    return $this;
}

###########

# let subclasses override if they want
sub formatLevel { return $_[1]; }    # humans start counting at 1

# let subclasses override if they want
sub formatCount { return $_[1]; }

sub formatNode {
    my ( $this, $node, $count, $level ) = @_;

    return "" if ( !$this->isInsideLevelBounds($level) );

    #my $res = $this->data("format"); #SL: was that
    my $res = $node->data("format");    #SL: we do that now

    my $nodeLinkName = &Foswiki::Plugins::TreePlugin::getLinkName($node);
    return $nodeLinkName unless ($res);

    # Pseudo-variable substitutions
    # We only do pseudo-variable specific to TreePlugin
    # ... in fact pseudo-variable common with SEARCH was already done

    # Make linkable non-wiki-word namesuse strict;
    my $spaceTopic =
      &Foswiki::Plugins::TreePlugin::FormatHelper::spaceTopic(
        $node->data('topic') );
    $res =~ s/\$spacetopic/$spaceTopic/g;

    #$res =~ s/\$topic/$node->name()/geo;
    $res =~ s/\$outnum/$this->formatOutNum($node)/geo;
    $res =~ s/\$count/$this->formatCount($count)/geo;
    $res =~ s/\$level/$this->formatLevel($level)/geo;

#SL: here were some crazy data substitution we've delegating that to the SEARCH itself

#SL: levelprefix allows rendering of bullet list using Foswiki:: syntax thus enabling combination with TreeBrowserPlugin
    if ( defined( $this->data("levelprefix") ) ) {
        my $i = $level;
        while ( $i > 0 ) {
            $res = $this->data("levelprefix") . $res;
            $i--;
        }
    }

    return $res;
}

sub formatBranch {
    my ( $this, $node, $childrenText, $count, $level ) = @_;
    my $res = $this->data("branchformat");

# default if there's no format to do, let superclass handle
#	return $this->SUPER::formatBranch($this, $node, $childrenText, $count, $level)
#		unless ($res);

    # there's a bug with the above do this for now ??
    return $this->formatNode( $node, $count, $level ) . $childrenText
      unless ($res);

    $res =~ s/\$level/$this->formatLevel($level)/geo;
    $res =~ s/\$parent/$this->formatNode($node, $count, $level)/geo;
    $res =~ s/\$children/$childrenText/geo;
    return $res;
}

1;
