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
package Foswiki::Plugins::TocPlugin::Section;

use strict;
use integer;
use Assert;

use Foswiki::Plugins::TocPlugin::Attrs           ();
use Foswiki::Plugins::TocPlugin::Anchor          ();
use Foswiki::Plugins::TocPlugin::TopLevelSection ();

# A node in the tree of sections. Each Section is an Anchor of type
# "Section"

our @ISA = qw(Foswiki::Plugins::TocPlugin::Anchor);

sub new {
    my ( $class, $level, $text ) = @_;

    my $this = $class->SUPER::new( "Section", $level, $text, 1 );

    $this->{ISA} = "Section";

    # array of subsections
    $this->{SECTIONS} = [];

    # link anchors targetting this section
    $this->{ANCHORS} = {};

    # depth of this section in the section hierarchy
    $this->{LEVEL} = $level;

    # parent section
    $this->{PARENT} = undef;

    # position in the parent section's subsection list
    $this->{POSITION} = -1;

    # files only - wiki name of this section (web.topic)
    $this->{WIKINAME} = undef;

    # file only - has been loaded
    $this->{IS_LOADED} = undef;

    return bless( $this, $class );
}

# PRIVATE see if the last subsection can be purged
sub _backIsPurgeable {
    my $this = shift;
    my $bidx = scalar( @{ $this->{SECTIONS} } );
    return 1 if $bidx == 0;
    my $back = @{ $this->{SECTIONS} }[ $bidx - 1 ];
    return 0 unless $back->wikiName();
    return 1;
}

# PUBLIC remove existing sections and anchors that came from
# the text file. (What if there's a generated section?)
sub purge {
    my $this = shift;

    # Kill all anchors
    $this->{ANCHORS} = {};

    # Pop sections that are tagged as purgeable
    while ( !$this->_backIsPurgeable() ) {
        pop @{ $this->{SECTIONS} };
    }

    # purge children
    my $child;
    foreach $child ( @{ $this->{SECTIONS} } ) {
        $child->purge();
    }
}

# PUBLIC the depth of this section, relative to the root
sub level {
    my $this = shift;
    if (@_) { $this->{LEVEL} = shift; }
    return $this->{LEVEL};
}

# PUBLIC the containing section of this section
sub parent {
    my $this = shift;
    if (@_) { $this->{PARENT} = shift; }
    return $this->{PARENT};
}

# PUBLIC position in the parent section's subsection list
sub position {
    my $this = shift;
    if (@_) { $this->{POSITION} = shift; }
    return $this->{POSITION};
}

# PUBLIC Access the wiki name, undef if this is not a wiki topic
sub wikiName {
    my $this = shift;
    if (@_) { $this->{WIKINAME} = shift; }
    return $this->{WIKINAME};
}

# PUBLIC Access the loaded status
sub loaded {
    my $this = shift;
    if (@_) { $this->{IS_LOADED} = shift; }
    return $this->{IS_LOADED};
}

# PUBLIC Get the list of anchors for a given key
sub anchors {
    my ( $this, $key ) = @_;
    die "Bad key" unless defined($key);
    if ( defined( $this->{ANCHORS}->{$key} ) ) {
        return @{ $this->{ANCHORS}->{$key} };
    }
    else {
        return [];
    }
}

# PRIVATE add a new subsection to the end of our list of subsections
sub _push_back {
    my ( $this, $that ) = @_;

    push @{ $this->{SECTIONS} }, $that;

    $that->parent($this);
    $that->position( scalar( @{ $this->{SECTIONS} } ) );
    $that->uid( $that->_getSectionNumber() );
    $that->printable( $that->uid() );
}

# PROTECTED Get the root from within a topic
sub _getRoot {
    my $this = shift;

    while ( defined( $this->parent() ) ) {
        $this = $this->parent();
    }
    return $this;
}

# PROTECTED Get the topic that contains this section
sub _getTopic {
    my $this = shift;

    if ( defined( $this->wikiName() ) || !defined( $this->parent() ) ) {
        return $this;
    }
    return $this->parent()->_getTopic();
}

