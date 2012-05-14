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
# Canned interface to Foswiki. Provided so that TOC scripts don't have to use
# Foswiki::Func everywhere. This makes testing easier and
# significantly improves portability between versions (a TOCIF can easily
# be written for older versions of Foswiki).
package Foswiki::Plugins::TocPlugin::TOCIF;

use strict;
use integer;

use Foswiki::Func ();

# Singleton instance
my $singleton;

# Factory method, returns a singleton instance of a Foswiki interface
sub getInterface {
    my ( $class, $web, $topic ) = @_;
    $singleton ||= bless( {}, $class );
    return $singleton;
}

sub topicExists {
    my ( $this, $topic ) = @_;
    my ( $w,    $t )     = Foswiki::Func::normalizeWebTopicName(
        $Foswiki::Plugins::SESSION->{webName}, $topic );
    return Foswiki::Func::topicExists( $w, $t );
}

sub readTopic {
    my ( $this, $topic ) = @_;
    my $text = "";

    # read the topic
    my ( $w, $t ) = Foswiki::Func::normalizeWebTopicName(
        $Foswiki::Plugins::SESSION->{webName}, $topic );
    $text = Foswiki::Func::readTopic( $w, $t );

    # expand the variables -- in the context of the appropriate topic
    $text = Foswiki::Func::expandCommonVariables( $text, $t, $w );

    # this can't be right -- turn verbatim tags into pre tags
    $text =~ s/<verbatim>/<pre>/go;
    $text =~ s/<\/verbatim>/<\/pre>/go;
    return $text;
}

sub webDirList {
    my $this = shift;
    return Foswiki::Func::getTopicList( $Foswiki::Plugins::SESSION->{webName} );
}

1;
