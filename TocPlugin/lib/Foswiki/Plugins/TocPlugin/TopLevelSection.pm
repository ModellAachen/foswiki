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
package Foswiki::Plugins::TocPlugin::TopLevelSection;

use strict;
use integer;

use Foswiki::Plugins::TocPlugin::Attrs      ();
use Foswiki::Plugins::TocPlugin::Section    ();
use Foswiki::Plugins::BookmakerPlugin::Book ();

# A specialisation of Section for the root of the table of contents

our @ISA = qw(Foswiki::Plugins::TocPlugin::Section);

######################################################################
# 'Object' methods.

# Constructor requires a context which provides loader services
sub new {
    my ( $class, $web, $wif ) = @_;
    my $this = $class->SUPER::new( 0, "ROOT" );
    $this->{ISA} = "TopLevelSection";
    $this->{WIF} = $wif;
    $this->{WEB} = $web;
    return bless( $this, $class );
}

# PUBLIC the wif to use to access the environment
sub wif {
    my $this = shift;
    return $this->{WIF};
}

# PUBLIC the web this is the toc of
sub web {
    my $this = shift;
    return $this->{WEB};
}

# Set/get the current topic being read and flag it as loaded; we are
# about to perform an operation that requires it.
sub currentTopic {
    my $this      = shift;
    my $ctn       = $Foswiki::Plugins::SESSION->{topicName};
    my $currTopic = $this->_findTopic($ctn);
    $currTopic->loaded(1) if $currTopic;
    return $currTopic;
}

# Load all topics under the given section.
sub loadTopics {
    my ( $this, $sec ) = @_;

    if ( defined( $sec->wikiName() ) ) {
        $this->loadTopic($sec);
    }

    if ( scalar( @{ $sec->{SECTIONS} } ) ) {
        my $subsection;
        foreach $subsection ( @{ $sec->{SECTIONS} } ) {
            $this->loadTopics($subsection);
        }
    }
}

# Load the sections for a topic from the data directory
sub loadTopic {
    my ( $this, $section ) = @_;
    return if ( defined( $section->loaded() ) );
    die unless defined( $section->wikiName() );
    my $text = $this->wif()->readTopic( $section->_getTopicURL() );
    $text =~ s/\r//go;
    $section->parseTopicText($text);
}

# PUBLIC STATIC
# Factory method to generate the TOC for a web.
# Initialise the table of contents from the WebOrder topic. The
# table will only be partially populated; no topics will actually
# be parsed yet.
sub createTOC {
    my ( $web, $wif ) = @_;

    my $this = Foswiki::Plugins::TocPlugin::TopLevelSection->new( $web, $wif );

# load the table of contents topic
# Note that this does not use the BookmakerPlugin API for the simple reason that it has to
# support an old format for the WebOrder topic. However it is fully compatible.
    if ( $wif->topicExists("WebOrder") ) {
        my $book =
          Foswiki::Plugins::BookmakerPlugin::Book->new("$web.WebOrder");
        my $attrs = Foswiki::Plugins::TocPlugin::Attrs->new("");

        # Check that each topic in the WebOrder only appears once

        my $bit = $book->each();

        while ( $bit->hasNext() ) {
            my $tocEntry = $bit->next();
            my $name =
              $tocEntry->{topic};   # Ignore web; tocs only work in a single web

            $attrs->set( "level", $tocEntry->{level} + 1 );
            $attrs->set( "text",  $name );
            my $ne = $this->processSECTIONTag($attrs);
            $ne->wikiName($name) if ( $wif->topicExists($name) );
        }
    }

    return ( $this, "" );
}

# TOCCHECK tag implementation
sub processTOCCHECKTag {
    my $this = shift;

    # Find files in this web which are not listed in the WebOrder topic
    # Get list of files in the web
    my @fullList = $this->wif()->webDirList();

    my $result = "";
    my $topic;
    foreach $topic (@fullList) {

        # ignore topics that start with "Web"
        if ( $topic !~ m/^Web/o && !$this->_findTopic($topic) ) {
            $result = $result . "\n<LI>" . $topic . "</LI>";
        }
    }

    if ( $result ne "" ) {
        $result = Foswiki::Plugins::TocPlugin::Section::_error(
                "The following topics were not found "
              . "in the WebOrder:\n<OL>"
              . $result
              . "\n</OL>\n" );
    }
    return $result;
}

# Generate table of contents
sub processTOCTag {
    my ( $this, $attrSet ) = @_;

    my $html  = "<DIV>\n";
    my $topic = $attrSet->get("topic");
    my $depth = $attrSet->get("depth");
    my $root  = $this->_getRoot();
    if ( defined($topic) ) {
        $topic = Foswiki::Plugins::TocPlugin::Section::_toWikiName($topic);
        $root  = $root->_findTopic($topic);
        if ( !$root ) {
            return Foswiki::Plugins::TocPlugin::Section::_error(
                "Bad topic $topic");
        }
    }

    $this->loadTopics($root);
    $html = $html . $root->generateTOC($depth);

    return $html . "</DIV>";
}

# REFTABLE tag implementation
sub processREFTABLETag {
    my ( $this, $attrSet ) = @_;
    my $type = $attrSet->get("type");

    return Foswiki::Plugins::TocPlugin::Section::_error("Bad type in REFTABLE")
      unless ( defined($type) );
    return $this->generateRefTable($type);
}

# Get a list of all file-level topics in the toc.
sub getTopicList {
    my ( $this, $topics ) = @_;
    my $section;
    foreach $section ( @{ $this->{SECTIONS} } ) {
        if ( defined( $section->wikiName() ) ) {
            push @$topics, $section->wikiName();
        }
        getTopicList( $section, $topics );
    }
}

sub toPrint {
    my ( $this, $toc, $wif, $web, $nohtml ) = @_;
    return $this->SUPER::toPrint( $wif, $toc, $web, $nohtml );
}

sub toString {
    my ( $this, $nohtml ) = @_;
    my $res = $this->{ISA} . "(web=" . $this->{WEB} . ") ";
    $res .= "<b>"  unless $nohtml;
    $res .= "ISA";
    $res .= "</b>" unless $nohtml;
    return $res . " [" . $this->SUPER::toString($nohtml) . "]";
}

1;
