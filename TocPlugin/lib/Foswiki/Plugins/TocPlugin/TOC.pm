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
package Foswiki::Plugins::TocPlugin::TOC;

use strict;
use integer;

use Foswiki::Plugins::TocPlugin::Attrs           ();
use Foswiki::Plugins::TocPlugin::Section         ();
use Foswiki::Plugins::TocPlugin::TopLevelSection ();

# Private
sub _processTag {
    my ( $toc, $wif, $ct, $tag, @params ) = @_;

    if ( $tag eq "TOCCHECK" ) {
        return $toc->processTOCCHECKTag(@params);
    }
    elsif ( $tag eq "CONTENTS" ) {
        return $toc->processTOCTag(@params);
    }
    elsif ( $tag eq "REFTABLE" ) {
        return $toc->processREFTABLETag(@params);
    }
    elsif ( $tag eq "TOCDUMP" ) {
        return $toc->toString(0);
    }
    else {
        if ( $tag eq "TOCBUTTONS" ) {

            # Return nothing for topics not in WebOrder
            return "" unless $ct;
            return &Foswiki::Plugins::TocPlugin::TOC::processTOCBUTTONSTag(
                $toc, $wif, $ct->wikiName() );
        }
        return Foswiki::Plugins::TocPlugin::Section::_error(
            "Bad $tag: Current topic not in WebOrder")
          unless $ct;
        if ( $tag eq "ANCHOR" ) {
            my $anc = $ct->processANCHORTag(@params);
            return $anc->generateTarget() if $anc;
        }
        elsif ( $tag eq "SECTION" ) {
            my $sec = $ct->processSECTIONTag(@params);
            return $sec->generateTarget() if $sec;
        }
        elsif ( $tag eq "REF" ) {
            return $ct->processREFTag(@params);
        }
    }
    return Foswiki::Plugins::TocPlugin::Section::_error(
        "Bad tag $tag: " . join( ",", @params ) );
}

# Process TOC tags in the current topic
# MAIN ENTRY POINT for Foswiki
sub _processTOCTags {
    my ( $toc, $wif, $text ) = @_;

    my $ct = $toc->currentTopic();

    # remove sections and anchors that were generated from the text
    # from the current topic for reload as the content may have changed
    $ct->purge() if $ct;

    # Anchors and sections must be done before we generate the table
    # of contents and ref tables.
    while ( $text =~ s/%(SECTION\d+|ANCHOR)({[^%]*})?%(.*)/\<TOC_Mark\>/ ) {
        my $tag   = $1;
        my $attrs = Foswiki::Plugins::TocPlugin::Attrs->new($2);
        $attrs->set( "text", $3 );
        if ($ct) {
            if ( $tag =~ s/SECTION([0-9]+)//o ) {
                my $level = $1;
                $attrs->set( "level", $ct->level() + $level );
                $text =~
s/\<TOC_Mark\>/&_processTag($toc, $wif, $toc->currentTopic, "SECTION", $attrs)/e;
            }
            else {
                $text =~
s/\<TOC_Mark\>/&_processTag($toc, $wif, $toc->currentTopic, "ANCHOR", $attrs)/e;
            }
        }
    }

    # The order in which the other tags is done is irrelevant
    my $nullatt = Foswiki::Plugins::TocPlugin::Attrs->new("");
    $text =~
s/%(REF|REFTABLE){([^%]*)}%/&_processTag($toc, $wif, $toc->currentTopic, $1, Foswiki::Plugins::TocPlugin::Attrs->new($2))/geo;
    $text =~
s/%(TOCDUMP)%/&_processTag($toc, $wif, $toc->currentTopic, $1, $nullatt)/geo;
    $text =~
s/%(TOCCHECK)%/&_processTag($toc, $wif, $toc->currentTopic, $1, $nullatt)/geo;
    $text =~
s/%(CONTENTS)({[^%]*})?%/&_processTag($toc, $wif, $toc->currentTopic, $1, Foswiki::Plugins::TocPlugin::Attrs->new($2))/geo;
    $text =~
s/%(TOCBUTTONS)%/&_processTag($toc, $wif, $toc->currentTopic, $1, $nullatt)/geo;
    return $text;
}

my $toc  = undef;
my $mess = undef;

