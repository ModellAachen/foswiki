# InterwikiPreviewPlugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# See bottom of file for license and copyright information

=pod

---+ package Foswiki::Plugins::InterwikiPreviewPlugin

=cut

package Foswiki::Plugins::InterwikiPreviewPlugin;

use strict;
use warnings;
use Foswiki::Plugins::InterwikiPreviewPlugin::Rule;
use Foswiki::Plugins::InterwikiPreviewPlugin::Query;
use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

use vars qw(
  $debug $web $topic $user $installWeb $pluginName $prefixPattern $upperAlpha
  $mixedAlphaNum $sitePattern $pagePattern $postfixPattern);

our $VERSION = '$Rev: 9771 $';
our $RELEASE = '2.0.0';
our $SHORTDESCRIPTION =
'Display extra information (using AJAX) next to ==ExternalSite:Page== links, based on rules defined in the InterWikiPreviews topic. Best used in conjunction with InterwikiPlugin.';
our $NO_PREFS_IN_TOPIC = 1;

$pluginName = 'InterwikiPreviewPlugin';

BEGIN {

    # 'Use locale' for internationalisation of Perl sorting and searching -
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Regexes for the Site:page format InterWiki reference - updated to support
# 8-bit characters in both parts - see Codev.InternationalisationEnhancements
$prefixPattern = '(^|[\s\-\*\(])';
$upperAlpha    = $Foswiki::regex{upperAlpha};
$mixedAlphaNum = $Foswiki::regex{mixedAlphaNum};
$sitePattern   = "([${upperAlpha}][${mixedAlphaNum}]+)";
$pagePattern =
  "([${mixedAlphaNum}_\/][${mixedAlphaNum}" . '\+\_\.\,\;\:\!\?\/\%\#-]+?)';
$postfixPattern = '(?=[\s\.\,\;\:\!\?\)]*(\s|$))';

sub _trimWhitespace {
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Get plugin debug flag
    $debug = $Foswiki::cfg{Plugins}{InterwikiPreviewPlugin}{Debug} || 0;

    if ($debug) {
        Foswiki::Plugins::InterwikiPreviewPlugin::Rule::enableDebug();
        Foswiki::Plugins::InterwikiPreviewPlugin::Query::enableDebug();
    }

    Foswiki::Plugins::InterwikiPreviewPlugin::Rule::reset();
    Foswiki::Plugins::InterwikiPreviewPlugin::Query::reset();

    # Get rules topic(s)
    my $rulesTopicPref =
      $Foswiki::cfg{Plugins}{InterwikiPreviewPlugin}{RulesTopic}
      || 'InterwikiPreviews';

    my @rulesTopics = split( ',', $rulesTopicPref );
    foreach my $rulesTopic (@rulesTopics) {
        $rulesTopic = _trimWhitespace($rulesTopic);

        Foswiki::Func::writeDebug(
            "- ${pluginName}::initPlugin, rules topic: ${rulesTopic}")
          if $debug;

        my ( $interWeb, $interTopic ) =
          Foswiki::Func::normalizeWebTopicName( $installWeb, $rulesTopic );

        if (
            !Foswiki::Func::checkAccessPermission(
                'VIEW', $user, undef, $interTopic, $interWeb
            )
          )
        {
            Foswiki::Func::writeWarning(
"- ${pluginName}: user '$user' did not have permission to read the rules topic at '$interWeb.$interTopic'"
            );
            return 1;
        }
        my $data =
          Foswiki::Func::readTopicText( $interWeb, $interTopic, undef, 1 );
        $data =~
s/^\|\s*$sitePattern\s*\|\s*(.+?)\s*\|\s*([${mixedAlphaNum}]+)\s*\|\s*(.+?)\s*\|\s*(\d+)\s*\|$/newRule($1,$2,$3,$4,$5)/geom;
    }

    # Plugin correctly initialized
    Foswiki::Func::writeDebug(
        "- ${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub newRule {

    #    my ( $alias, $url, $format, $info, $reload ) = @_;

    Foswiki::Func::writeDebug("- ${pluginName}::newRule") if $debug;

    my $rule = Foswiki::Plugins::InterwikiPreviewPlugin::Rule->new(@_);

    if ( defined $rule ) {

        # Proxy query via REST interface
        Foswiki::Func::registerRESTHandler(
            $_[0],
            sub { return $rule->restHandler( $_[0], $_[1], $_[2] ); },
            authenticate => 0,
            validate     => 0,
            http_allow   => 'GET'
        );
    }
}

# =========================
sub handleInterwiki {

    #    my ( $pre, $alias, $page, $post ) = @_;
    Foswiki::Func::writeDebug("- ${pluginName}::handleInterwiki") if $debug;

    my $text = "";

    my $rule = Foswiki::Plugins::InterwikiPreviewPlugin::Rule->get( $_[1] );

    if ( defined $rule ) {
        $text =
          " %INTERWIKIPREVIEWQUERY{alias=\"$_[1]\" page=\"$_[2]\"}% "
          . Foswiki::Func::expandCommonVariables( $rule->{"info"}, $topic,
            $web );
        Foswiki::Func::writeDebug(
            "- ${pluginName}::handleInterwiki adding ${text}")
          if $debug;
    }
    return $_[0] . $_[1] . ":" . $_[2] . $_[3] . $text;
}

# =========================
sub preRenderingHandler {

    #my( $text, $pMap ) = @_;
    Foswiki::Func::writeDebug("- ${pluginName}::preRenderingHandler()")
      if $debug;

    # The ...QUERY and ...FIELD tag handlers are local closures
    # which have the same $query in scope.
    my $query      = undef();
    my %tagHandler = (
        QUERY => sub {
            Foswiki::Func::writeDebug(
                "- ${pluginName}::preRenderingHandler QUERY")
              if $debug;
            my %params = Foswiki::Func::extractParameters( $_[0] );
            my $rule   = Foswiki::Plugins::InterwikiPreviewPlugin::Rule->get(
                $params{alias} );
            if ( defined $rule ) {
                $query =
                  Foswiki::Plugins::InterwikiPreviewPlugin::Query->new( $rule,
                    $params{page} );
            }
            return "";
        },
        FIELD => sub {
            Foswiki::Func::writeDebug(
                "- ${pluginName}::preRenderingHandler FIELD")
              if $debug;
            return $query->field( $_[0] ) if ( defined $query );

            # Leave tag unexpanded if there was no query.
            Foswiki::Func::writeDebug(
                "- ${pluginName}::preRenderingHandler FIELD unexpanded")
              if $debug;
            return "%INTERWIKIPREVIEWFIELD{$_[0]}%";
        }
    );

    $_[0] =~
s/(\]\[)$sitePattern:$pagePattern(\]\]|\s)/&handleInterwiki($1,$2,$3,$4)/geo;
    $_[0] =~
s/$prefixPattern$sitePattern:$pagePattern$postfixPattern/&handleInterwiki($1,$2,$3,"")/geo;
    $_[0] =~ s/%INTERWIKIPREVIEW(\w+){(.*?)}%/&{$tagHandler{$1}}($2)/geo;
}

