#
# Copyright (C) Slava Kozlov 2002 - All rights reserved
#
# Foswiki:: extension Foswiki::Plugins::TreePlugin::ImgNodeFormatter
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

package Foswiki::Plugins::TreePlugin::ImgNodeFormatter;
use Foswiki::Plugins::TreePlugin::FormatOutlineNodeFormatter;
our @ISA = qw( Foswiki::Plugins::TreePlugin::FormatOutlineNodeFormatter );

use Foswiki::Plugins::TreePlugin;

#use Foswiki::Func;

# different ways to use this formatting, maybe these should be subclasses?

use constant SINGLE_MODE    => "single";
use constant FOLDER_MODE    => "folder";
use constant THREAD_MODE    => "thread";
use constant THREADEXP_MODE => "threadexp";
use constant DEF_MODE       => THREAD_MODE;

# the default format for image construction
use constant DEF_IMAGEFORMAT => "<img src='\$image' border='0'>";

# the directory where to find relative images
#	(will sub in $installWeb where the plugin was installed, supposedly)
use constant IMG_DIR_TEMPL => "%PUBURL%/\$installWeb/TreePlugin/";

# the $images variable in the format will be replaced by
# the concat of:
#		for im in images /depending on mode/:
#			if im is relative:
#				im = default_image_dir + im
#			imageformat with "$image" replaced by im

# be nice: provide some default images for the different modes
# (note funny Perl syntax!)

use constant DEF_IMAGES => {
    SINGLE_MODE() => "/icons/ball.red.gif",
    FOLDER_MODE() =>
      "white.gif,/icons/generic.gif,/icons/folder.open.gif,/icons/folder.gif",
    THREAD_MODE() => "I.gif,white.gif,T.gif,L.gif",
    THREADEXP_MODE() =>
      "I.gif,white.gif,T.gif,L.gif,oT.gif,oL.gif,pT.gif,pL.gif"
};

# be nice, provide some default formats that work OK

use constant DEF_FORMATS => {
    SINGLE_MODE() => "\$images [[\$topic]]<br>",
    FOLDER_MODE() =>
"<table border='0' cellspacing='0' cellpadding='0'><tr><td nowrap height='35'>\$images</td><td> [[\$web.\$topic][\$topic]]</td></tr></table>",
    THREAD_MODE() =>
"<table border='0' cellspacing='0' cellpadding='0'><tr><td nowrap>\$images</td><td> [[\$web.\$topic][\$topic]] </td></tr></table>",

#		THREAD_MODE()		=> "<table border=0 cellspacing=0 cellpadding=0><tr><td nowrap>\$images</td><td style={font-size:12pt}> \$topic  <span style={font-size:9pt;color:gray}>\$modTime</span></td></tr></table>",
    THREADEXP_MODE() =>
"<table border='0' cellspacing='0' cellpadding='0'><tr><td nowrap>\$images</td><td> [[\$web.\$topic][\$topic]]</td></tr></table>"
};

# class to format the nodes in a tree using images

# Constructor
sub new {
    my ( $class, $mode, $images, $imageformat ) = @_;
    my $this = $class->SUPER::new();
    bless( $this, $class );

    # if given mode is valid and images not provided, grab default images
    if (   $mode eq SINGLE_MODE
        || $mode eq THREAD_MODE
        || $mode eq THREADEXP_MODE
        || $mode eq FOLDER_MODE )
    {
        $images = $images || DEF_IMAGES->{$mode};
    }

    $this->data( "imageformat", $imageformat || DEF_IMAGEFORMAT );
    $this->images( split /,/, ( $images || DEF_IMAGES->{DEF_MODE} ) );

    # figure out the mode from the number of images provided
    unless ($mode) {
        $mode = SINGLE_MODE if ( $this->imagesTotal == 0 );
        push @{ $this->images }, $this->images->[1]
          if ( $this->imagesTotal == 1 ); # copy last image to be in folder mode
        $mode = FOLDER_MODE    if ( $this->imagesTotal == 2 );
        $mode = THREAD_MODE    if ( $this->imagesTotal == 3 );
        $mode = THREADEXP_MODE if ( $this->imagesTotal == 7 );
    }

    # use user-defined mode or calculated mode or just the default
    $mode = $mode || DEF_MODE;
    $this->data( "mode", $mode );

    # get a default format
    $this->data( "format", DEF_FORMATS->{$mode} );

    #Foswiki::Func::writeDebug("format($mode): ", DEF_FORMATS->{$mode});
    return $this;
}