sub processTOCBUTTONSTag {
    my ( $toc, $wif, $topic ) = @_;

    return "" unless ( defined $toc );
    my $mytopic = $toc->currentTopic();
    return "" unless ( defined $mytopic );

    # Get list of files in the web
    my $i;
    my @fullList = ();
    $toc->getTopicList( \@fullList );

    for ( $i = 0 ; $i < scalar(@fullList) ; $i++ ) {
        last if ( $fullList[$i] eq $topic );
    }

    my ( $prev,     $next,     $home );
    my ( $prevText, $nextText, $homeText );
    if ( $i > 0 ) {
        $prev     = $fullList[ $i - 1 ];
        $prevText = "Prev";
    }
    else {
        $prev = $prevText = "";
    }
    if ( $i < scalar(@fullList) - 1 ) {
        $next     = $fullList[ $i + 1 ];
        $nextText = "Next";
    }
    else {
        $next = $nextText = "";
    }
    $home     = $fullList[0];
    $homeText = "Home";

    if ($prev) {
        $prev = $toc->_findTopic($prev);
        $toc->loadTopic($prev);
        $prev = $prev->generateReference( $prev->wikiName() );
    }
    if ($next) {
        $next = $toc->_findTopic($next);
        $toc->loadTopic($next);
        $next = $next->generateReference( $next->wikiName() );
    }
    if ($home) {
        $home = $toc->_findTopic($home);
        $toc->loadTopic($home);
        $home = $home->generateReference( $home->wikiName() );
    }

    return (
        "<table WIDTH=\"100%\" BORDER=\"0\" CELLPADDING=\"0\" CELLSPACING=\"0\">
<tr><td WIDTH=\"33%\" ALIGN=\"left\" VALIGN=\"top\">$prev<td>
<td WIDTH=\"33%\" ALIGN=\"center\" VALIGN=\"top\">$home<td>
<td WIDTH=\"33%\" ALIGN=\"right\" VALIGN=\"top\">$next<td><tr>
<tr><td WIDTH=\"33%\" ALIGN=\"left\" VALIGN=\"top\">$prevText<td>
<td WIDTH=\"33%\" ALIGN=\"center\" VALIGN=\"top\">$homeText<td>
<td WIDTH=\"33%\" ALIGN=\"right\" VALIGN=\"top\">$nextText<td><tr></table>"
    );
}

sub _printWithTOCTags {
    my ( $toc, $wif, $ct, $text ) = @_;

    # remove sections and anchors that were generated from the text
    # from the current topic for reload as the content may have changed
    $ct->purge() if $ct;

    # Anchors and sections must be done before we generate the table
    # of contents and ref tables.
    while ( $text =~ s/%((SECTION[0-9]+)|ANCHOR)({[^%]*})?%(.*)/\<TOC_Mark\>/o )
    {
        my $tag   = $1;
        my $attrs = Foswiki::Plugins::TocPlugin::Attrs->new($3);
        $attrs->set( "text", $4 );
        if ( $tag =~ s/SECTION([0-9]+)//o ) {
            my $level = $1;
            $attrs->set( "level", $ct->level() + $level );
            $text =~
s/\<TOC_Mark\>/&_processTag($toc, $wif, $ct, "SECTION", $attrs)/eo;
        }
        else {
            $text =~
              s/\<TOC_Mark\>/&_processTag($toc, $wif, $ct, "ANCHOR", $attrs)/eo;
        }
    }

    # The order in which the other tags is done is irrelevant
    my $nullatt = Foswiki::Plugins::TocPlugin::Attrs->new("");
    $text =~
s/%(REF|REFTABLE){([^%]*)}%/&_processTag($toc, $wif, $ct, $1, Foswiki::Plugins::TocPlugin::Attrs->new($2))/geo;
    $text =~
s/%(CONTENTS)({[^%]*})?%/&_processTag($toc, $wif, $ct, $1, Foswiki::Plugins::TocPlugin::Attrs->new($2))/geo;
    $text =~ s/%(TOCCHECK)%/&_processTag($toc, $wif, $ct, $1, $nullatt)/geo;
    $text =~ s/%(TOCDUMP)%/&_processTag($toc, $wif, $ct, $1, $nullatt)/geo;

    return $text;
}

sub _webPrint {
    my ( $toc, $wif, $web ) = @_;
    return $toc->toPrint( $toc, $wif, $web, 0 );
}

sub processTopic {
    my ( $wif, $web, $topic, $text ) = @_;

    # If this is a different web, need to reload the weborder
    # If the topic is WebOrder, have to reload the weborder
    # If the topic is something else, need to reset it to the weborder
    if ( !$toc || $web ne $toc->web() || $topic eq "WebOrder" ) {
        my $mess;
        ( $toc, $mess ) =
          Foswiki::Plugins::TocPlugin::TopLevelSection::createTOC( $web, $wif );
        if ( $toc && $topic eq "WebPrint" ) {
            return _webPrint( $toc, $wif, $web );
        }

        return Foswiki::Plugins::TocPlugin::Section::replaceAllTags( $text,
            $mess )
          unless $toc;
    }
    my $ct = $toc->currentTopic();

    return _processTOCTags( $toc, $wif, $text );
}

1;
