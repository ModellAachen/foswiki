# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2011 Will Norris
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
###############################################################################

package Foswiki::Plugins::MathJaxPlugin::Core;

use strict;

use constant DEBUG => 0;    # toggle me

###############################################################################
# static
sub writeDebug {

    #&Foswiki::Func::writeDebug('- MathJaxPlugin - '.$_[0]) if DEBUG;
    print STDERR '- MathJaxPlugin - ' . $_[0] . "\n" if DEBUG;
}

###############################################################################
sub new {
    my $class = shift;

    my $this = {
        hashedMathStrings => {},

        # contains the math strings, indexed by their hash code

        fgColors => {},

        # contains the foreground color of a math string

        bgColor => {},

        # contains the background color for all formulas

        sizes => {},

       # font size of a math string, can be; can be
       # tiny, scriptsize, footnotesize, small, normalsize, large, Large, LARGE,
       # huge or Huge

        scaleFactor => $Foswiki::cfg{MathJaxPlugin}{ScaleFactor} || 1.2,

        # factor to scale images;
        # may be overridden by a LATEXSCALEFACTOR preference variable

        latexFGColor => $Foswiki::cfg{MathJaxPlugin}{LatexFGColor} || 'black',

        # default text color

        latexBGColor => $Foswiki::cfg{MathJaxPlugin}{LatexBGColor} || 'white',

        # default background color

        latexFontSize => $Foswiki::cfg{MathJaxPlugin}{LatexFontSize}
          || 'normalsize',

        # default text color

        @_
    };

    return bless( $this, $class );
}

###############################################################################
# delayed initialization
sub init {
    my ( $this, $web, $topic ) = @_;

    # prevent a doubled invokation
    return if $this->{isInitialized};
    $this->{isInitialized} = 1;

    # get preverences
    my $value = Foswiki::Func::getPreferencesValue('LATEXSCALEFACTOR');
    $this->{scaleFactor} = $value if $value;

    $value = Foswiki::Func::getPreferencesValue('LATEXIMAGETYPE');
    $this->{imageType} = $value if $value;
    $this->{imageType} = 'png' unless $this->{imageType} =~ /^(png|gif)$/i;

    $value = Foswiki::Func::getPreferencesValue('LATEXPREAMBLE');
    $this->{latexPreamble} = $value if $value;

    $value = Foswiki::Func::getPreferencesValue('LATEXBGCOLOR');
    $this->{latexBGColor} = $value if $value;

    $value = Foswiki::Func::getPreferencesValue('LATEXFGCOLOR');
    $this->{latexFGColor} = $value if $value;

    $value = Foswiki::Func::getPreferencesValue('LATEXFONTSIZE');
    $this->{latexFontSize} = $value if $value;

}

###############################################################################
# This function takes a string of math and wrap in the appropriate markup for MathJax
sub handleMath {
    my ( $this, $web, $topic, $text, $inlineFlag, $args ) = @_;

    # store the string in a hash table, indexed by the MD5 hash
    $text =~ s/^\s+//go;
    $text =~ s/\s+$//go;

    # extract latex options
    $args ||= '';
    require Foswiki::Attrs;
    my $params = new Foswiki::Attrs($args);
    $this->{fgColors}{$text} = $params->{color} || $this->{latexFGColor};
    $this->{bgColor} = $params->{bgcolor} || $this->{latexBGColor};

    my $size = $params->{size} || '';
    $this->{sizes}{$text} = $size if $size;

    Foswiki::Func::addToZone( 'head', 'MATHJAX_PLUGIN', <<__SCRIPT__ );
<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/MathJaxPlugin/MathJax/MathJax.js">
    MathJax.Hub.Config({
        jax: ["input/TeX", "output/HTML-CSS"],
        delayStartupUntil: "onload"
    });
</script>
__SCRIPT__

    my $result =
        '<noautolink><script type="math/tex">' 
      . $text
      . "</script></noautolink>\n";
    return $result;
}

###############################################################################
# returns the arguments to the latex commands \color or \pagecolor
sub formatColorSpec {
    my $color = shift;

    # try to auto-detect the color spec
    return "{$color}"       if $color =~ /^[a-zA-Z]+$/;         # named
    return "[HTML]{$color}" if $color =~ /^[a-fA-F0-9]{6}$/;    # named
    return "$color";
}

1;
