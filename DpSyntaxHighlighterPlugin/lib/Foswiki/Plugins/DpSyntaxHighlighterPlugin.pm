# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007 - 2010 Andrew Jones, http://andrew-jones.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.

package Foswiki::Plugins::DpSyntaxHighlighterPlugin;
use strict;
use warnings;

use vars
  qw( $VERSION $RELEASE $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION $pluginName $rootDir $doneHead );

our $VERSION           = '$Rev$';
our $RELEASE           = '2.0';
our $pluginName        = 'DpSyntaxHighlighterPlugin';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION =
'Client side syntax highlighting using the [[http://code.google.com/p/syntaxhighlighter/][dp.SyntaxHighlighter]]';

sub initPlugin {

    $rootDir = Foswiki::Func::getPubUrlPath() . '/' .    # /pub/
      $Foswiki::cfg{SystemWebName} . '/' .               # System/
      $pluginName . '/' .    # DpSyntaxHighlighterPlugin
      'dp.SyntaxHighlighter';

    $doneHead = 0;

    # Plugin correctly initialized
    return 1;
}

sub commonTagsHandler {

    $_[0] =~ s/%CODE(?:_DP)?{(.*?)}%\s*(.*?)%ENDCODE%/&_handleTag($1, $2)/egs;

    return;
}

sub _addScript {
    my ( $tag, $text, $requires ) = @_;

    if (  !$Foswiki::cfg{Plugins}{ZonePlugin}{Enabled}
        && $Foswiki::Plugins::VERSION < 2.1 )
    {
        Foswiki::Func::addToHEAD( $tag, $text, $requires );
    }
    else {
        Foswiki::Func::addToZone( 'script', $tag, $text, $requires );
    }

    return;
}

