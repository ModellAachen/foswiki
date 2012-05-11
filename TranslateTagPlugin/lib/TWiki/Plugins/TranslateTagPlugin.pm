#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
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
# =========================
#
# This plugin allows the automatic translation of TAGS from/to English
# at edit/save time
#
# Define your translations in Plugins.TagTranslations topic as follows:
# | TAG.option.param | TRANSLATED.tr_option.tr_param | <lang> |
#
# e.g.:
# | SEARCH.format.topic | CERCA.formato.pagina | it |
#
# =========================

package TWiki::Plugins::TranslateTagPlugin;

# =========================
# use strict;
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug $pluginName
  $translationTopic %translations %reverseTrans
  $syntaxTag
);

$VERSION          = '$Rev$';
$pluginName       = 'TranslateTagPlugin';     # this plugin name
%translations     = ();                       # mapping english -> translated
%reverseTrans     = ();                       # mapping translated -> english
$translationTopic = 'TagTranslations';        # topic containing the table
$syntaxTag        = qr /([A-Z_]+(\.\w+)*)/;

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.002 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between \Q$pluginName\E and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::\Q$pluginName\E::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub beforeEditHandler {
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &TWiki::Func::writeDebug("- \Q$pluginName\E::beforeEditHandler( $_[1] )")
      if $debug;

    &parseTranslations;

    $_[0] =~ s/%([A-Z]+)%/&translateTag(\%translations,$1)/ge;
    $_[0] =~ s/%([A-Z]+)\{(.*)\}%/&translateTag(\%translations,$1,$2)/ge;
}

# =========================
sub afterEditHandler {
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &TWiki::Func::writeDebug("- \Q$pluginName\E::afterEditHandler( $_[1] )")
      if $debug;

    &parseTranslations;

    $_[0] =~ s/%([A-Z]+)%/&translateTag(\%reverseTrans,$1)/ge;
    $_[0] =~ s/%([A-Z]+)\{(.*)\}%/&translateTag(\%reverseTrans,$1,$2)/ge;
}

# =========================
sub translateTag {

    # parameters: $translation, TAG, options
    my $THash = shift;
    my $t     = shift;
    my $op    = shift;

    my %trans = %{$THash};

    my $tt = $trans{$t}{'-TAG-'};

    if ( !defined($tt) ) {
        return "%$t\{$op\}%" if defined($op);
        return "%$t%";
    }
    return "%$tt%" if !defined($op);

    my ( $opt, $parm, $to, $tp );
    foreach $opt ( keys %{ $trans{$t} } ) {
        $to = $trans{$t}{$opt}{'-TAG-'};
        $op =~ s/(\s*)\b$opt(=".*"\s*)/$1$to$2/g;
        foreach $parm ( keys %{ $trans{$t}{$opt} } ) {
            $tp = $trans{$t}{$opt}{$parm};
            $op =~ s/(\s*\b$to=\".*)\$$parm(.*\"\s*)/$1\$$tp$2/g;
        }
    }
    return "%$tt\{$op\}%";
}

# =========================
sub parseTranslations {

    # Get TOPIC preference
    $translationTopic =
      &TWiki::Func::getPreferencesValue("\U$pluginName\E_TOPIC")
      || "$installWeb.$translationTopic";

    my ( $w, $t ) = ( $installWeb, $translationTopic );
    if ( $translationTopic =~ /^([a-zA-Z]+)\.([a-zA-Z]+)$/ ) {
        ( $w, $t ) = ( $1, $2 );
    }
    elsif ( $translationTopic =~ /^([a-zA-Z]+)$/ ) {
        ( $w, $t ) = ( $installWeb, $1 );
    }

    # stop here if the translation topic does not exists
    if ( !&TWiki::Func::topicExists( $w, $t ) ) {
        &TWiki::Func::writeWarning("Missing translation TOPIC for $pluginName");
        return;
    }

    # Get LANG preference from the web preferences OR the Plugin topic
    my $lang =
         &TWiki::Func::getPreferencesValue("LANG")
      || &TWiki::Func::getPreferencesValue("\U$pluginName\E_LANG")
      || 'en';    # fall back on English

    # untaint $lang
    if ( $lang =~ /^\s*(\w+)\s*$/ ) {
        $lang = qr /$1/i;
    }
    else {

        # invalid language
        &TWiki::Func::writeWarning(
            "Invalid LANG setting for $pluginName (found '$lang')");
        return;
    }

    # read/parse translations
    my $text = &TWiki::Func::readTopic( $w, $t );
    my %trans = map {
        /^\|\s*$syntaxTag\s*\|\s*$syntaxTag\s*\|\s*$lang\s*|\s$/;
        ( $1, $3 )
      }
      grep { /^\|\s*$syntaxTag\s*\|\s*$syntaxTag\s*\|\s*$lang\s*|\s$/ }
      split( "[\n\r]+", $text );

    my ( $tag, $rtag, $opt, $ropt, $var, $rvar );
    while ( ( $k, $v ) = each %trans ) {
        if ( $k =~ /^([A-Z_]+)$/ && $v =~ /^([A-Z_]+)$/ ) {
            $translations{$k}{'-TAG-'} = $v;
            $reverseTrans{$v}{'-TAG-'} = $k;
        }
        elsif ( $k =~ /^([A-Z_]+)\.(\w+)$/ ) {
            ( $tag, $opt ) = ( $1, $2 );
            if ( $v =~ /^([A-Z_]+)\.(\w+)$/ ) {
                $translations{$tag}{'-TAG-'}       = $1;
                $reverseTrans{$1}{'-TAG-'}         = $tag;
                $translations{$tag}{$opt}{'-TAG-'} = $2;
                $reverseTrans{$1}{$2}{'-TAG-'}     = $opt;
            }

        }
        elsif ( $k =~ /^([A-Z_]+)\.(\w+)\.(\w+)$/ ) {
            ( $tag, $opt, $parm ) = ( $1, $2, $3 );
            if ( $v =~ /^([A-Z_]+)\.(\w+)\.(\w+)$/ ) {
                $translations{$tag}{'-TAG-'}       = $1;
                $reverseTrans{$1}{'-TAG-'}         = $tag;
                $translations{$tag}{$opt}{'-TAG-'} = $2;
                $reverseTrans{$1}{$2}{'-TAG-'}     = $opt;
                $translations{$tag}{$opt}{$parm}   = $3;
                $reverseTrans{$1}{$2}{$3}          = $parm;
            }
        }
    }
}

1;

