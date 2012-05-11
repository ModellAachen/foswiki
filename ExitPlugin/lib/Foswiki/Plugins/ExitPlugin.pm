# Plugin for Foswiki Collaboration Platform, http://foswiki.org/
#
# Copyright (C) 2009 Ian Bygrave, ian@bygrave.me.uk
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
# This plugin redirects links to external sites via a page of your choice.

# =========================
package Foswiki::Plugins::ExitPlugin;

use strict;

require Foswiki::Func;
require Foswiki::Plugins;
require URI::Escape;

our $VERSION = '$Rev: 3193 $';
our $RELEASE = '$Date: 2009-03-19 16:32:09 +0000 (Thu, 19 Mar 2009) $';
our $SHORTDESCRIPTION =
  'ExitPlugin redirects links to external sites via a page of your choice.';

our $NO_PREFS_IN_TOPIC = 1;

# =========================
use vars qw(
  $web $topic $user $installWeb $pluginName
  $debug $disable $initStage $redirectVia $noExit $preMark $postMark $marksInLink $schemepat
);

$pluginName = 'ExitPlugin';

# =========================

sub _patFromCfg {
    return "(?:"
      . join(
        "|",
        map( quotemeta,
            split(
                /[[:space:]]*,[[:space:]]*/s,
                $Foswiki::cfg{Plugins}{$pluginName}{ $_[0] }
              ) )
      ) . ")";
}

sub _isWebInCfg {
    my $cfg = $Foswiki::cfg{Plugins}{$pluginName}{ $_[0] } || '';

    # Wildcard
    return 1 if ( $cfg =~ /^[[:space:]]*\*[[:space:]]*$/ );

    my @items = split( /[[:space:]]*,[[:space:]]*/s, $cfg );
    return 1 if ( grep /$web/, @items );

    return 0;
}

sub _partInit {

    # Partial initialization
    # stage 0:
    #  uninitialized
    # stage 1:
    #  enough for endRenderingHandler
    #  set $debug $schemepat
    # stage 2:
    #  enough for linkreplace without link rewriting
    #  set $noExit
    # stage 3:
    #  enough for link rewriting
    #  set $redirectVia, $preMark, $postMark, $marksInLink

    return if ( $_[0] > 3 );

    while ( $initStage < $_[0] ) {

        if ( $initStage == 0 ) {

            # Get plugin debug flag
            $debug = $Foswiki::cfg{Plugins}{$pluginName}{Debug} || 0;

            # Get disable flag
            $disable = !_isWebInCfg("EnableWebs");
            Foswiki::Func::writeDebug( __PACKAGE__, "disable = ${disable}" )
              if $debug;

            # Get schemes to redirect
            $schemepat = _patFromCfg("Schemes");
            Foswiki::Func::writeDebug( __PACKAGE__, "schemepat = ${schemepat}" )
              if $debug;

            $initStage = 1;

        }
        elsif ( $initStage == 1 ) {

            # Get exempt link targets
            $noExit = _patFromCfg("NoExit");
            Foswiki::Func::writeDebug( __PACKAGE__, "noExit = ${noExit}" )
              if $debug;

            $initStage = 2;

        }
        elsif ( $initStage == 2 ) {

            # Get redirect page
            $redirectVia = $Foswiki::cfg{Plugins}{$pluginName}{RedirectVia}
              || "%SCRIPTURL%/exit?url=";
            $redirectVia =
              Foswiki::Func::expandCommonVariables( $redirectVia, $topic,
                $web );
            Foswiki::Func::writeDebug( __PACKAGE__,
                "redirectVia = ${redirectVia}" )
              if $debug;

            # Get pre- and post- marks
            $preMark = $Foswiki::cfg{Plugins}{$pluginName}{Premark} || "";
            $preMark =
              Foswiki::Func::expandCommonVariables( $preMark, $topic, $web );
            Foswiki::Func::writeDebug( __PACKAGE__, "preMark = ${preMark}" )
              if $debug;
            $postMark = $Foswiki::cfg{Plugins}{$pluginName}{Postmark} || "";
            $postMark =
              Foswiki::Func::expandCommonVariables( $postMark, $topic, $web );
            Foswiki::Func::writeDebug( __PACKAGE__, "postMark = ${postMark}" )
              if $debug;

            # Get marksInLink flag
            $marksInLink = $Foswiki::cfg{Plugins}{pluginName}{MarksInLink} || 0;

            $initStage = 3;

        }

    }
    return;
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

    # Register REST handler for exit redirector
    # Disabled until unauthorised REST handlers are possible.
    #Foswiki::Func::registerRESTHandler('exit', \&_restExit);

    $initStage = 0;
    _partInit(1);

    # Plugin correctly initialized
    Foswiki::Func::writeDebug( __PACKAGE__,
        "::initPlugin( $web.$topic ) is OK" )
      if $debug;
    return 1;
}

