# See bottom of file for license and copyright information
package Foswiki::Plugins::FindElsewherePlugin::Core;

use strict;
use warnings;

BEGIN {

    # Do a dynamic 'use locale' for this module
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Set to 1 to get debug messages written to the warnings log
use constant TRACE => 0;

my $thisWeb;
my $findAcronyms;
my $disablePluralToSingular;
my $redirectable;
my @webList;
my $singleMixedAlphaNumRegex;
my $otherWebs;

my $EMESC = "\1";

sub initPlugin {

    # initPlugin($topic, $web, $user) -> $boolean

    $thisWeb = $_[1];

    $otherWebs = Foswiki::Func::getPreferencesValue("LOOKELSEWHEREWEBS");
    unless ( defined($otherWebs) ) {

        # Compatibility, deprecated
        $otherWebs =
          Foswiki::Func::getPluginPreferencesValue("LOOKELSEWHEREWEBS");
    }

    unless ( defined($otherWebs) ) {

        # SMELL: Retained for compatibility, but would be much better
        # off without this, as we could use the absence of webs to mean the
        # plugin is disabled.
        $otherWebs = "$Foswiki::cfg{SystemWebName},$Foswiki::cfg{UsersWebName}";
    }

 # Item10460: Expand some variables like %USERSWEB%
 # WARNING: calling expandCommonVariables inside initPlugin is a bad thing to do
 # as the engine isn't fully initialized at that point
    $otherWebs =~ s/\%USERSWEB%/$Foswiki::cfg{UsersWebName}/g;
    $otherWebs =~ s/\%SYSTEMWEB%/$Foswiki::cfg{SystemWebName}/g;
    $otherWebs =~ s/\%SANDBOXWEB%/$Foswiki::cfg{SandboxWebName}/g;

    $findAcronyms =
      Foswiki::Func::getPreferencesValue("LOOKELSEWHEREFORACRONYMS") || "all";

    $disablePluralToSingular =
      Foswiki::Func::getPreferencesFlag("DISABLEPLURALTOSINGULAR");
    unless ( defined($disablePluralToSingular) ) {

        # Compatibility, deprecated
        $disablePluralToSingular =
          Foswiki::Func::getPluginPreferencesFlag("DISABLEPLURALTOSINGULAR");
    }

    $redirectable = Foswiki::Func::getPreferencesFlag("LOOKELSEWHEREFORLOCAL");

    $singleMixedAlphaNumRegex = qr/[$Foswiki::regex{mixedAlphaNum}]/;

}

sub preRenderingHandler {

    @webList = ();

    # Might still be unexpanded macros - expand if necessary
    if ( $otherWebs =~ m/%/ ) {
        $otherWebs = Foswiki::Func::expandCommonVariables($otherWebs);
    }

    foreach my $otherWeb ( split( /[,\s]+/, $otherWebs ) ) {
        $otherWeb = Foswiki::Sandbox::untaint( $otherWeb,
            \&Foswiki::Sandbox::validateWebName );
        push( @webList, $otherWeb ) if $otherWeb;
    }

    if ( exists( $Foswiki::cfg{FindElsewherePlugin}{CairoLegacyLinking} )
        && $Foswiki::cfg{FindElsewherePlugin}{CairoLegacyLinking} )
    {

        #very old, pre-nested webs linking rules.
    }
    else {
        unless ( scalar(@webList) ) {

            # no point if there are no webs to search
            return;
        }
    }

    # Find instances of WikiWords not in this web, but in the otherWeb(s)
    # If the WikiWord is found in theWeb, put the word back unchanged
    # If the WikiWord is found in the otherWeb, link to it via
    # [[otherWeb.WikiWord]]
    # If it isn't found there either, put the word back unchnaged

    my $removed = {};
    my $text = _takeOutBlocks( $_[0], 'noautolink', $removed );

    $text =~ s/(?<=[\s\(])
        ($Foswiki::regex{emailAddrRegex})/${EMESC}<nop>$1/gox;

    # Match
    # 0) (Allowed preambles: "\s" and "(")
    # 1) [[something]] - (including [[something][something]], but non-greedy),
    # 2) WikiWordAsWebName.WikiWord,
    # 3) WikiWords, and
    # 4) WIK IWO RDS
    my %linkedWords = ();
    my $count       = (
        $text =~ s/(\[\[.*?\]\]|(?:^|(?<=[\s\(,]))
                       (?:$Foswiki::regex{webNameRegex}\.)?
                       (?:$Foswiki::regex{wikiWordRegex}
                       | $Foswiki::regex{abbrevRegex}))/
                         _findTopicElsewhere($thisWeb, $1, \%linkedWords)/gexo
    );

    $text =~ s/${EMESC}<nop>//go;

    if ($count) {
        _putBackBlocks( \$text, $removed, 'noautolink' );
        $_[0] = $text;
    }
}

sub makeTopicLink {
    ##my($otherWeb, $topic) = @_;
    return "[[$_[0].$_[1]][$_[0]]]";
}

sub _findTopicElsewhere {

    # This was copied and pruned from Foswiki::internalLink
    my ( $web, $topic, $linkedWords ) = @_;
    my $original         = $topic;
    my $linkText         = $topic;
    my $nonForcedAcronym = 0;

    Foswiki::Func::writeDebug(
        "FindElsewherePlugin: Called $web, $topic Redirectable = $redirectable")
      if TRACE;

    if (
        $topic =~ /^\[\[($Foswiki::regex{webNameRegex})\.
                      ($Foswiki::regex{wikiWordRegex})\](?:\[(.*)\])?\]$/ox
      )
    {
        if ( $redirectable && $1 eq $web ) {

            # The topic is *supposed* to be in this web, but the web is
            # redirectable so we can ignore the web specifier
            # remove the web name and continue
            Foswiki::Func::writeDebug(
                "FindElsewherePlugin: $topic $1 is redirectable")
              if TRACE;
            $topic = $2;
            $linkText = $3 || $topic;
        }
        else {

            # The topic is an explicit link to another web
            return $topic;
        }
    }
    elsif (
        $topic =~ /^\[\[($Foswiki::regex{wikiWordRegex})\]
                           (?:\[(.*)\])?\]$/ox
      )
    {

        # No web specifier, look elsewhere
        $topic = $1;
        $linkText = $2 || $topic;
    }
    elsif (
        $topic =~ /^\[\[($Foswiki::regex{abbrevRegex})\]
                           (?:\[(.*)\])?\]$/ox
      )
    {

        # No web specifier, look elsewhere
        $topic = $1;
        $linkText = $2 || $topic;
    }
    elsif ( $topic =~ /^$Foswiki::regex{abbrevRegex}$/o ) {
        $nonForcedAcronym = 1;
    }
    elsif (
        $topic =~ /^($Foswiki::regex{webNameRegex})\.
                           ($Foswiki::regex{wikiWordRegex})$/ox
      )
    {
        if ( $redirectable && $1 eq $web ) {
            $linkText = $topic = $2;
        }
        else {
            return $topic;
        }
    }

    if ($nonForcedAcronym) {
        return $topic if $findAcronyms eq "none";
        return $linkedWords->{$topic}
          if ( $findAcronyms eq 'all' && $linkedWords->{$topic} );
        return $topic
          if ( $findAcronyms eq 'first' && $linkedWords->{$topic} );
    }

    # Turn spaced-out names into WikiWords - upper case first letter of
    # whole link, and first of each word.
    $topic =~ s/^(.)/\U$1/o;
    $topic =~ s/\s($singleMixedAlphaNumRegex)/\U$1/go;
    $topic =~ s/\[\[($singleMixedAlphaNumRegex)(.*)\]\]/\u$1$2/o;

    # It's been validated
    $web   = Foswiki::Sandbox::untaintUnchecked($web);
    $topic = Foswiki::Sandbox::untaintUnchecked($topic);

    # Look in the current web, return if found
    my $exist = Foswiki::Func::topicExists( $web, $topic );

    if ( !$exist ) {
        if ( !$disablePluralToSingular && $topic =~ /s$/ ) {
            my $topicSingular = _makeSingular($topic);
            if ( Foswiki::Func::topicExists( $web, $topicSingular ) ) {
                Foswiki::Func::writeDebug(
                    "FindElsewherePlugin: $topicSingular was found in $web")
                  if TRACE;
                return $original;    # leave it as we found it
            }
        }
    }
    else {
        Foswiki::Func::writeDebug(
            "FindElsewherePlugin: $topic was found in $web: $linkText")
          if TRACE;
        return $original;            # leave it as we found it
    }

    # Look in the other webs, return when found
    my @topicLinks;

    foreach my $otherWeb (@webList) {

        # For systems running WebNameAsWikiName
        # If the $topic is a reference to a the name of
        # otherWeb, point at otherWeb.WebHome - MRJC
        if ( $otherWeb eq $topic ) {
            Foswiki::Func::writeDebug(
"FindElsewherePlugin: $topic is the name of another web $otherWeb."
            ) if TRACE;
            return "[[$otherWeb.WebHome][$otherWeb]]";
        }

        my $exist = Foswiki::Func::topicExists( $otherWeb, $topic );
        if ( !$exist ) {
            if ( !$disablePluralToSingular && $topic =~ /s$/ ) {
                my $topicSingular = _makeSingular($topic);
                if ( Foswiki::Func::topicExists( $otherWeb, $topicSingular ) ) {
                    Foswiki::Func::writeDebug(
"FindElsewherePlugin: $topicSingular was found in $otherWeb"
                    ) if TRACE;
                    push( @topicLinks, makeTopicLink( $otherWeb, $topic ) );
                }
            }
        }
        else {
            Foswiki::Func::writeDebug(
                "FindElsewherePlugin: $topic was found in $otherWeb")
              if TRACE;
            push( @topicLinks, makeTopicLink( $otherWeb, $topic ) );
        }
    }

    if ( scalar(@topicLinks) > 0 ) {
        if ( scalar(@topicLinks) == 1 ) {

            # Topic found in one place
            # If link text [[was in this form]], free it
            $linkText =~ s/\[\[(.*)\]\]/$1/o;

            # Link to topic
            $topicLinks[0] =~ s/(\[\[.*?\]\[)(.*?)(\]\])/$1$linkText$3/o;
            $linkedWords->{$topic} = $topicLinks[0];
            return $topicLinks[0];
        }
        else {

            # topic found in several places
            # If link text [[was in this form]] <em> it
            $linkText =~ s/\[\[(.*)\]\]/<em>$1<\/em>/go;

            # If $linkText is a WikiWord, prepend with <nop>
            # (prevent double links)
            $linkText =~ s/($Foswiki::regex{wikiWordRegex})/<nop\/>$1/go;
            my $renderedLink =
              "$linkText<sup>(" . join( ",", @topicLinks ) . ")</sup>";
            $linkedWords->{$topic} = $renderedLink;
            return $renderedLink;
        }
    }

    if ( exists( $Foswiki::cfg{FindElsewherePlugin}{CairoLegacyLinking} )
        && $Foswiki::cfg{FindElsewherePlugin}{CairoLegacyLinking} )
    {

        #pre-nested webs TWiki treated non-wikiwords more liberally
        #print STDERR "===( $web, $topic )\n";
        #replace space letter with uc(letter)
        #$topic =~ s/\s(\w)/uc($1)/ge;
        #remove all other non-wikiword links
        $topic =~ s/[^$Foswiki::regex{mixedAlphaNum}]//g;

        #test for existance
        #print STDERR "------ exists($web, $topic)\n";

        if ( Foswiki::Func::topicExists( $web, $topic ) ) {

            # Topic found in one place
            # If link text [[was in this form]], free it
            $linkText =~ s/\[\[(.*)\]\]/$1/o;

            #print STDERR "------==== >> [[$topic][$linkText]]\n";
            return "[[$topic][$linkText]]";
        }
    }

    return $original;
}

sub _makeSingular {
    my ($theWord) = @_;

    $theWord =~ s/ies$/y/o;          # plurals like policy / policies
    $theWord =~ s/sses$/ss/o;        # plurals like address / addresses
    $theWord =~ s/([Xx])es$/$1/o;    # plurals like box / boxes
    $theWord =~
      s/([A-Za-rt-z])s$/$1/o;    # others, excluding ending ss like address(es)
    return $theWord;
}

my $placeholderMarker = 0;

sub _takeOutBlocks {
    my ( $intext, $tag, $map ) = @_;

    return $intext unless ( $intext =~ m/<$tag\b/i );

    my $out   = '';
    my $depth = 0;
    my $scoop;
    my $tagParams;

    foreach my $token ( split /(<\/?$tag[^>]*>)/i, $intext ) {
        if ( $token =~ /<$tag\b([^>]*)?>/i ) {
            $depth++;
            if ( $depth eq 1 ) {
                $tagParams = $1;
                next;
            }
        }
        elsif ( $token =~ /<\/$tag>/i ) {
            if ( $depth > 0 ) {
                $depth--;
                if ( $depth eq 0 ) {
                    my $placeholder = $tag . $placeholderMarker;
                    $placeholderMarker++;
                    $map->{$placeholder}{text}   = $scoop;
                    $map->{$placeholder}{params} = $tagParams;
                    $out .= '<!--'
                      . $Foswiki::TranslationToken
                      . $placeholder
                      . $Foswiki::TranslationToken . '-->';
                    $scoop = '';
                    next;
                }
            }
        }
        if ( $depth > 0 ) {
            $scoop .= $token;
        }
        else {
            $out .= $token;
        }
    }

    # unmatched tags
    if ( defined($scoop) && ( $scoop ne '' ) ) {
        my $placeholder = $tag . $placeholderMarker;
        $placeholderMarker++;
        $map->{$placeholder}{text}   = $scoop;
        $map->{$placeholder}{params} = $tagParams;
        $out .= '<!--'
          . $Foswiki::TranslationToken
          . $placeholder
          . $Foswiki::TranslationToken . '-->';
    }

    return $out;
}

sub _putBackBlocks {
    my ( $text, $map, $tag, $newtag, $callback ) = @_;

    $newtag = $tag if ( !defined($newtag) );

    foreach my $placeholder ( keys %$map ) {
        if ( $placeholder =~ /^$tag\d+$/ ) {
            my $params = $map->{$placeholder}{params} || '';
            my $val = $map->{$placeholder}{text};
            $val = &$callback($val) if ( defined($callback) );
            if ( $newtag eq '' ) {
                $$text =~ s(<!--$Foswiki::TranslationToken$placeholder
                            $Foswiki::TranslationToken-->
                          )($val)x;
            }
            else {
                $$text =~ s(<!--$Foswiki::TranslationToken$placeholder
                            $Foswiki::TranslationToken-->
                          )(<$newtag$params>$val</$newtag>)x;
            }
            delete( $map->{$placeholder} );
        }
    }
}

1;
__END__
Copyright (C) 2002 Mike Barton, Marco Carnut, Peter HErnst
Copyright (C) 2003 Martin Cleaver
Copyright (C) 2004 Matt Wilkie
Copyright (C) 2007 Crawford Currie http://c-dot.co.uk
Copyright (C) 2008-2012 Foswiki Contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at 
http://www.gnu.org/copyleft/gpl.html

