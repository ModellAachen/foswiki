# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005 Toni Prug, toni@irational.org
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
# This is the NetgrepPlugin used to embed external information.
# Plugin home: http://foswiki.org/Extensions/NetgrepPlugin
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
# For increased performance, DISABLE handlers you don't need.
#
# NOTE: To interact with Foswiki use the official Foswiki functions
# in the &Foswiki::Func module. Do not reference any functions or
# variables elsewhere in Foswiki!!

# =========================
package Foswiki::Plugins::NetgrepPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  $defaultRefresh $defaultFormat $defaultSize
  $perlDigestMD5Found $defaultFilter $defaultColor
);

# This should always be $Rev$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$perlDigestMD5Found = 0;

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1 ) {
        &Foswiki::Func::writeWarning(
            "Version mismatch between NetgrepPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin preferences
    $defaultRefresh =
      &Foswiki::Func::getPreferencesValue("NETGREPPLUGIN_REFRESH")
      || 15;
    $defaultFilter =
      &Foswiki::Func::getPreferencesValue("NETGREPPLUGIN_FILTER");
    $defaultFormat = &Foswiki::Func::getPreferencesValue("NETGREPPLUGIN_FORMAT")
      || "(+1+)";
    $defaultSize = &Foswiki::Func::getPreferencesValue("NETGREPPLUGIN_SIZE")
      || "100%";
    $defaultColor = &Foswiki::Func::getPreferencesValue("NETGREPPLUGIN_COLOR")
      || "black";

    # Get plugin debug flag
    $debug = &Foswiki::Func::getPreferencesFlag("NETGREPPLUGIN_DEBUG");

    # Plugin correctly initialized
    &Foswiki::Func::writeDebug(
        "- Foswiki::Plugins::NetgrepPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &Foswiki::Func::writeDebug(
        "- NetgrepPlugin::commonTagsHandler( $_[2].$_[1] )");
    $_[0] =~ s/( *)%NETGREP{(.*?)}%/_handleNetgrepTag( $1, $2 )/geo;
}

# =========================
sub _errorMsg {
    my ( $thePre, $theMsg ) = @_;

    return "$thePre| *NETGREP Plugin Error* |\n"
      . "$thePre| $installWeb.NetgrepPlugin: $theMsg |\n";
}

# =========================
sub _getUrl {
    my ( $theUrl, $theRefresh ) = @_;

    my $cacheDir  = "";
    my $cacheFile = "";
    if ($theRefresh) {
        $cacheDir =
          Foswiki::Func::getPubDir() . '/' . $installWeb . '/NetgrepPlugin';
        $cacheDir =~ /(.*)/;
        $cacheDir = $1;    # untaint (save because only internal variables)
        $cacheFile = $cacheDir . '/_url-' . Digest::MD5::md5_hex($theUrl);
        $cacheFile =~ /(.*)/;
        $cacheFile = $1;    # untaint
        if (   ( -e $cacheFile )
            && ( ( time() - ( stat(_) )[9] ) <= ( $theRefresh * 60 ) ) )
        {

      # return cached version if it exists and isn't too old. 1440 = 24h * 60min
            return Foswiki::Func::readFile($cacheFile);
        }
    }

    my $host = "";
    my $port = 0;
    my $path = "";
    if ( $theUrl =~ /http\:\/\/(.*?)\:([0-9]+)(\/.*)/ ) {
        $host = $1;
        $port = $2;
        $path = $3;
    }
    elsif ( $theUrl =~ /http\:\/\/(.*?)(\/.*)/ ) {
        $host = $1;
        $path = $2;
    }
    unless ($path) {
        return "ERROR: invalid format of the href parameter";
    }

   # figure out how to get to TWiki::Net which is wide open in Cairo and before,
   # but Dakar uses the session object.
    my $text =
        $TWiki::Plugins::SESSION->{net}
      ? $TWiki::Plugins::SESSION->{net}->getUrl( $host, $port, $path )
      : Foswiki::Net::getUrl( $host, $port, $path );

    if ( $text =~ /text\/plain\s*ERROR\: (.*)/s ) {
        my $msg = $1;
        $msg =~ s/[\n\r]/ /gos;
        return "ERROR: Can't read $theUrl ($msg)";
    }
    if ( $text =~ /HTTP\/[0-9\.]+\s*([0-9]+)\s*([^\n]*)/s ) {
        unless ( $1 == 200 ) {
            return "ERROR: Can't read $theUrl ($1 $2)";
        }
    }
    $text =~ s/\r\n/\n/gos;
    $text =~ s/\r/\n/gos;
    $text =~ s/^.*?\n\n(.*)/$1/os;    # strip header
    $text =~ s/\n/ /gos;              # new line to space
    $text =~ s/ +/ /gos;

    if ($theRefresh) {
        unless ( -e $cacheDir ) {

            # create the cache directory in the pub dir of the NetgrepPlugin
            umask(002);
            mkdir( $cacheDir, 0775 );
        }

        # save text in cache file before returning it
        Foswiki::Func::saveFile( $cacheFile, $text );
    }

    return $text;
}

# =========================
sub _handleNetgrepTag {
    my ( $thePre, $theArgs ) = @_;

    unless ($perlDigestMD5Found) {

        # lazy loading of Perl module
        eval { $perlDigestMD5Found = require Digest::MD5; };
    }
    unless ($perlDigestMD5Found) {
        return _errorMsg( $thePre,
            "ERROR: Cannot locate Perl module Digest::MD5" );
    }

    my $href = Foswiki::Func::extractNameValuePair( $theArgs, "href" )
      || Foswiki::Func::extractNameValuePair($theArgs);
    my $filter = Foswiki::Func::extractNameValuePair( $theArgs, "filter" )
      || Foswiki::Func::extractNameValuePair($theArgs);
    my $refresh = Foswiki::Func::extractNameValuePair( $theArgs, "refresh" )
      || $defaultRefresh;
    my $format = Foswiki::Func::extractNameValuePair( $theArgs, "format" )
      || $defaultFormat;
    my $size = Foswiki::Func::extractNameValuePair( $theArgs, "size" )
      || $defaultSize;
    my $color = Foswiki::Func::extractNameValuePair( $theArgs, "color" )
      || $defaultColor;

    unless ($href) {
        return _errorMsg( $thePre, "href parameter (source) is missing" );
    }

    unless ($filter) {
        return _errorMsg( $thePre, "filter parameter is missing" );
    }

    my $raw = _getUrl( $href, $refresh );
    if ( $raw =~ /^ERROR\: (.*)/s ) {
        return _errorMsg( $thePre, $1 );
    }

    ( my @filtered ) = $raw =~ /$filter/;

    my $result = $format;
    for ( my $i = 0 ; $i < scalar(@filtered) ; $i++ ) {
        $result =~ s/\+$i\+/$filtered[$i]/g;
    }

    return
"$thePre <noautolink><span style='color: $color; font-size: $size;'>$result</span></noautolink>";
}

# =========================

1;
