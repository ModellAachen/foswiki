#
# Copyright (C) Motorola 2001 - All rights reserved
#
# Foswiki extension that adds tags for the generation of tables of contents.
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
use strict;
use integer;

# Class of target anchors. Anchors are typed.
package Foswiki::Plugins::TocPlugin::Anchor;

# Constructor
sub new {
    my ( $class, $type, $id, $text, $visible ) = @_;
    my $this = {};
    $this->{ISA}        = "Anchor";
    $this->{TYPE}       = $type;
    $this->{UID}        = $id;
    $this->{PRINTABLE}  = undef;
    $this->{TEXT}       = $text;
    $this->{IS_VISIBLE} = $visible;
    return bless( $this, $class );
}

# PUBLIC the type of this anchor
sub type {
    my $this = shift;
    if (@_) { $this->{TYPE} = shift; }
    return $this->{TYPE};
}

# PUBLIC the expanded section number
sub uid {
    my $this = shift;
    if (@_) { $this->{UID} = shift; }
    return $this->{UID};
}

# PUBLIC printable form of this anchor. UID is not defined.
sub printable {
    my $this = shift;
    if (@_) { $this->{PRINTABLE} = shift; }
    return $this->{PRINTABLE};
}

# PUBLIC the text associated with this anchor
sub text {
    my $this = shift;
    if (@_) { $this->{TEXT} = shift; }
    return $this->{TEXT};
}

# PUBLIC is this anchor to be text-rendered, or is it invisible?
sub visible {
    my $this = shift;
    if (@_) { $this->{IS_VISIBLE} = shift; }
    return $this->{IS_VISIBLE};
}

# PROTECTED generate the text associated with the identity of this
# section e.g. "Section 5.6"
sub genIdentText {
    my $this = shift;
    if ( defined( $this->{PRINTABLE} ) ) {
        return $this->{PRINTABLE};
    }
    return $this->{UID};
}

# Escape wiki words from the text
sub unWikiWord {
    my ( $this, $text ) = @_;
    $text =~ s/(\s)([A-Z]+[a-z]+[A-Z])/$1<nop>$2/go;
    $text =~ s/\[\[([a-z0-9 ]+)\]\]/$1/gio;
    return $text;
}

# Generate the unique tag in this file
sub genTag {
    my $this = shift;
    return $this->type() . "_" . $this->uid();
}

# PROTECTED generate the <A href=> part of a jump tag
sub genReferenceA {
    my ( $this, $relativeTo ) = @_;
    $relativeTo = "" unless defined($relativeTo);
    return "<A href=\"" . $relativeTo . "#" . $this->genTag() . "\">";
}

# PROTECTED generate the <A name=> part of a target
sub genTargetA {
    my $this = shift;
    return "<A name=\"" . $this->genTag() . "\">";
}

# PUBLIC Generate HTML to anchor the link
sub generateTarget {
    my $this = shift;
    my $text = " ";
    if ( $this->visible() ) {
        $text =
          $this->unWikiWord( $this->genIdentText() . " " . $this->text() );
    }
    return $this->genTargetA() . "</A>" . $text;
}

# PUBLIC Generate HTML to target the link
sub generateReference {
    my ( $this, $relativeTo ) = @_;

    # Escape out wiki words in the text
    my $text = $this->genIdentText() . " " . $this->text();
    return
      $this->genReferenceA($relativeTo) . $this->unWikiWord($text) . "</A>";
}

# Generate expanded HTML for printing
sub toPrint {
}

# Generate a string representation for debugging
sub toString {
    my ( $this, $nohtml ) = @_;
    my $res =
        $this->{ISA} 
      . "(type="
      . $this->type()
      . " uid='"
      . $this->uid()
      . "' text='"
      . $this->text() . "'";
    $res .= " printable='" . $this->printable() . "'"
      if ( $this->printable() );
    $res = $res . " invisible" if !$this->visible();
    return $res . ")";
}

1;
