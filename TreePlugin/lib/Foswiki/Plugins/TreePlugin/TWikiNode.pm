#
# Copyright (C) XXXXX 2001 - All rights reserved
#
# TWiki extension XXXXX
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

package Foswiki::Plugins::TreePlugin::TWikiNode;
use Foswiki::Plugins::TreePlugin::Node;
our @ISA = qw( Foswiki::Plugins::TreePlugin::Node );

use strict;

# Constructor
sub new {
    my ( $class, $name ) = @_;
    my $this = $class->SUPER::new();
    $this->name($name);
    return bless( $this, $class );
}

########
#sub data {
#    my $this = shift;
#    my $key = shift;
#    return $this->{_data} unless ($key);
#    my $val = shift;
#    return $this->{_data}->{$key} unless ($val);
#    return $this->{_data}->{$key} = $val;
#}

sub data {
    my $this = shift;
    my $key  = shift;
    return "" unless ($key);
    my $val = shift;
    return $this->{"_$key"} unless ($val);
    return $this->{"_$key"} = $val;
}

########
# need to move all these data accessors
# into one hash like data above (which fails in CGI mode for osme reason)

# PUBLIC the , set/get
sub onum {
    my $this = shift;
    if (@_) { $this->{_onum} = shift; }
    return $this->{_onum};    # added to give root an onum
}

##################

# takes a NodeFormatter object and applies its methods to format this
#	node
#
# call order:

sub toHTMLFormat {
    my $this      = shift;
    my $formatter = shift;        # should we check for correct class?
    my $num       = shift || 0;
    my $level     = shift || 0;

#&Foswiki::Func::writeDebug("toHTMLFormat: ".$this->name()) if $Foswiki::Plugins::TreePlugin::debug;

    #This make sure we don't render a node more than once
    #thus preventing endless loop when dealing with inconsitant relationship
    if ( $this->{_rendered} ) {
        return "";
    }

    #Mark this node as being rendered
    $this->{_rendered} = 1;

    $formatter->initNode( $this, $num, $level );

    my $childrenText = "";
    if ( scalar( @{ $this->children() } ) ) {
        my $count = 0;
        foreach my $node ( @{ $this->children() } ) {

#SL: Append delimiter
#$childrenText .= "," unless ($count==0 && $level==0 && $this->name() eq ' '); #BAD: Test to prevent Web tree to append delimiter before first item
            $childrenText .= $formatter->separator();

            # accumulate childrens' format
            $node->data( "count", $count++ );

            # remember this node's sibling order
            $childrenText .=
              $formatter->formatChild( $node, $count, $level + 1 );
        }
    }
    return ($childrenText)
      ? $formatter->formatBranch( $this, $childrenText, $num, $level )
      : $formatter->formatNode( $this, $num, $level );
}

1;