# =========================
sub postRenderingHandler {

    #my $text = shift;
    Foswiki::Func::writeDebug("- ${pluginName}::postRenderingHandler()")
      if $debug;
    my $queryScripts =
      Foswiki::Plugins::InterwikiPreviewPlugin::Query->scripts();
    if ($queryScripts) {
        $_[0] = $_[0] . $queryScripts;
        my $head = <<HERE;
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/${pluginName}/MochiKit.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/${pluginName}/query.js"></script>
HERE
        Foswiki::Func::addToZone(
            'script', 'INTERWIKIPREVIEWPLUGIN',
            $head,    'JQUERYPLUGIN::FOSWIKI'
        );
    }
}

# =========================
sub modifyHeaderHandler {
    my ( $headers, $query ) = @_;

    my $queryContentType =
      Foswiki::Func::getSessionValue( $pluginName . 'ContentType' );
    if ( Foswiki::Func::getContext()->{'rest'} && $queryContentType ) {
        Foswiki::Func::writeDebug(
"- ${pluginName}::modifyHeaderHandler setting Content-Type to $queryContentType"
        ) if $debug;
        $headers->{'Content-Type'} = $queryContentType;
        Foswiki::Func::clearSessionValue( $pluginName . 'ContentType' );
    }
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2007-2011 Ian Bygrave, ian@bygrave.me.uk

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