sub _parseLang {
    my ($lang) = @_;

    if ($lang) {
        return 'AS3'        if ( $lang =~ /as3|actionscript3/ );
        return 'Css'        if ( $lang =~ /css/ );
        return 'Bash'       if ( $lang =~ /bash|shell/ );
        return 'CSharp'     if ( $lang =~ /c#|c-sharp|csharp/ );
        return 'Cpp'        if ( $lang =~ /^c$|cpp/ );
        return 'Vb'         if ( $lang =~ /vb|vbnet/ );
        return 'Delphi'     if ( $lang =~ /delphi|pascal/ );
        return 'Diff'       if ( $lang =~ /diff|patch/ );
        return 'Groovy'     if ( $lang =~ /groovy/ );
        return 'JScript'    if ( $lang =~ /js|jscript|javascript/ );
        return 'Java'       if ( $lang =~ /^java$/ );
        return 'JavaFX'     if ( $lang =~ /jfx|javafx/ );
        return 'Php'        if ( $lang =~ /php/ );
        return 'Perl'       if ( $lang =~ /^pl$|[Pp]erl/ );
        return 'Plain'      if ( $lang =~ /plain|text|ascii/ );
        return 'PowerShell' if ( $lang =~ /ps|powershell/ );
        return 'Python'     if ( $lang =~ /py|python/ );
        return 'Ruby'       if ( $lang =~ /ruby|ror|rails/ );
        return 'Scala'      if ( $lang =~ /scala/ );
        return 'Sql'        if ( $lang =~ /sql/ );
        return 'Xml'        if ( $lang =~ /xml|xhtml|xslt|html/ );
    }

    return '';
}

# handles the tag
sub _handleTag {
    my ( $rawParams, $code ) = @_;
    my %params = Foswiki::Func::extractParameters($rawParams);
    my $el = ( lc $params{el} eq 'textarea' ? 'textarea' : 'pre' );
    my $lang = lc $params{lang} || lc $params{_DEFAULT};    # language

    # start
    my $out = "<$el name='code' class='brush: $lang\;";

    # attributes
    $out .= " auto-links: false;" if lc $params{noautolinks} eq 'on';
    $out .= " gutter: false;"     if lc $params{nogutter}    eq 'on';
    $out .= " toolbar: false;"    if lc $params{nocontrols}  eq 'on';
    $out .= " collapse: true;"    if lc $params{collapse}    eq 'on';
    $out .= " first-line: $params{firstline};" if $params{firstline};
    $out .= " wrap-lines: false;"              if lc $params{nowrap} eq 'on';
    $out .= " ruler: true;"                    if lc $params{ruler} eq 'on';
    $out .= " smart-tabs: false;" if lc $params{nosmarttabs} eq 'on';
    $out .= " tab-size: $params{tabsize};" if $params{tabsize};
    $out .= " highlight: [$params{highlight}];" if $params{highlight};
    $out .= "'";

    if ( $el eq 'textarea' ) {

        # used to give sensible size if javascript not available
        $out .= " cols='$params{cols}'" if $params{cols};
        $out .= " rows='$params{rows}'" if $params{rows};
    }

    $out .= ">";

    # code
    $out .= "$code";

    # end
    $out .= "</$el>";

    # brush
    my $brush = _parseLang($lang);

    # language not found; return error
    return
"<span class='foswikiAlert'>$pluginName error: The language \"$lang\" is not supported.</span>"
      if $brush eq '';

#$out .= "<script type=\"text/javascript\" src='$rootDir/scripts/shBrush$brush.js'></script>";
    _addScript(
        $pluginName . '::LANG::' . $brush,
"<script type=\"text/javascript\" src='$rootDir/scripts/shBrush$brush.js'></script>",
        $pluginName . '::SCRIPT'
    );

    _doHead();

    return $out;
}

# adds styles and core js to head
sub _doHead {

    return if $doneHead;
    $doneHead = 1;

    # style sheet
    my $style =
"<link type='text/css' rel='stylesheet' href='$rootDir/styles/shCore.css' />";

    # CSS theme to use for output
    my $theme = Foswiki::Func::getPreferencesValue("\U$pluginName\_THEME")
      || 'Default';
    $style .=
"<link type='text/css' rel='stylesheet' href='$rootDir/styles/shTheme$theme.css' />";

    my $jsDefs = '';

    # Hide about/print buttons
    if (
        uc( Foswiki::Func::getPreferencesValue("\U$pluginName\_HIDE_ABOUT") ) eq
        'ON' )
    {
        $jsDefs .= "\n  delete SyntaxHighlighter.toolbar.items[\"about\"];";
    }
    if (
        uc( Foswiki::Func::getPreferencesValue("\U$pluginName\_HIDE_PRINT") ) eq
        'ON' )
    {
        $jsDefs .=
          "\n  delete SyntaxHighlighter.toolbar.items[\"printSource\"];";
    }

    # SyntaxHighlighter normally tries to guess the width of a space by
    # measuring it through javascript. When measuring, it appends the item
    # to the document.body, so font-size may not match the Foswiki theme.
    #
    # This allows an override in WebPreferences. The value is in pixels.
    #    Set DPSYNTAXHIGHLIGHTERPLUGIN_SPACEWIDTH = 8
    my $spaceWidth =
      Foswiki::Func::getPreferencesValue("\U$pluginName\_SPACEWIDTH");
    if ( defined $spaceWidth and $spaceWidth ne '' ) {
        $jsDefs .= "\n  SyntaxHighlighter.vars.spaceWidth = $spaceWidth;";
    }

    # core javascript file
    my $core =
"<script type=\"text/javascript\" src='$rootDir/scripts/shCore.js'></script>";

    my $script = <<"EOT";
<script type="text/javascript">
// use SyntaxHighlighter namespace
SyntaxHighlighter.render = function(){
  SyntaxHighlighter.config.clipboardSwf = '$rootDir/scripts/clipboard.swf';
  SyntaxHighlighter.config.tagName = 'pre';$jsDefs
  SyntaxHighlighter.highlight();
  SyntaxHighlighter.config.tagName = 'textarea';
  SyntaxHighlighter.highlight();
}
if (typeof jQuery != 'undefined') {
  // jQuery
  jQuery(document).ready(SyntaxHighlighter.render);
} else if (typeof YAHOO != "undefined") {
  // YUI
  YAHOO.util.Event.onDOMReady(SyntaxHighlighter.render);
} else if (typeof foswiki != "undefined"){
  // foswiki
  foswiki.Event.addLoadEvent(SyntaxHighlighter.render);
} else {
  alert("Can't add load event for $pluginName. Please contact your System Administrator.");
}
</script>
EOT

    Foswiki::Func::addToHEAD( $pluginName . '::STYLE', $style );
    _addScript( $pluginName . '::SCRIPT', $core . $script );

    return;
}

1;