sub formatNode {
    my ( $this, $node, $count, $level ) = @_;

    return "" if ( !$this->isInsideLevelBounds($level) );

    my $sub;
    my $mode = $this->data("mode");

    if ( $mode eq THREAD_MODE || $mode eq THREADEXP_MODE ) {

        # figure out ancestral lineage & sub in approp. images

        my $imagesString = getLasts( $node, $level );

        my ( $a, $b );
        if ( $imagesString ne "" ) {

            # split between ancestry & given node
            ( $a, $b ) = $imagesString =~ m/([01]*)([01])$/o;

            # mode = thread - sub in third and fourth images for 0 & 1;
            # mode = threadexp
            #		- sub in third/fourth images when node is leaf
            #		- sub in fifth/sixth images when node is open tree
            #		- sub in seventhd/eighth images when node is unopen tree
            # note: the only difference between thread & threadexp modes
            #	is that threadexp differentiates by nodeType
            my $nodeType =
              ( $mode eq THREADEXP_MODE )
              ? $this->nodeType( $node, $level )
              : 0;
            $b += 2 * $nodeType + 2;    # figure out the correct image index

            # concat back together
            $sub = $a . $b;

            # sub in correct images
            $sub =~ s/(\d)/$this->formatImage($this->images()->[$1])/geo;
        }

    }
    elsif ( $mode eq SINGLE_MODE ) {

        # just slot in the image
        $sub = $this->formatImage( $this->images()->[0] );

    }
    elsif ( $mode eq FOLDER_MODE ) {

        # indent approp + differentiate by nodeType

        # make indent
        my $a = "0" x $level;

        # make image index depending on this node's type
        my $b = $this->nodeType( $node, $level ) + 1;

        $b = 2 if ( $b == 3 && !$this->images()->[3] ); # make sure image exists
        $a .= $b;
        $a =~ s/([0123])/$this->formatImage($this->images()->[$1])/geo;
        $sub = $a;
    }

    # ick; otheriwse Foswiki:: does weird stuff
    $sub = "<!-- -->" unless $sub;

    # let superclass do most of the formatting
    my $res = $this->SUPER::formatNode( $node, $count, $level );

    # then we contribute our share
    $res =~ s/\$images/$sub/go;
    return $res;
}

# given a node, returns:
#	0 = leaf
#	1 = open branch
#	2 = closed branch

sub nodeType {
    my ( $this, $node, $level ) = @_;

    # leaf or branch?
    my $b = ( scalar( @{ $node->children } ) ) ? 1 : 0;

    # unopened branch?
    $b = 2
      if (
        $b == 1    # if branch
        && (
            $this->data("stoplevel") == $level ) # and we're at the bottom level
      );
    return $b;
}

# given image returns a HTML reference to it

sub formatImage {
    my ( $this, $im ) = @_;

    # fix up the directory, if needed

    unless ( $im =~ m/^\// ) {
        my $dir = IMG_DIR_TEMPL;

# (we should probably make the following sub once per formatter, not once per image)
        $dir =~ s/\$installWeb/Foswiki::Plugins::TreePlugin::installWeb()/geo;
        $im = $dir . $im;
    }

    # sub in image into image format
    my $res = $this->data("imageformat");
    $res =~ s/\$image/$im/;
    return $res;
}

sub imagesTotal {
    return $#{ $_[0]->{_images} };
}

sub images {
    my $this = shift;
    if (@_) { @{ $this->{_images} } = @_ }
    return \@{ $this->{_images} };
}

# seeds isNodeLast recursive function and normalizes
# the returned string depending on level
#
# class method

sub getLasts {
    my ( $node, $level ) = @_;
    my $lastString = "";
    $lastString = isNodeLast( $node, $level )
      unless ( $level == 0 );    # don't do root
    return
      substr( $lastString, -$level )
      ;    # just get the data pertainent to this tree view
}

# returns a string of 1s and 0s representing whether its direct ancestry
# were the last in their sibling groups
# (eg, was parent the last? was granparent the last? etc)
# the order is furthest ancestor to closest
# (eg, 110 means grandgranparent was the last sibling,
#		so was grandparent, but parent wasn't
#
# class method

sub isNodeLast {
    my ( $node, $level ) = @_;

    #SL: make sure we don't recurse on the root level
    if ( $level == 0 ) {
        return 0;
    }
    my $parent = $node->parent;
    return 0 unless ( ref($parent) );

    my $order = $node->data("count") || 0;
    my $siblings = scalar( @{ $parent->children } ) - 1 || 0;
    my $t = ( $order == $siblings ) ? 1 : 0;
    return $t
      if ( $parent->name eq " " );    # HACK to stop recursion up the tree!!
                                      # though it should stop anyway
    return isNodeLast( $parent, --$level ) . $t; # recurse up the hierarchy tree
}

1;
