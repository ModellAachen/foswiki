#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional.
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# =========================
package TWiki::Plugins::PhantomPlugin;    # change the package name!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE

  $debug

  $WEBCONTENTTYPE

  %CUSTOM_VARS
  %CUSTOM_FORMAT
  %CUSTOM_CODE
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$VARS = 0;

# Loading formatters into hash, return hasp with loaded formatters
sub loadFormatters {
    my ($text) = @_;
    my %formatters = ( $text =~ m/%FORMAT:DEF{\"(.+?)\"}%(.*?)%FORMAT:END%/gs );
    my %loaded = ();
    foreach my $id ( sort( keys(%formatters) ) ) {
        my $formatDefinition = $formatters{$id};
        my ( $regexp, $substitution, $load, $allowoverlap );
        foreach my $line ( split( /\n+/, $formatDefinition ) ) {
            $line =~ s/\#.*?$//;
            $regexp = $1 if $line =~ /REGEXP\s*=\s*(.*?)\s*$/;
            $regexpignorecase = $1
              if $line =~ /REGEXPIGNORECASE\s*=\s*(.*?)\s*$/;
            $regexpmultiline = $1 if $line =~ /REGEXPMULTILINE\s*=\s*(.*?)\s*$/;
            $substitution    = $1 if $line =~ /SUBSTITUTION\s*=\s*(.*?)\s*$/;
            $load         = lc($1) if $line =~ /LOAD\s*=\s*(.*?)\s*$/;
            $allowoverlap = lc($1) if $line =~ /ALLOWOVERLAP\s*=\s*(.*?)\s*$/;
        }

        $regexpignorecase = "false"
          unless $regexpignorecase && $regexpignorecase =~ /^(true|false)$/;
        $regexpmultiline = "true"
          unless $regexpmultiline && $regexpmultiline =~ /^(true|false)$/;
        $load = "auto" unless $load && $load =~ /^(auto|manual)$/;
        $allowoverlap = "true"
          unless $allowoverlap && $allowoverlap =~ /^(true|false)$/;

        # Quoted REGEXP
        $regexp =~ s/^\"(.*?)\"$/$1/;
        my $formatter = {
            'REGEXP'           => $regexp,
            'REGEXPIGNORECASE' => $regexpignorecase eq "true",
            'REGEXPMULTILINE'  => $regexpmultiline eq "true",
            'SUBSTITUTION'     => $substitution,
            'ALLOWOVERLAP'     => $allowoverlap,
            'ENABLED'          => $load eq "auto"
        };

        # Formatter loaded
        &TWiki::Func::writeDebug(
            "- TWiki::Plugins::PhantomPlugin::loadFomatters() load: \"$id\"")
          if $debug;

        $loaded{$id} = $formatter;
    }
    return %loaded;
}

# Parse FORMAT:LOAD commands
sub enableFormatters() {
    my ( $hash, $text ) = @_;
    foreach my $id ( $text =~ m/%FORMAT:LOAD{\"(.+?)\"}%/gs ) {
        ${ ${$hash}{$id} }{'ENABLED'} = 1;
    }
}

# Parse FORMAT:DISABLE commands
sub disableFormatters() {
    my ( $hash, $text ) = @_;
    foreach my $id ( $text =~ m/%FORMAT:DISABLE{\"(.+?)\"}%/gs ) {
        ${ ${$hash}{$id} }{'ENABLED'} = 0;
    }
}

# Clear disabled formatters
sub validateFormatters() {
    my ($hash) = @_;
    foreach my $id ( keys( %{$hash} ) ) {
        unless ( ${ ${$hash}{$id} }{'ENABLED'} ) {
            &TWiki::Func::writeDebug(
"- TWiki::Plugins::PhantomPlugin::validateFomatters() unload: \"$id\""
            ) if $debug;
            delete ${$hash}{$id};
        }
    }
}

# Formating
sub formatText() {
    my ( $hash, $text ) = @_;

    # Regular expressions mathes supportd with follow
    my $surround = '<format:$id:$allowoverlap>$1<format:$id:$allowoverlap>';
    foreach my $id ( keys( %{$hash} ) ) {
        my $regexp           = ${ ${$hash}{$id} }{'REGEXP'};
        my $regexpFlags      = "g";
        my $regexpignorecase = ${ ${$hash}{$id} }{'REGEXPIGNORECASE'};
        my $regexpmultiline  = ${ ${$hash}{$id} }{'REGEXPMULTILINE'};
        my $substitution     = ${ ${$hash}{$id} }{'SUBSTITUTION'};
        my $allowoverlap     = ${ ${$hash}{$id} }{'ALLOWOVERLAP'};

        $regexpFlags .= "i" if $regexpignorecase;
        $regexpFlags .= "s" unless $regexpmultiline;
        my $re = "s/($regexp)/$surround/$regexpFlags";

        &TWiki::Func::writeDebug(
            "- TWiki::Plugins::PhantomPlugin::formatText() \"$id\" - $re")
          if $debug;

        eval( '$text =~ ' . $re );
        &TWiki::Func::writeDebug(
            "- TWiki::Plugins::PhantomPlugin::formatText() \"$id\" - $@")
          if $debug && $@;
    }

    # Disable nested formaters for allowoverlap="false"
    my @pairs = split( /(<format:.*?:false>)/, $text );
    $text = "";
    for ( my $i = 0 ; $i < scalar(@pairs) ; $i++ ) {
        my $pair = $pairs[$i];
        if ( $pair =~ /(<format:.*?:false>)/s ) {
            my $nextPair;
            my $j;
            for ( $j = $i + 1 ; $j < scalar(@pairs) ; $j++ ) {
                if ( $pair eq $pairs[$j] ) {
                    $nextPair = $pairs[$j];
                    last;
                }
            }

            # Find parentes?
            if ( $nextPair eq $pair ) {

                # All between it's two must be skiped
                my $k;
                $text .= $pair;
                for ( $k = $i + 1 ; $k < $j ; $k++ ) {
                    $pairs[$k] =~ s/<format:.*?>//sg;
                    $text .= $pairs[$k];
                }
                $text .= $nextPair;
                $i = $j;
            }
            else {

                # Ignoring
            }
        }
        else {
            $text .= $pair;
        }
    }

    # For debug
    #return $text;
    # Apply formatting
    while ( $text =~ /<(format:(.*?):.*?)>(.*?)<\1>/s ) {
        my $pre              = $`;
        my $post             = $';
        my $id               = $2;
        my $part             = $3;
        my $regexp           = ${ ${$hash}{$id} }{'REGEXP'};
        my $regexpFlags      = "g";
        my $regexpignorecase = ${ ${$hash}{$id} }{'REGEXPIGNORECASE'};
        my $regexpmultiline  = ${ ${$hash}{$id} }{'REGEXPMULTILINE'};
        my $substitution     = ${ ${$hash}{$id} }{'SUBSTITUTION'};

        $regexpFlags .= "i" if ($regexpignorecase);
        $regexpFlags .= "s" unless ($regexpmultiline);
        my $re = "s/$regexp/$substitution/$regexpFlags";

        eval( '$part =~ ' . $re );
        &TWiki::Func::writeDebug(
            "- TWiki::Plugins::PhantomPlugin::formatText() \"$id\" - $@")
          if $debug && $@;
        last if ($@);
        $text = "$pre$part$post";
    }

    # Disable partial formats
    $text =~ s/<\/?format:.*?:.*?>//gs;
    return $text;
}

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between EmptyPlugin and Plugins.pm");
        return 0;
    }

    # Plugin correctly initialized

    my ( $meta, $text ) = &TWiki::Func::readTopic( $web, $topic );
    my $query = &TWiki::Func::getCgiQuery();

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("PHANTOMPLUGIN_DEBUG");

    $WEBCONTENTTYPE =
      &TWiki::Func::getPreferencesValue("PHANTOMPLUGIN_WEBCONTENTTYPE")
      || "text/html";

    # Follow parameter used in bin/view script
    $query->param( "contenttype", $WEBCONTENTTYPE );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "-" x 80 ) if $debug;
    &TWiki::Func::writeDebug(
        "TWiki::Plugins::PhantomPlugin::initPlugin( $web.$topic )")
      if $debug;

    my $globalText = "";
    my $globalMeta = "";

    # Parse custom variables declarations to hash
    # Syntax: %VAR:DEF{"name"}% value %VAR:END%
    if ( &TWiki::Func::topicExists( $installWeb, "PhantomPluginVariables" ) ) {
        ( $globalMeta, $globalText ) =
          &TWiki::Func::readTopic( $installWeb, "PhantomPluginVariables" );
    }
    %CUSTOM_VARS =
      ( "$text$globalText" =~ m/%VAR:DEF{\"(.+?)\"}%(.*?)%VAR:END%/gs );

    if ( $debug && %CUSTOM_VARS ) {
        &TWiki::Func::writeDebug(
"- TWiki::Plugins::PhantomPlugin::initPlugin( $web.$topic ) - Loaded variables:"
        );
        foreach $key ( keys(%CUSTOM_VARS) ) {
            &TWiki::Func::writeDebug(
"- TWiki::Plugins::PhantomPlugin::initPlugin( $web.$topic ) - %VAR:DEF{\"$key\"}%$CUSTOM_VARS{$key}%VAR:END%"
            );
        }
    }

    # Parse custom formatters declarations to hash
    if ( &TWiki::Func::topicExists( $installWeb, "PhantomPluginFormatters" ) ) {
        ( $globalMeta, $globalText ) =
          &TWiki::Func::readTopic( $installWeb, "PhantomPluginFormatters" );
    }
    %CUSTOM_FORMAT = &loadFormatters($globalText);
    &enableFormatters( \%CUSTOM_FORMAT, "$text$globalText" );
    &disableFormatters( \%CUSTOM_FORMAT, "$text$globalText" );
    &validateFormatters( \%CUSTOM_FORMAT );

    # Parse custom code highlighters to hash
    if ( &TWiki::Func::topicExists( $installWeb, "PhantomHighlighters" ) ) {
        ( $globalMeta, $globalText ) =
          &TWiki::Func::readTopic( $installWeb, "PhantomHighlighters" );
    }
    if ( $globalText =~ /\t+\*\sSet\sHIGHLIGHTERS\s\=\s*(.*)/g ) {
        my @highlighterTopics = split( /[, ]+/, $1 );
        foreach $hlTopic (@highlighterTopics) {
            if ( &TWiki::Func::topicExists( $installWeb, $hlTopic ) ) {
                &TWiki::Func::writeDebug(
"- TWiki::Plugins::PhantomPlugin::initPlugin( $web.$topic ) - Load highlighter $hlTopic"
                ) if $debug;

                ( $globalMeta, $globalText ) =
                  &TWiki::Func::readTopic( $installWeb, $hlTopic );
                if ( $globalText =~ /%CODE:DEF{\"(.+?)\"}%(.*?)%CODE:END%/gs ) {
                    my $name = $1;
                    $globalText = $2;

                    my %FORMATTERS = &loadFormatters($globalText);
                    &enableFormatters( \%FORMATTERS, "$text$globalText" );
                    &disableFormatters( \%FORMATTERS, "$text$globalText" );
                    &validateFormatters( \%FORMATTERS );

                    $CUSTOM_CODE{$name} = \%FORMATTERS;
                }
            }
            elsif ($debug) {
                &TWiki::Func::writeDebug(
"- TWiki::Plugins::PhantomPlugin::initPlugin( $web.$topic ) - Highlighter topic not found $hlTopic"
                );
            }
        }
    }

    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    # Sometimes text is empty
    return unless $_[0];

    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::PhantomPlugin::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # HTML and HTTP settings
    $_[0] =~ s/%WEBCONTENTTYPE%/$WEBCONTENTTYPE/geo;

    # Perform text processing only for topic content,
    # variable %TEXT% must not be present in text

    unless ( $_[0] =~ /%TEXT%/ ) {

        # Clean up declarations from text
        $_[0] =~
s/(%VAR:DEF{\".+?\"}%.*?%VAR:END%)\s+(%VAR:DEF{\".+?\"}%.*?%VAR:END%)/$1$2/gs;
        $_[0] =~ s/%VAR:DEF{\".+?\"}%.*?%VAR:END%//gso;

        # Print variables value
        $_[0] =~ s/%VAR:P{\"(.+?)\"}%/&getVarValue($1)/geo;

        # Clean up declarations from text
        $_[0] =~
s/(%FORMAT:DEF{\".+?\"}%.*?%FORMAT:END%)\s+(%FORMAT:DEF{\".+?\"}%.*?%FORMAT:END%)/$1$2/gs;
        $_[0] =~ s/%FORMAT:DEF{\".+?\"}%.*?%FORMAT:END%//gso;

        # Code formating
        $_[0] = &formatText( \%CUSTOM_FORMAT, $_[0] );

        # Language hightlighting
        if (%CUSTOM_CODE) {
            foreach $codeName ( keys(%CUSTOM_CODE) ) {
                while ( $_[0] =~ /%CODE:$codeName%(.*?)%CODE:END%/si ) {
                    my $code = $1;

                    my $FORMATTERS = $CUSTOM_CODE{$codeName};

                    # Prevent from TWiki words highlighting
                    $code =~ s/\t/  /sg;
                    $code =~ s/ /&nbsp;/sg;

                    # Formating
                    $code = &formatText( $FORMATTERS, $code );

                    # Formating LF
                    $code =~ s/\n/<br>/sg;

                    # Preformat code
                    $_[0] =~
s/%CODE:$codeName%.*?%CODE:END%/<pre class=\"code\">$code<\/pre>/si;
                }
            }
        }
    }

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/geo;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/geo;
}

# Method return variable value. If debug flag is on and
# variable does not match print error message
sub getVarValue {

    if ( exists( $CUSTOM_VARS{ $_[0] } ) ) {
        return $CUSTOM_VARS{ $_[0] };
    }
    elsif ($debug) {
        &TWiki::Func::writeDebug(
"- TWiki::Plugins::PhantomPlugin::getVarValue( $web.$topic ) - Warning: Variable $_[0] not defined"
        ) if $debug;
    }

    return "";
}

1;
