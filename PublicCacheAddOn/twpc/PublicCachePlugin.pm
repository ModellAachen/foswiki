# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Colas Nahaboo http://colas.nahaboo.net
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

# This plugin is part of the TWPC, TWiki Public Cache Addon.
# It is used to track changes in the state of the TWiki contents, and call
# proper cache updating modules.

# =========================
package TWiki::Plugins::PublicCachePlugin;

$debug = 0;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION  $RELEASE $pluginName
  $debug
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'v3';

$pluginName = 'PublicCachePlugin';    # Name of this Plugin

sub debug { TWiki::Func::writeDebug(@_) if $debug; }

sub warning {
    TWiki::Func::writeWarning(@_);
    debug( "WARNING" . $_[0], @_[ 1 .. $#_ ] );
}

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.020 ) {
        warning("Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }
    return 1;
}

=pod

---++ afterSaveHandler($text, $topic, $web, $error, $meta )
   * =$text= - the text of the topic _excluding meta-data tags_
     (see beforeSaveHandler)
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string returned by the save.
   * =$meta= - the metadata of the saved topic, a TWiki::Meta object 
This handler is called each time a topic is saved.

__NOTE:__ meta-data is embedded in $text (using %META: tags)

*Since:* TWiki::Plugins::VERSION 1.020

=cut

sub afterSaveHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $error, $meta ) = @_;
    #         0      1       2     3       4
    if ( $_[3] ) {
        debug("- $pluginName: Unsuccessful save, not notifying...");
        return;
    }

    # immediately clear cache for cleargrace null
    if ( XXXcleargraceXXX == 0 ) {
        eval "require  LWP::Simple;";
        my $response = LWP::Simple::get("XXXbinurlXXX/pcad?action=clear");
        if ( !defined $response ) {
            warning("Error in clearing cache");
        }
    }
    else {

        # register our client as a changer
        # untaint var,  http://www.perlmeme.org/howtos/secure_code/taint.html
        my $ip_tainted = $ENV{REMOTE_ADDR};
        if ( $ip_tainted =~ m/^([0-9\.]+)$/ ) {
            my $ip = "$1";

            if ( open( FILE, ">XXXcacheXXX/_changers/$ip" ) ) {
                print FILE $ip;    # "touch"
                close(FILE);
            }
            else {

                # retry once
                eval "require File::Path;";
                File::Path::mkpath( "XXXcacheXXX/_changers", 0, 0777 );
                if ( open( FILE, ">>XXXcacheXXX/_changers/$ip" ) ) {
                    print FILE $ip;    # "touch"
                    close(FILE);       # just create an empty file
                }
                else {

                    # dont complain: it means the cache system was not in
                    # place yet, so no need to bypass it anyways at this time
                    debug(
"PublicCachePlugin: could not write XXXcacheXXX/_changers/$ip"
                    );
                }
            }
        }
        else {
            warning("Bad IP address in REMOTE_ADDR: $ENV{REMOTE_ADDR}");
        }
    }
    return 1;
}

=pod

---++ beforeWriteCompletePage($text, $topic, $web, $contenbtType )
   * =$page= - the html rendering of the page
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$contentType= - mime type: text/html, text/plain, text/xml
This handler is called just after page rendering (end of view).

*Since:* Not yet an official handler

=cut

sub beforeWriteCompletePage {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $page, $topic, $web, $contentType ) = @_;
    #         0      1       2     3

    # handle cache expiration time of this page if set
    # 0 = no expire, -1 = not cached, 1 = default value, N = seconds
    my $exptime = TWiki::Func::getPreferencesValue('PUBLIC_CACHE_EXPIRE') || 0;

    #debug("- $pluginName: beforeWriteCompletePage $exptime");
    if ( $exptime != 0 ) {
        eval "require File::Path;";
        if ( $exptime < 0 ) {
            File::Path::mkpath( "XXXcacheXXX/$_[2]", 0, 0777 );
            if ( open( FILE, ">>XXXcacheXXX/$_[2]/$_[1].nc" ) ) {
                close(FILE);    # just create an empty file
            }
        }
        else {
            eval "require File::Path;";
            $exptime = XXXexptimeXXX if ( $exptime == 1 );
            File::Path::mkpath( "XXXcacheXXX/_expire/$_[2]", 0, 0777 );
            if ( open( FILE, ">>XXXcacheXXX/_expire/$_[2]/$_[1]" ) ) {
                close(FILE);    # just create an empty file
                my $fileexptime = time() + $exptime;
                utime( $fileexptime, $fileexptime,
                    "XXXcacheXXX/_expire/$_[2]/$_[1]" );
            }
            else {
                warning("Error writing XXXcacheXXX/_expire/$_[2]/$_[1]");
            }
        }
    }
    return 1;
}

1;