# =========================

sub _linkReplace {
    my ( $open, $pretags, $url, $posttags, $text, $close ) = @_;
    _partInit(2);

    # Is this an exit link?
    if ( !( $url =~ /^\w+:\/\/[\w\.]*?$noExit(?:\/.*)?$/o ) ) {
        _partInit(3);
        $url =~
          s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;    # Remove <nop> tags.
        $url = URI::Escape::uri_escape($url);
        if ($marksInLink) {
            return
                $open
              . " class='exitlink'"
              . $pretags
              . $redirectVia
              . $url
              . $posttags
              . $preMark
              . $text
              . $postMark
              . $close;
        }
        else {
            return
                $preMark 
              . $open
              . " class='exitlink'"
              . $pretags
              . $redirectVia
              . $url
              . $posttags
              . $text
              . $close
              . $postMark;
        }
    }
    return $open . $pretags . $url . $posttags . $text . $close;
}

sub postRenderingHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead
    if ($disable) {
        Foswiki::Func::writeDebug( __PACKAGE__,
            "::endRenderingHandler(disabled by DISABLEEXITPLUGIN)" )
          if $debug;
        return;
    }
    Foswiki::Func::writeDebug( __PACKAGE__,
        "::endRenderingHandler( $web.$topic )" )
      if $debug;

# This handler is called by getRenderedVersion just after the line loop, that is,
# after almost all XHTML rendering of a topic. <nop> tags are removed after this.
    $_[0] =~
s/(<a)(\s+[^>]*?href=")($schemepat:\/\/[^"]+)("[^>]*>)(.*?)(<\/a>)/&_linkReplace($1,$2,$3,$4,$5,$6)/isgeo;
}

# =========================

sub _restExit {
    my ( $session, $plugin, $verb, $response ) = @_;

    Foswiki::Func::writeDebug( __PACKAGE__, "::_restExit()" ) if $debug;

    my $query = Foswiki::Func::getCgiQuery();

    unless ( defined( $query->param('url') ) ) {
        $response->header(
            -type   => 'text/html',
            -status => 400
        );
        $response->print("ERROR: (400) Bad Request");
        return undef;
    }

    my $url = URI::Escape::uri_unescape( $query->param('url') );
    $response->header(
        -type   => 'text/html',
        -status => 200
    );

    $response->print(
        "<html><head><title>You Are Exiting The Foswiki Web Server</title>\n");
    $response->print(
        "<meta http-equiv=\"refresh\" content=\"0; URL=${url}\"></head>\n");
    $response->print("<body><b>Thank you for visiting.\n");
    $response->print("Click on the following link to go to:</b>\n");
    $response->print("<a href=\"${url}\">${url}</a>\n");
    $response->print(
        "<b>(or you will be taken there immediately)<hr></b></body></html>\n");
    return undef;
}

# =========================

# Invoked via bin/exit

sub exitRedirect {

    my $session = shift;

    Foswiki::Func::writeDebug( __PACKAGE__, "::exitRedirect()" ) if $debug;

    _restExit( $session, "ExitPlugin", "exit", $session->{response} );
}

1;