# PROTECTED Get the unique section number for this section.
sub _getSectionNumber {
    my $this = shift;

    my $parent = $this->parent();
    return "" unless ( defined($parent) );
    return $parent->_getSectionNumber() . $this->position() . ".";
}

# PROTECTED Get the wiki name of the topic that is, or contains, this
sub _getTopicURL {
    my $this = shift;
    return $this->_getTopic()->wikiName();
}

# PROTECTED Get the most recently added subsection
sub _getLastSubsection {
    my $this = shift;
    return @{ $this->{SECTIONS} }[ $#{ $this->{SECTIONS} } ];
}

# PROTECTED add a new subsection at, or below, the level of this section.
sub _addSection {
    my ( $this, $newEntry ) = @_;

    die "Section depth not relative to root "
      . $newEntry->level() . " <= "
      . $this->level()
      if $newEntry->level() <= $this->level();

    if ( $newEntry->level() == $this->level() + 1 ) {

        # add at this level
        $this->_push_back($newEntry);
    }
    else {

        # add to the last entry added
        if ( scalar( @{ $this->{SECTIONS} } ) == 0 ) {

            # insert a pseudo-section to compensate for the
            # missing section level
            my $tmp =
              Foswiki::Plugins::TocPlugin::Section->new( $this->level() + 1,
                "_missing_" );
            $this->_push_back($tmp);
        }
        $this->_getLastSubsection()->_addSection($newEntry);
    }
}

sub _replaceSection {
    my ( $this, $oe, $ne ) = @_;

    my $i = $oe->position() - 1;
    @{ $this->{SECTIONS} }[$i] = $ne;
    $oe->parent(undef);
    $ne->parent($this);
    $ne->position( $oe->position() );
}

# PROTECTED find a topic
sub _findTopic {
    my ( $this, $name ) = @_;

    return $this if ( $this->wikiName() && $name eq $this->wikiName() );

    my $child;
    foreach $child ( @{ $this->{SECTIONS} } ) {
        my $found = $child->_findTopic($name);
        return $found if $found;
    }
    return undef;
}

# PROTECTED Add a reference to this section
sub _addAnchor {
    my ( $this, $type, $uid, $text, $visible ) = @_;
    my $ref =
      Foswiki::Plugins::TocPlugin::Anchor->new( $type, $uid, $text, $visible );
    my $id  = $this->_getSectionNumber();
    my $idx = 0;
    if ( defined( $this->{ANCHORS}->{$type} ) ) {
        $idx = @{ $this->{ANCHORS}->{$type} };
    }
    $id = $id . pack( "c", ord("A") + $idx );
    $ref->printable($id);
    push( @{ $this->{ANCHORS}->{$type} }, $ref );
    return $ref;
}

# PROTECTED Find a link target and return the topic, the link and
# the text.
sub _findTarget {
    my ( $this, $type, $id ) = @_;

    # find the tag
    my $link;
    foreach $link ( @{ $this->{ANCHORS}->{$type} } ) {
        if ( $link->uid() eq $id ) {
            return ( $this, $link );
        }
    }

    my $section;
    foreach $section ( @{ $this->{SECTIONS} } ) {
        my ( $sec, $link ) = $section->_findTarget( $type, $id );
        if ( defined($link) ) {
            return ( $sec, $link );
        }
    }
    return undef;
}

# PUBLIC Generate HTML to target the link
sub generateReference {
    my ( $this, $relativeTo ) = @_;

    if (   $this->wikiName()
        && $relativeTo
        && $this->wikiName() eq $relativeTo )
    {
        my $text = $this->genIdentText() . " " . $this->text();
        return
            "<A href=\""
          . $relativeTo . "\">"
          . $this->unWikiWord($text) . "</A>";
    }

    return $this->SUPER::generateReference($relativeTo);
}

# PROTECTED Generate a decorated target for this section
sub generateTarget {
    my $this  = shift;
    my $topic = $this->_getTopic();
    my $level = $this->level() - $topic->level() + 1;
    my $text  = "";

    $text = $this->SUPER::generateTarget();

    my $key;
    foreach $key ( keys %{ $this->{ANCHORS} } ) {
        my $link;
        foreach $link ( $this->anchors($key) ) {
            $text = $text . $link->generateTarget() . "\n";
        }
    }
    $level = 6 if $level > 6;
    return "<H" . $level . ">" . $text . "</H" . $level . ">";
}

# Generate table of contents row for this section
# $depth gives the number of levels to generate below the start
# point. May be 0, in which case all levels will be generated.
# $level gives the depth of this section below the start point;
# Call with $level = undef
sub generateTOC {
    my ( $this, $depth ) = @_;

    $depth = 999 unless ( defined($depth) && $depth > 0 );

    my $html = "<UL>";
    if ( $this->level() == 0 ) {
        my $section;
        foreach $section ( @{ $this->{SECTIONS} } ) {
            $html = $html . $section->_generateTOC($depth);
        }
    }
    else {
        $html = $html . $this->_generateTOC($depth);
    }
    return $html . "</UL>";
}

sub _generateTOC {
    my ( $this, $depth ) = @_;

    my $topic = $this->_getTopic();
    my $tgt   = undef;
    $tgt = $topic->wikiName()
      if ( defined($topic) && defined( $topic->wikiName() ) );
    my $html = "<LI>" . $this->generateReference($tgt);

    if ( $depth > 1 && scalar( @{ $this->{SECTIONS} } ) ) {
        my $section;
        $html = $html . "<UL>\n";
        foreach $section ( @{ $this->{SECTIONS} } ) {
            $html = $html . $section->_generateTOC( $depth - 1 );
        }
        $html = $html . "</UL>";
    }

    return $html . "</LI>\n";
}

# Generate ref table rows for all targets in this section and
# below for the given reference type.
# $type is the name of the type to generate the table for
# $level is the level reached in recursion (internal, don't use)
sub generateRefTable {
    my ( $this, $type, $level ) = @_;
    my $html = "";

    if ( !defined($level) ) {
        $html = "<TABLE cols=1 border=2>\n" . "<TR><TH>$type</TH></TR>\n";
    }

    # find the tag
    my $topic = $this->_getTopic();
    my $link;
    foreach $link ( @{ $this->{ANCHORS}->{$type} } ) {
        $html =
            $html . "<TR>"
          . "<TD width=\"10%\">"
          . $link->generateReference( $topic->wikiName() )
          . "</TD></TR>\n";
    }

    my $section;
    foreach $section ( @{ $this->{SECTIONS} } ) {
        $html = $html . $section->generateRefTable( $type, 1 );
    }

    if ( !defined($level) ) {
        $html = $html . "</TABLE>\n";
    }
    return $html;
}

# Generate a prettifying indent to make the HTML readable
sub _indent {
    my $level = shift;
    my $text  = "";
    for ( my $i = 0 ; $i < $level ; $i++ ) {
        $text = $text . "  ";
    }
    return $text;
}

# Process a SECTION tag. Establishes the section under which this
# section is to be added, determines if the section is already
# there. If the section is already there, replaces it, otherwise
# adds it.
# $this - section to add to
# $attrSet - attributes on tag
# $level - root-relative section level
# $title - text associated with section
sub processSECTIONTag {
    my ( $this, $attrSet ) = @_;

    my $level = $attrSet->get("level");

    if ( $level == $this->level() && $this->wikiName() ) {
        $this = $this->_getTopic();
        $this->text( $attrSet->get("text") );
        return $this;
    }
    elsif ( $level < $this->level() ) {
        return $this->parent()->processSECTIONTag($attrSet);
    }

    my $title = $attrSet->get("text");

    my $noTagsTitle = tidy( replaceAllTags( $title, "" ) );
    my $ne = Foswiki::Plugins::TocPlugin::Section->new( $level, $noTagsTitle );

    # Will add intervening sections if required
    $this->_addSection($ne);

    # We know the section number now, so cache it
    my $sec = $ne->_getSectionNumber();
    $ne->uid($sec);

    # add an extra anchor if so requested
    my $link = $attrSet->get("name");
    if ( defined($link) ) {
        $ne->_addAnchor( "Section", $link, $noTagsTitle, 0 );
    }
    return $ne;
}

# Process an ANCHOR tag
sub processANCHORTag {
    my ( $this, $attrSet ) = @_;

    die unless $this->wikiName();

    my $type        = $attrSet->get("type");
    my $name        = $attrSet->get("name");
    my $display     = $attrSet->{"display"};
    my $title       = $attrSet->get("text");
    my $visible     = ( !$display || $display ne "no" );
    my $noTagsTitle = tidy( replaceAllTags( $title, "" ) );

    return undef unless ( defined($type) && defined($name) );

    # Add the anchor to the last subsection under this
    my $lss = $this;
    while ( scalar( @{ $lss->{SECTIONS} } ) ) {
        $lss = $lss->_getLastSubsection();
    }
    my $anchor = $lss->_addAnchor( $type, $name, $noTagsTitle, $visible );
    return $anchor;
}

# Subclasses should provide.
sub loadTopic {
    my ( $this, $sec ) = @_;
    die "$this $sec Section::loadTopic called"
      unless $sec->{SECTION_TESTS_JUST_TESTING};
}

# Process a REF tag and return a jump string
# If the topic is defined in the Attrs, searches in that
# topic.
sub processREFTag {
    my ( $this, $attrSet ) = @_;

    my $topic = $attrSet->get("topic");
    if ($topic) {
        $topic = _toWikiName($topic);
        my $fileTopic = $this->_getRoot()->_findTopic($topic);
        if ( !$fileTopic ) {
            return _error("No such topic $topic");
        }
        $this->_getRoot()->loadTopic($fileTopic);
        $this = $fileTopic;
    }
    return $this->_processREFTag($attrSet);
}

# Process a REF tag and return the topic and the link
# Searches for the tag below the current topic ONLY
sub _processREFTag {
    my ( $this, $attrSet ) = @_;

    my $type = $attrSet->get("type");
    my $name = $attrSet->get("name");

    if ( defined($type) ) {
        my ( $sec, $link ) = $this->_findTarget( $type, $name );
        if ( $sec && $link ) {
            my $sn = $sec->_getTopic()->wikiName();

            # if the link is a section type link, generate a reference to the
            # section
            return $sec->generateReference($sn)
              if ( $link->type() eq "Section" );

            # otherwise return the jump to the anchor
            return $link->generateReference($sn);
        }
        return _error(
            "Reference " . $this->wikiName() . ":$type:$name not satisfied" );
    }
    else {
        return _error("No type in REF tag");
    }
}

# Load the topic into this section
sub parseTopicText {
    my ( $this, $text ) = @_;
    my $i = 0;

    while ( $text =~ s/%(SECTION[0-9]+|ANCHOR)({[^%]*})?%(.*)//o ) {
        my ( $key, $title ) = ( $1, $3 );
        my $attrs = Foswiki::Plugins::TocPlugin::Attrs->new($2);
        $title =~ s/(^\s+|\s+$)//go;
        $attrs->set( "text", $title );
        $attrs->{name} ||= $i++;

        if ( $key =~ s/([0-9]+)//o ) {
            $key = $1;
            if ( $key == 0 ) {
                $this->text($title);
                $this->_addAnchor( "Section", $attrs->get("name"), $title, 0 );
            }
            else {
                $attrs->set( "level", $this->level() + $key );
                $this->processSECTIONTag($attrs);
            }
        }
        else {
            $this->processANCHORTag($attrs);
        }

        # recursively parse the title text
        $this->parseTopicText($title);
    }
    $this->loaded(1);
}

# Convert to a string for debugging
sub toString {
    my ( $this, $nohtml ) = @_;

    my $res = $this->{ISA} . "(";
    $res .= "level=" . $this->level();
    $res .= " position=" . $this->position();
    $res .= " secnum=" . $this->_getSectionNumber();
    $res .= " loaded" if ( $this->loaded() );
    if ( defined( $this->wikiName() ) ) {
        $res .= " wikiName=" . $this->wikiName();
    }
    $res .= ") ";
    $res .= "<b>" unless $nohtml;
    $res .= "ISA";
    $res .= "</b>" unless $nohtml;
    $res .= " [" . $this->SUPER::toString($nohtml) . "] {";

    my $key;
    my $listed = 0;
    foreach $key ( keys %{ $this->{ANCHORS} } ) {
        my $link;
        $res .= "<ul>" unless ( $listed || $nohtml );
        $res .= "<ul"  unless $nohtml;
        $res .= "$key=";
        foreach $link ( @{ $this->{ANCHORS}->{$key} } ) {
            $res .= " " . $link->toString($nohtml);
        }
        $listed = 1;
    }
    $res .= "</ul>" if ( $listed && !$nohtml );

    my $child;
    $listed = 0;
    foreach $child ( @{ $this->{SECTIONS} } ) {
        $res .= "<ul>" unless ( $listed || $nohtml );
        $res .= "<li>" . $child->toString($nohtml);
        $listed = 1;
    }
    $res .= "</ul>" if ( $listed && !$nohtml );

    $res .= "}";
    return $res;
}

# for webPrint function
sub toPrint {
    my ( $this, $wif, $toc, $web, $nohtml ) = @_;
    my $res = "";

    if ( defined( $this->wikiName() ) ) {
        my $ct   = $toc->_findTopic( $this->wikiName );
        my $text = $wif->readTopic( $this->wikiName );

        $res .=
          Foswiki::Plugins::TocPlugin::TOC::_printWithTOCTags( $toc, $wif, $ct,
            $text );

    }

    my $child;
    foreach $child ( @{ $this->{SECTIONS} } ) {
        $res .= $child->toPrint( $wif, $toc, $web, $nohtml );
    }

    return $res;
}

#######################################################
# Static functions private to this package

# remove tags of a given type from a string
sub _replaceTypeTags {
    my ( $type, $text, $alt ) = @_;
    $text =~ s/%$type({[^%]*})?%/$alt/ge;
    return $text;
}

# Remove all types of TOC tag from the string
sub replaceAllTags {
    my ( $text, $alt ) = @_;

    $text = _replaceTypeTags( "ANCHOR", $text, $alt );
    $text =~ s/%SECTION[0-9]+({[^%]*})?%/$alt/geo;
    $text = _replaceTypeTags( "REFTABLE",   $text, $alt );
    $text = _replaceTypeTags( "CONTENTS",   $text, $alt );
    $text = _replaceTypeTags( "TOCCHECK",   $text, $alt );
    $text = _replaceTypeTags( "TOCBUTTONS", $text, $alt );

    return $text;
}

sub tidy {
    my $text = shift;
    $text =~ s/^\s+//so;
    $text =~ s/\s+$//so;
    return $text;
}

# static method to convert a toc entry to a wiki word
sub _toWikiName {
    my $t = shift;
    $t =~ s/^[\s*]*//o;
    $t =~ s/[\s*]*$//o;

    # expand [[odd link]]
    $t =~ s/\[\[([\w\s]+)\]\]/_expandOddLink($1)/eo;
    return $t;
}

# Modified version of internalLink from wiki.pm, required because the
# original is rather overenthusiastic in reformatting the link.
sub _expandOddLink {
    my ($topic) = @_;

    # kill spaces and Wikify topic name
    $topic =~ s/^\s*//o;
    $topic =~ s/\s*$//o;
    $topic =~ s/^(.)/\U$1/o;
    $topic =~ s/\s([a-zA-Z0-9])/\U$1/go;
    return $topic;
}

# Create a red string
sub _error {
    my ($text) = @_;
    return "<FONT color=#ff0000>$text</FONT>";
}

1;
