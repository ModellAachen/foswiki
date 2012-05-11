#
# Copyright (C) 2001 Andrea Sterbini, a.sterbini@flashnet.it
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
# http://www.gnu.ai.mit.edu/copyleft/gpl.html
#
# =========================
#
# This plugin finds all group of words that could be joined to
# link to an existing topic.
#
# E.g. if a topic named ANiceTopic exists then
#	"topic is nice" is hilighted
#
# The rationale is that you often dont' know that there is some
# topic speaking of something you are writing about, and that
# probably you would like to link it.
#
# This is probably useful only during Preview.
#
# =========================
# Implementation:
# 1: get all topic names in this web
# 2: for all topic names:
#   2a: split the topic name in words
#   2b: remove stop words (articles ...)
#   2c: transform words to "(singular|plural)"
#   2d: for all permutations
#	3a: look for a pattern with the current permutation spaced with
#	    at most 2 words (and not containing commas, colons, stops etc)
#
# =========================
package TWiki::Plugins::SuggestLinksPlugin;

# =========================
use vars qw( $web $topic $user $installWeb
  %allTopicNamePatterns
  $stopWords $format1 $format2
  $maxWords $selectedWeb );

# we filter single characters, articles ...
# $stopWords = qr /[a-zA-Z0-9]|an|the|and|or|not|to|for/i ;

# we admit at most 4! = 24 permutations for word
$maxWords = 4;

# use List::Permutor; # lazy load
# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    my $query = &TWiki::Func::getCgiQuery();
    if ( !$query ) { return 0; }

    # see if they want me
    my $yn = $query->param('suggestions') || 'off';
    if ( $yn ne 'on' ) { return 0; }

    # see if List::Permutor is present
    eval 'require List::Permutor';
    if ( !defined $List::Permutor::VERSION ) {
        &TWiki::Func::writeWarning(
            'SuggestLinksPlugin init failed: missing List::Permutor');
        return 0;
    }

    # from where should we get the topic names?
    $selectedWeb = $query->param('suggestionsWeb') || $web;

    # how long can be the patterns?
    $maxWords = scalar( $query->param('suggestionsLength') || '4' );
    if ( $maxWords > 6 ) {
        $maxWords = 6;
    }

    $stopWords =
      &TWiki::Func::getPreferencesValue('SUGGESTLINKSPLUGIN_STOPWORDS')
      || '[:lower:]';
    $stopWords =~ s/[,\s]+/|/go;
    $stopwords =~ s/\|+/\|/go;
    $stopWords = qr /$stopWords/i;

    $format1 = &TWiki::Func::getPreferencesValue('SUGGESTLINKSPLUGIN_FORMAT1')
      || "<SPAN STYLE=\"background : yellow;\">";
    $format2 = &TWiki::Func::getPreferencesValue('SUGGESTLINKSPLUGIN_FORMAT2')
      || "<\/SPAN><img src=\"%PUBURLPATH%\/$installWeb\/SuggestLinksPlugin\/exclam.gif\" alt=\"\$web.\$topic\">";

    foreach $name ( &TWiki::Func::getTopicList( $selectedWeb, $user ) ) {
        my $pats = &getAllPatterns($name);
        $allTopicNamePatterns{$name} = $pats;
    }

    return 1;
}

# =========================
#sub outsidePREPreviewHandler
sub commonTagsHandler {

    #    my ( $text, $topic, $web ) = @_;
    while ( ( $name, $patterns ) = each %allTopicNamePatterns ) {
        foreach $pattern ( @{$patterns} ) {
            my ( $f1, $f2 ) = ( "$format1", "$format2" );
            $f1   =~ s/\$topic/$name/g;
            $f2   =~ s/\$topic/$name/g;
            $f1   =~ s/\$web/$selectedWeb/go;
            $f2   =~ s/\$web/$selectedWeb/go;
            $_[0] =~ s/$pattern/$1$f1$2$f2/gi;
        }
    }
}

# =========================
sub getAllPatterns {
    my ( $name, $web ) = @_;

    my $words = $name;
    $words =~ s/([A-Z][a-z])/ $1/go;
    my @words = split( " ", $words );

    # we filter out stopwords (articles ...)
    @words = grep { !/^$stopWords$/i } @words;

    # we never admit more than 6 words (6! = 720 permutations)
    my $theMax = ( $maxWords < 7 ) ? $maxWords : 6;

    # we limit list size
    if ( scalar(@words) > $theMax ) {

        #FIXME: should we truncate instead than returning null?
        return ();
    }

    #FIXME: are the plurals correct?
    map {

        # plural --> plural|singular
        $_ =~ s/^(([^|]+)ies)$/$1|$2y/o;
        $_ =~ s/^(([^|]+)sses)$/$1|$2ss/o;
        $_ =~ s/^(([^|]+)xes)$/$1|$2x/o;
        $_ =~ s/^(([^|]*[^|s])s)$/$1|$2/o;

        # singular --> singular|plural
        $_ =~ s/^(([^|]+)y)$/$1|$2ies/o;
        $_ =~ s/^(([^|]+)ss)$/$1|$2sses/o;
        $_ =~ s/^(([^|]+)x)$/$1|$2xes/o;
        $_ =~ s/^([^|]*[^|s])$/$1|$1s/o;
    } @words;

    return &getAllPermPatterns(@words);
}

# =========================
sub getAllPermPatterns {
    my $perm = new List::Permutor @_;
    my @pats = ();
    my $pat  = "";
    while ( my @set = $perm->next ) {

     #we look  for permutations interspersed with at most 2 words here and there
        $pat =
            '([\s\.\,\:\!\?^])(('
          . join( ')\s+([a-zA-Z0-9]+\s+)?([a-zA-Z0-9]+\s+)?(', @set )
          . ')[\s\.\,\:\!\?$])';

        # we want them caseless
        push @pats, qr /$pat/i;
    }
    return \@pats;
}

1;

