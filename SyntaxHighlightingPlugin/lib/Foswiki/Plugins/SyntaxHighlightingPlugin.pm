# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 - 2009 Andrew Jones, andrewjones86@gmail.com
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
# This was the Syntax Highlighting TWiki plugin, now forked for Foswiki
# originally written by
# Nicolas Tisserand (tisser_n@epita.fr), Nicolas Burrus (burrus_n@epita.fr)
# and Perceval Anichini (anichi_p@epita.fr)
# Current version by Andrew Jones (andrewjones86@gmail.com)
#
# It uses enscript as syntax highlighter.
#
# Use it in your by writing %CODE{"language"}% ... %ENDCODE%
# with language = ada asm awk bash c changelog c++ csh delphi diff diffs diffu elisp fortran fortran_pp haskell html idl inf java javascript
# ksh m4 mail makefile maple matlab modula_2 nested nroff objc outline pascal perl postscript python rfc scheme sh skill sql states synopsys
# tcl tcsh tex vba verilog vhdl vrml wmlscript zsh

package Foswiki::Plugins::SyntaxHighlightingPlugin;
use strict;

use IPC::Run qw( run );

use vars qw(    $VERSION
  $RELEASE
  $NO_PREFS_IN_TOPIC
  $SHORTDESCRIPTION
  $pluginName
  %langs
);
our $VERSION = '$Rev$';
our $RELEASE = '1.21';
our $SHORTDESCRIPTION =
  'Highlights code fragments for many languages using ==enscript==.';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName        = 'SyntaxHighlightingPlugin';

our %langs = (
    "ada"        => "ada",
    "asm"        => "asm",
    "awk"        => "awk",
    "bash"       => "bash",
    "c"          => "c",
    "changelog"  => "changelog",
    "cpp"        => "cpp",
    "c++"        => "cpp",
    "csh"        => "csh",
    "delphi"     => "delphi",
    "diff"       => "diff",
    "diffs"      => "diffs",
    "diffu"      => "diffu",
    "elisp"      => "elisp",
    "fortran"    => "fortran",
    "fortran_pp" => "fortran_pp",
    "haskell"    => "haskell",
    "html"       => "html",
    "idl"        => "idl",
    "inf"        => "inf",
    "java"       => "java",
    "javascript" => "javascript",
    "ksh"        => "ksh",
    "m4"         => "m4",
    "mail"       => "mail",
    "makefile"   => "makefile",
    "maple"      => "maple",
    "matlab"     => "matlab",
    "modula_2"   => "modula_2",
    "nested"     => "nested",
    "nroff"      => "nroff",
    "objc"       => "objc",
    "outline"    => "outline",
    "pascal"     => "pascal",
    "perl"       => "perl",
    "postscript" => "postscript",
    "python"     => "python",
    "rfc"        => "rfc",
    "scheme"     => "scheme",
    "sh"         => "sh",
    "skill"      => "skill",
    "sql"        => "sql",
    "states"     => "states",
    "synopsys"   => "synopsys",
    "tcl"        => "tcl",
    "tcsh"       => "tcsh",
    "tex"        => "tex",
    "tiger"      => "tiger",
    "vba"        => "vba",
    "verilog"    => "verilog",
    "vhdl"       => "vhdl",
    "vrml"       => "vrml",
    "wmlscript"  => "wmlscript",
    "zsh"        => "zsh"
);

# =========================

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # Plugin correctly initialized
    _Debug("initPlugin( $web.$topic ) is OK");

    return 1;
}

sub commonTagsHandler {

    $_[0] =~ s/%CODE(?:_ENSCRIPT)?{(.*?)}%\s*(.*?)%ENDCODE%/&_handleTag/egs;

}

# =========================

sub _handleTag {

    my %params = Foswiki::Func::extractParameters($1);
    my $lang = lc $params{lang} || lc $params{_DEFAULT};    # language
    my $num =
         lc $params{num}
      || lc $params{number}
      || lc $params{numbered};    # start line number
    my $code = $2;                # code to highlight

    unless ( _definedLang($lang) ) {
        return _returnError(
"Language is either undefined or unsupported. Check %SYSTEMWEB%.$pluginName for more information."
        );
    }

    my $highlighted = _highlight( $code, $lang );

    if ( $highlighted =~ s/.*\<PRE\>\n(.*?)\n?\<\/PRE\>.*/$1/os ) {
        if ($num) {
            my $line = $num;
            $highlighted =~
s/(^.*)/sprintf("<b><font color=\"#000000\">%5d<\/font><\/b>\t%s", $line++, $1)/mgeo;
        }
        my $out = "<!-- !$pluginName -->";
        $out .= "<pre class='syntaxHighlightingPlugin'>$highlighted</pre>";
        $out .= "<!-- end !$pluginName -->";
        return $out;
    }
    else {
        _Warn(
'Error with enscript while highlighting. Check its installed correctly and the path is correct'
        );
        _returnError(
            'Internal error. Notify you administrator at %WIKIWEBMASTER%.');
    }
}

# =========================

# runs enscript to highlight the code
sub _highlight {
    my ( $code, $lang ) = @_;

    my $enscript = $Foswiki::cfg{Plugins}{$pluginName}{EnscriptPath}
      || 'enscript';

    my @cmd;
    push @cmd, $enscript;
    push @cmd, qw( --color --language=html --output - --silent);
    push @cmd, "--highlight=$langs{lc($lang)}";
    my $out = '';

    # FIXME: Should we use Foswiki::Sandbox instead?
    run \@cmd, \$code, \$out;

    return $out;
}

# checks the language is supported
sub _definedLang {

    my ($lang) = @_;

    if ( exists $langs{ lc( $_[0] ) } ) {
        return 1;
    }
    else {
        return 0;
    }
}

# =========================

# output an error to screen
sub _returnError {
    my ($text) = @_;

    my $out = '<span class="foswikiAlert">';
    $out .= "%SYSTEMWEB%.$pluginName - $text";
    $out .= '</span>';

    return $out;
}

# =========================

sub _Debug {
    my $text = shift;
    my $debug = $Foswiki::cfg{Plugins}{$pluginName}{Debug} || 0;
    Foswiki::Func::writeDebug("- Foswiki::Plugins::${pluginName}: $text")
      if $debug;
}

sub _Warn {
    my $text = shift;
    Foswiki::Func::writeWarning("- Foswiki::Plugins::${pluginName}: $text");
}

1;
