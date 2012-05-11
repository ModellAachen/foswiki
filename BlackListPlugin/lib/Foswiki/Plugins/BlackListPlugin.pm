# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004-2007 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2008-2009 Foswiki Contributors
#
# For licensing info read LICENSE file in the Foswiki root.
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
# As per the GPL, removal of this notice is prohibited.
#
# Q&D implementation of backlist handler. Black sheep get a
# timeout and a message

package Foswiki::Plugins::BlackListPlugin;

# Always use strict to enforce variable scoping
use strict;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
  'Utility to keep malicious users away from a public Foswiki site';

# For this plugin it is for the moment still the plugin topic that is used for more dynamic settings
# because many settings are of a nature where a trusted group and not only the administrator should
# maintain the settings, making moving the settings to configure a bad choice.
our $NO_PREFS_IN_TOPIC = 0;

use vars qw(
  $web $topic $user $installWeb $debug
);

# This should always be $Rev$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
our $VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
our $RELEASE = '24 Feb 2010';

our $pluginName = 'BlackListPlugin';    # Name of this Plugin
our %cfg        = (
    "ptReg"   => 10,
    "ptChg"   => 5,
    "ptView"  => 1,
    "ptRaw"   => 30,
    "ptLimit" => 100,
    "period"  => 300,
);
our $userScore    = "N/A";
our $isBlackSheep = 0;
our $noFollowAge  = 0;
our $topicAge     = 0;
our $urlHost      = "initialized_later";
our $banExpire    = 0;

# =========================
sub writeDebug {
    Foswiki::Func::writeDebug( "$pluginName - " . $_[0] ) if $debug;
}

# =========================
sub writeDebugTimes {
    Foswiki::Func::writeDebugTimes( "$pluginName - " . $_[0] ) if $debug;
}

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # get debug flag
    $debug = Foswiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    Foswiki::Func::registerTagHandler( 'BLACKLISTPLUGIN', \&_handleBlackList );

    my $cgiQuery = Foswiki::Func::getCgiQuery();

    # initialize for rel="nofollow" links
    $urlHost = Foswiki::Func::getUrlHost();
    $noFollowAge =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_NOFOLLOWAGE") || 0;
    $noFollowAge = 0 unless ( $noFollowAge =~ s/.*?(\-?[0-9]*.*)/$1/s );

    if ( $noFollowAge > 0 ) {
        $noFollowAge *= 3600;
        my ($date) = Foswiki::Func::getRevisionInfo( $web, $topic );
        $topicAge = time() - $date if ($date);
    }

    # initialize the ban expiry - convert minutes to seconds
    # We cannot use the usual || 0 because undefined means a 60 default
    $banExpire = Foswiki::Func::getPreferencesValue("\U$pluginName\E_BANEXPIRE")
      || 0;
    $banExpire *= 60;

    # white list
    my $whiteList = _getWhiteListRegex();

    # black list
    my $blackList =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_BLACKLIST") || "";
    $blackList = join( "|", map { quotemeta } split( /,\s*/, $blackList ) );

    # ban list
    my $remoteAddr  = $ENV{'REMOTE_ADDR'}  || "";
    my $scriptName  = $ENV{'SCRIPT_NAME'}  || "";
    my $queryString = $ENV{'QUERY_STRING'} || "";
    my $banList     = '';
    my $banTimestamp = quotemeta _checkBanList($remoteAddr);
    $banList = $remoteAddr if $banTimestamp;

    # black list + ban list regular expression
    my $blackRE = "($blackList";
    $blackRE .= "|" if ( $blackList && $banList );
    $blackRE .= "$banList)";

    # black sheep if in black list unless in white list
    $isBlackSheep = 0;
    $userScore    = "N/A";

    if ( ($remoteAddr) && ( $remoteAddr !~ /^$whiteList/ ) ) {
        if ( $blackRE ne "()" && $remoteAddr =~ /^$blackRE/ ) {

            # already a black sheep
            $isBlackSheep = 1;
            _writeLog("$scriptName - already blacklisted");
        }
        else {

            # check for new candidate of black sheep

            my ( $c1, $c2, $c3, $c4, $c5, $c6 ) =
              split(
                /,\s*/,
                (
                    Foswiki::Func::getPreferencesValue(
                        "\U$pluginName\E_BANLISTCONFIG")
                      || ''
                )
              );
            $cfg{"ptReg"}   = $c1 || 10;
            $cfg{"ptChg"}   = $c2 || 5;
            $cfg{"ptView"}  = $c3 || 1;
            $cfg{"ptRaw"}   = $c4 || 30;
            $cfg{"ptLimit"} = $c5 || 100;
            $cfg{"period"}  = $c6 || 300;

            $userScore =
              _handleEventLog( $remoteAddr, $scriptName, $queryString );
            writeDebug("initPlugin() score: $userScore");
            if ( $userScore > $cfg{"ptLimit"} ) {
                $isBlackSheep = 1;
                _handleBanList( "add", $remoteAddr );
                _writeLog(
"BANLIST add: $remoteAddr, $scriptName, $userScore over limit $cfg{ \"ptLimit\" }"
                );
            }
        }
    }

    if ($isBlackSheep) {

        # black sheep identified
        # sleep for 5 seconds
        # was 60 seconds but reduced to 5 to lower the risk of using this for
        # DOS attech. 5 seconds is enough to slow down a scanning attempt
        sleep 5 unless ($debug);
        if ( $scriptName =~ /oops/ ) {

            # show oops message normal
        }
        else {

            # other scripts: redirect to oops message
            unless ($cgiQuery) {
                exit 1;    # Force a "500 Internal Server Error" error
            }

# We cannot reliably redirect in initPlugin. So we send simple primitive message
# that causes minimal load on the system.
# A more complete solution has been discussed but this simple message gives the
# least load on the server when an attacker tries many times.
            my $expireText = '';
            if ($banExpire) {
                $expireText =
                    " for another "
                  . int( ( $banTimestamp + $banExpire - time() ) / 60 )
                  . " minutes";
            }
            local $| = 1;
            print CGI::header( -status => 403, -type => 'text/plain' );
            print "You have been banned on this website$expireText";
            exit 0;
        }
    }

    # Plugin correctly initialized
    writeDebug(
"initPlugin( $web.$topic ) is OK, whiteList $whiteList, blackRE $blackRE"
    );
    return 1;
}

# =========================

sub postRenderingHandler {

    # ( $text )

    return unless ($noFollowAge);
    $_[0] =~
s/(<a .*?href=[\"\']?)([^\"\'\s]+[\"\']?)(\s*[a-z]*)/_handleNofollowLink( $1, $2, $3 )/geoi;
}

# =========================
sub beforeSaveHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    writeDebug("beforeSaveHandler( $_[2].$_[1] )");

# This handler is called by Foswiki::Store::saveTopic just before the save action.

    # Bail out unless spam filtering is enabled
    return
      unless (
        Foswiki::Func::getPreferencesFlag("\U$pluginName\E_FILTERWIKISPAM") );

    # Bail out for excluded topics
    my @arr = split( /,\s*/,
        Foswiki::Func::getPreferencesValue("\U$pluginName\E_SPAMEXCLUDETOPICS")
    );
    foreach (@arr) {
        return if ( (/^(.*)/) && ( $1 eq "$_[2].$_[1]" ) );
    }

    # exclude white list
    my $whiteList = _getWhiteListRegex();
    my $remoteAddr = $ENV{'REMOTE_ADDR'} || "";
    return if ( $remoteAddr =~ /^$whiteList/ );

    # First we look spam in the raw text
    my $spamListRegex = _getSpamListRegex();
    return unless $spamListRegex;    # empty list
    if ( $_[0] =~ /$spamListRegex/ ) {
        _oopsMessage( "topic", $1, $remoteAddr );
    }

    # check for evil eval() or escape() spam in <script>
    # This provides limited protection, consider SafeWikiPlugin
    if ( $_[0] =~ /<script.*?(eval|escape) *\(.*?<\/script>/gis ) {
        _oopsMessage( "topic", "script eval() or escape()", $remoteAddr );
    }

    # check for 'no changes ... no changes' by ringtones scumbag
    if ( $_[0] =~ /no changes \.\.\. no changes/gis ) {
        _oopsMessage( "topic", "ringtones scumbag", $remoteAddr );
    }
}

# =========================
sub beforeAttachmentSaveHandler {
### my ( $attachmentAttr, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    my $attachmentAttr = $_[0];
    my $attachmentName = $attachmentAttr->{"attachment"};
    my $tmpFilename    = $attachmentAttr->{"tmpFilename"};

# This handler is called by Foswiki::Store::saveAttachment just before the save action
    writeDebug("beforeAttachmentSaveHandler( $_[2].$_[1], $attachmentName )");

    # Bail out unless spam filtering is enabled
    return
      unless (
        Foswiki::Func::getPreferencesFlag("\U$pluginName\E_FILTERWIKISPAM") );

    # test only attachments of type .html and a few more
    return unless ( $attachmentName =~ m/\.(html?|txt|js|css)$/i );

    # exclude white list
    my $whiteList = _getWhiteListRegex();
    my $remoteAddr = $ENV{'REMOTE_ADDR'} || "";
    return if ( $remoteAddr =~ /^$whiteList/ );

    # check for evil eval() or escape() spam in <script>
    my $text = Foswiki::Func::readFile($tmpFilename);
    if ( $text =~ /<script.*?(eval|escape) *\(.*?<\/script>/gis ) {
        _oopsMessage( "html", "script eval() or escape()", $remoteAddr );
    }

    # check for known spam signatures
    my $spamListRegex = _getSpamListRegex();
    return unless $spamListRegex;    # empty list
    if ( $text =~ /$spamListRegex/ ) {
        _oopsMessage( "html", $1, $remoteAddr );
    }
}

# =========================
sub _oopsMessage {
    my ( $type, $badword, $remoteAddr ) = @_;

    my $cgiQuery = Foswiki::Func::getCgiQuery();

    if ($cgiQuery) {
        _handleBanList( "add", $remoteAddr );
        _writeLog("SPAMLIST add: $remoteAddr, $type spam '$badword'");

        my $msg =
          Foswiki::Func::getPreferencesValue("\U$pluginName\E_WIKISPAMMESSAGE")
          || "Spam detected, '%WIKISPAMWORD%' is a banned word and cannot be saved.";
        $msg =~ s/%WIKISPAMWORD%/$badword/;
        $msg = Foswiki::Func::expandCommonVariables($msg);

        throw Foswiki::OopsException(
            'oopsattention',
            def    => 'generic',
            status => 403,
            web    => $web,
            topic  => $topic,
            params => [ $msg || '?' ]
        );
    }

    # else (unlikely case) force a "500 Internal Server Error" error
    exit 1;
}

# =========================
# Gets the BLACKLISTPLUGIN_WHITELIST pref which must be comma separated
# and returns regex in the format (xxx\\.xxx\\.xxx\\.xxx|yyy\\.yyy\\.yyy\\.yyy)
sub _getWhiteListRegex {
    my $regex = Foswiki::Func::getPreferencesValue("\U$pluginName\E_WHITELIST")
      || "127.0.0.1";

    # Get rid of trailing spaces that the user or editor may have added
    $regex =~ s/\s+$//;
    $regex = join( "|", map { quotemeta } split( /,\s*/, $regex ) );
    return "($regex)";
}

# =========================
# Returns empty string if no local spam list and public never cached and
# not available
sub _getSpamListRegex {
    my $refresh =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_SPAMREGEXREFRESH")
      || 5;
    $refresh = 1 unless ( $refresh =~ s/.*?([0-9]+).*/$1/s );
    $refresh = 1 if ( $refresh < 1 );

    my $cacheFile = _makeFileName("spam_regex");
    if (   ( -e $cacheFile )
        && ( ( time() - ( stat(_) )[9] ) <= ( $refresh * 60 ) ) )
    {

        # return cached version if it exists and isn't too old
        return Foswiki::Func::readFile($cacheFile);
    }

    # merge public and local spam list
    my $text = _getSpamMergeText() . "\n" . _handleSpamList( "read", "" );
    $text =~ s/ *\#.*//go;    # strip comments
    $text =~
      s/^.*?[ <>].*?$//gom;   # remove all lines that have spaces or HTML <tags>

    # Remove patterns in exclude list
    my $excludeRE = join( '|',
        map { quotemeta }
          split( /[\n\r]+/, _handleExcludeList( "read", "" ) ) );
    $text =~ s/^.*?($excludeRE).*?$//gm if ($excludeRE);

    # Build regex
    $text =~ s/^[\n\r]+//os;
    $text =~ s/[\n\r]+$//os;
    $text =~ s/[\n\r]+/\|/gos;

    # We return empty string and do not save cacheFile if we have no local
    # spam list and the public list has never been loaded
    return '' unless $text;

    $text = "(https?://[\\w\\.\\-:\\@/]*?($text))";

    Foswiki::Func::saveFile( $cacheFile, $text );
    return $text;
}

# =========================
sub _getSpamMergeText {
    my $url = Foswiki::Func::getPreferencesValue("\U$pluginName\E_SPAMLISTURL")
      || 'http://arch.thinkmo.de/cgi-bin/spam-merge';
    my $refresh =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_SPAMLISTREFRESH")
      || 10;
    $refresh = 10 unless ( $refresh =~ s/.*?([0-9]+).*/$1/s );
    $refresh = 10 if ( $refresh < 10 );

    my $cacheFile = _makeFileName("spam_merge");
    if (   ( -e $cacheFile )
        && ( ( time() - ( stat(_) )[9] ) <= ( $refresh * 60 ) ) )
    {

        # return cached version if it exists and isn't too old
        return Foswiki::Func::readFile($cacheFile);
    }

    # read spam merge list via http
    $url =~ /http\:\/\/(.*?)(\/.*)/;
    my $host             = $1;
    my $port             = 0;
    my $path             = $2;
    my $text             = '';
    my $headerAndContent = 1;

    my $response = Foswiki::Func::getExternalResource($url);
    if ( $response->is_error() ) {
        my $msg = "Code " . $response->code() . ": " . $response->message();
        $msg =~ s/[\n\r]/ /gos;
        Foswiki::Func::writeDebug(
            "- $pluginName ERROR: Can't read $url ($msg)");
        return "#ERROR: Can't read $url ($msg)";
    }
    else {
        $text             = $response->content();
        $headerAndContent = 0;
    }

    if ($headerAndContent) {
        if ( $text =~ /text\/plain\s*ERROR\: (.*)/s ) {
            my $msg = $1;
            $msg =~ s/[\n\r]/ /gos;
            Foswiki::Func::writeDebug(
                "- $pluginName ERROR: Can't read $url ($msg)");
            return "#ERROR: Can't read $url ($msg)";
        }
        if ( $text =~ /HTTP\/[0-9\.]+\s*([0-9]+)\s*([^\n]*)/s ) {
            unless ( $1 == 200 ) {
                Foswiki::Func::writeDebug(
                    "- $pluginName ERROR: Can't read $url ($1 $2)");
                return "#ERROR: Can't read $url ($1 $2)";
            }
        }
    }
    $text =~ s/\r\n/\n/gos;
    $text =~ s/\r/\n/gos;
    $text =~ s/^.*?\n\n(.*)/$1/os if ($headerAndContent);    # strip header
    unless ( $text =~ /.{128}/ ) {

        # spam-merge file is too short, possibly temporary read error
        Foswiki::Func::writeDebug(
"- $pluginName WARNING: Content of $url is too short, using old cache"
        );
        Foswiki::Func::saveFile( _makeFileName("spam_merge_err"), $text );
        $text = Foswiki::Func::readFile($cacheFile);    # read old cache content
    }
    Foswiki::Func::saveFile( $cacheFile, $text );
    return $text;
}

# =========================
sub _handleSpamList {
    my ( $theAction, $theValue ) = @_;
    my $fileName = _makeFileName("spam_list");
    writeDebug(
"_handleSpamList( Action: $theAction, value: $theValue, file: $fileName )"
    );
    my $text = Foswiki::Func::readFile($fileName)
      || "# The spam-list is a generated file, do not edit\n";
    if ( $theAction eq "read" ) {
        $text =~ s/^\#[^\n]*\n//s;
        return $text;
    }

    my @errorMessages;
    my @infoMessages;
    foreach my $item ( split( /,\s*/, $theValue ) ) {
        $item =~ s/^\s+//;
        $item =~ s/\s+$//;

        if ( $theAction eq "add" ) {
            if ( $text =~ /\n\Q$item\E\n/s ) {
                push @infoMessages,
                  "Warning: Spam pattern '$item' is already on the list";
                next;
            }
            $text .= "$item\n";
            push @infoMessages, "Note: Added spam pattern '$item'";
            unlink( _makeFileName("spam_regex") );    # remove cache

        }
        elsif ( $theAction eq "remove" ) {
            unless ( ($item) && ( $text =~ s/(\n)\Q$item\E\n/$1/s ) ) {
                push @errorMessages, "Error: Spam pattern '$item' not found";
                next;
            }
            push @infoMessages, "Note: Removed spam pattern '$item'";
            unlink( _makeFileName("spam_regex") );    # remove cache

        }
        else {

            # never reach
            return "Error: invalid action '$theAction'";
        }
    }

    if (@errorMessages) {
        writeDebug("spamlist=$text");
        return
            '<div class="foswikiAlert">'
          . join( "<br /> ", @errorMessages )
          . '</div>';

    }
    else {
        if (@infoMessages) {

            # SMELL: overwrites a concurrent save
            writeDebug("spamlist=$text");
            Foswiki::Func::saveFile( $fileName, $text );
            return '<br />' . join( "<br /> ", @infoMessages );

        }
        else {
            return 'Error: done nothing';
        }
    }
}

# =========================
sub _handleExcludeList {
    my ( $theAction, $theValue ) = @_;
    my $fileName = _makeFileName("exclude_list");
    writeDebug(
"_handleExcludeList( Action: $theAction, value: $theValue, file: $fileName )"
    );
    my $text = Foswiki::Func::readFile($fileName)
      || "# The exclude-list is a generated file, do not edit\n";
    if ( $theAction eq "read" ) {
        $text =~ s/^\#[^\n]*\n//s;
        return $text;
    }

    my @errorMessages;
    my @infoMessages;
    foreach my $item ( split( /,\s*/, $theValue ) ) {
        $item =~ s/^\s+//;
        $item =~ s/\s+$//;

        if ( $theAction eq "add" ) {
            if ( $text =~ /\n\Q$item\E\n/s ) {
                push @infoMessages,
                  "Warning: Exclude pattern '$item' is already on the list";
                next;
            }
            $text .= "$item\n";
            push @infoMessages, "Note: Added exclude pattern '$item'";
            unlink( _makeFileName("spam_regex") );    # remove cache

        }
        elsif ( $theAction eq "remove" ) {
            unless ( ($item) && ( $text =~ s/(\n)\Q$item\E\n/$1/s ) ) {
                push @errorMessages, "Error: Exclude pattern '$item' not found";
                next;
            }
            push @infoMessages, "Note: Removed exclude pattern '$item'";
            unlink( _makeFileName("spam_regex") );    # remove cache

        }
        else {

            # never reach
            return "Error: invalid action '$theAction'";
        }
    }

    if (@errorMessages) {
        writeDebug("excludelist=$text");
        return
            '<div class="foswikiAlert">'
          . join( "<br /> ", @errorMessages )
          . '</div>';

    }
    else {
        if (@infoMessages) {

            # SMELL: overwrites a concurrent save
            writeDebug("excludelist=$text");
            Foswiki::Func::saveFile( $fileName, $text );
            return '<br />' . join( "<br /> ", @infoMessages );

        }
        else {
            return 'Error: done nothing';
        }
    }
}

# =========================
sub _handleBlackList {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    my $action = $params->{action} || '';
    my $value  = $params->{value}  || '';
    my $text   = "";

    writeDebug(
"_handleBlackList( Action: $action, value: $value, topic: $theWeb.$theTopic )"
    );

    if ( $action eq "ban_show" ) {
        $text = _listBanList();
        $text =~ s/[\n\r]+$//os;
        $text =~ s/[\n\r]+/, /gos;

    }
    elsif ( $action eq "spam_show" ) {
        $text = _handleSpamList( "read", "" );
        $text =~ s/[\n\r]+$//os;
        $text =~ s/[\n\r]+/, /gos;

    }
    elsif ( $action eq "exclude_show" ) {
        $text = _handleExcludeList( "read", "" );
        $text =~ s/[\n\r]+$//os;
        $text =~ s/[\n\r]+/, /gos;

    }
    elsif ( $action eq "spam_show_n" ) {
        $text = _handleSpamList( "read", "" );

    }
    elsif ( $action eq "user_score" ) {
        $text = $userScore;

    }
    elsif ( $action =~
        /^(ban_add|ban_remove|spam_add|spam_remove|exclude_add|exclude_remove)$/
      )
    {
        my $anchor = "#BanList";
        if ( "$theWeb.$theTopic" eq "$installWeb.$pluginName" ) {
            my $wikiName = &Foswiki::Func::userToWikiName($user);
            if (
                Foswiki::Func::checkAccessPermission(
                    "CHANGE", $wikiName, "", $pluginName, $installWeb
                )
              )
            {
                if ( $action eq "ban_add" ) {
                    $text .= _handleBanList( "add", $value );
                    _writeLog("BANLIST add: $value, by user");
                }
                elsif ( $action eq "ban_remove" ) {
                    $text .= _handleBanList( "remove", $value );
                    _writeLog("BANLIST delete: $value by user");
                }
                elsif ( $action eq "spam_add" ) {
                    $text .= _handleSpamList( "add", $value );
                    $anchor = "#SpamList";
                    _writeLog("SPAMLIST add: $value, by user");
                }
                elsif ( $action eq "spam_remove" ) {
                    $text .= _handleSpamList( "remove", $value );
                    $anchor = "#SpamList";
                    _writeLog("SPAMLIST delete: $value by user");
                }
                elsif ( $action eq "exclude_add" ) {
                    $text .= _handleExcludeList( "add", $value );
                    $anchor = "#ExcludeList";
                    _writeLog("EXCLUDELIST add: $value, by user");
                }
                else {
                    $text .= _handleExcludeList( "remove", $value );
                    $anchor = "#ExcludeList";
                    _writeLog("EXCLUDELIST delete: $value by user");
                }
            }
            else {
                $text =
                  "Error: You do not have permission to maintain the list";
            }
        }
        else {
            $text = "Error: For use on $installWeb.$pluginName topic only";
        }
        $text .= " [ [[$theWeb.$theTopic$anchor][OK]] ]";
    }
    return $text;
}

# This sub returns '' if the IP address is not banned or the ban has expired
# If IP address is still banned we return the timestamp
sub _checkBanList {
    my ($remoteIP) = @_;
    my $fileName = _makeFileName("ban_list");
    my $text = Foswiki::Func::readFile($fileName) || '';
    if ( $text =~ /^($remoteIP)(\s+(\d+))?$/m ) {

        # Expire the IP if older than set by BANEXPIRE (0 means do not expire)
        # If the IP is from an old version of the plugin without timestamp
        # we expire is now.
        my $timestamp = $3 || 0;
        if ( $banExpire && ( time() > $timestamp + $banExpire ) ) {
            _handleBanList( 'remove', $remoteIP );
            return '';
        }
        else {
            return $timestamp;
        }
    }
    return '';
}

# List currently banned IP addresses after having pruned the expired IPs
# From a performance perspective we only want to expire all rarely
# But the feature will normally only be used in the BlackListPlugin topic
# so it will be very rare
sub _listBanList {
    my $fileName   = _makeFileName("ban_list");
    my $returnText = '';
    my $now        = time();
    my $ipExpired  = 0;
    my $text       = Foswiki::Func::readFile($fileName) || '';

    return '' unless $text;

    foreach my $line ( split( /\n/, $text ) ) {
        if ( $line =~ /^(\d[^\s]+)(\s+(\d+))?$/ ) {
            my $timestamp = $3 || 0;
            my $currentIP = $1;
            if ( $banExpire && ( $now > $timestamp + $banExpire ) ) {
                $text =~ s/$line\n//g;
                $ipExpired = 1;
            }
            else {
                my $minutesTillExpire =
                  int( ( $timestamp + $banExpire - $now ) / 60 );
                $minutesTillExpire = '-' unless $banExpire;
                $returnText .= "$currentIP ($minutesTillExpire)\n";
            }
        }
    }

    Foswiki::Func::saveFile( $fileName, $text ) if $ipExpired;
    return $returnText;
}

# Lists, adds, or removes IPs from the ban_list
sub _handleBanList {
    my ( $theAction, $theIPs ) = @_;
    my $fileName = _makeFileName("ban_list");
    writeDebug(
        "_handleBanList( Action: $theAction, IP: $theIPs, file: $fileName )");
    my $text = Foswiki::Func::readFile($fileName)
      || "# The ban-list is a generated file, do not edit\n";

    my @errorMessages;
    my @infoMessages;
    foreach my $theIP ( split( /,\s*/, $theIPs ) ) {
        $theIP =~ s/^\s+//;
        $theIP =~ s/\s+$//;

        if ( $theAction eq "add" ) {
            unless (
                ($theIP)
                && ( $theIP =~
                    /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/ )
              )
            {
                push @errorMessages, "Error: Invalid IP address '$theIP'";
                next;
            }

            if ( $text =~ /\n\Q$theIP\E\n/s ) {
                push @infoMessages,
                  "Warning: IP address '$theIP' is already on the list";
                next;
            }

            my $time = time();
            $text .= "$theIP $time\n";

            push @infoMessages, "Note: Added IP address '$theIP'";

        }
        elsif ( $theAction eq "remove" ) {

            # In case the user has upgraded from an old plugin version we also
            # allow the code to remove entries without a timestamp after the IP
            unless ( ($theIP) && ( $text =~ s/(\n)\Q$theIP\E( \d+)?\n/$1/s ) ) {
                push @errorMessages, "Error: IP address '$theIP' not found";
                next;
            }
            push @infoMessages, "Note: Removed IP address '$theIP'";
        }
        else {

            # never reach
            return "Error: invalid action '$theAction'";
        }
    }

    if (@errorMessages) {
        writeDebug("banlist=$text");
        return
            '<div class="foswikiAlert">'
          . join( "<br /> ", @errorMessages )
          . '</div>';

    }
    else {
        if (@infoMessages) {

            # SMELL: overwrites a concurrent save
            writeDebug("banlist=$text");
            Foswiki::Func::saveFile( $fileName, $text );
            return '<br />' . join( "<br /> ", @infoMessages );
        }
        else {
            return 'Error: done nothing';
        }
    }
}

# =========================
sub _handleEventLog {
    my ( $theIP, $theType, $theQueryString ) = @_;

    # read/update/save event logs
    my $fileName = _makeFileName("event_log");
    writeDebug(
        "_handleEventLog( IP: $theIP, type: $theType, query: $theQueryString )"
    );
    my $text = Foswiki::Func::readFile($fileName)
      || "# The event-list is a generated file, do not edit\n";
    my $time = time();
    $text .= "$time, $theIP, $theType";
    $text .= "__R_A_W__" if ( $theQueryString =~ /raw\=/ );
    $text .= "\n";
    my $limit = $time - $cfg{"period"};

    if ( ( $text =~ /([0-9]+)/ ) && ( $1 < $time - 8 * $cfg{"period"} ) ) {

        # for efficiency, clean up expired events only once in a while
        my @arr   = split( /\n/, $text );
        my $index = 0;
        my $limit = $time - $cfg{"period"};
        foreach (@arr) {
            if ( (/^([0-9]+)/) && ( $1 >= $limit ) ) {
                last;
            }
            $index++;
        }
        $text = "$arr[0]\n";    # keep comment
        $text .= join( "\n", @arr[ $index .. $#arr ] ) if ( $index <= $#arr );
        $text .= "\n";
    }
    Foswiki::Func::saveFile( $fileName, $text );

    # extract IP addresses of interest and calculate score
    my $score = 0;
    my $type  = "";
    foreach ( grep { / \Q$theIP\E\,/ } split( /\n/, $text ) ) {
        if ( (/^([0-9]+)\,[^\,]+\, ?(.*)/) && ( $1 >= $limit ) ) {
            $type = $2;
            if ( $type =~ /register/ ) {
                $score += $cfg{"ptReg"};
            }
            elsif ( $type =~ /(save|upload)/ ) {
                $score += $cfg{"ptChg"};
            }
            elsif ( $type =~ /__R_A_W__/ ) {
                $score += $cfg{"ptRaw"};
            }
            else {
                $score += $cfg{"ptView"};
            }
        }
    }
    return $score;
}

# =========================
sub _makeFileName {
    my ($name) = @_;
    my $dir = Foswiki::Func::getWorkArea($pluginName);
    return "$dir/_$name.txt";
}

# =========================
sub _writeLog {
    my ($theText) = @_;

    if ( Foswiki::Func::getPreferencesFlag("\U$pluginName\E_LOGACCESS") ) {
        if ( defined &Foswiki::Func::writeEvent ) {
            Foswiki::Func::writeEvent( 'blacklist', $theText );
        }
        else {

            # Pre 1.1 foswiki; there is no API for writing to the normal log
            # so we write directly to the log instead of using internal
            # functions which change once a year on average
            my $log = $Foswiki::cfg{LogFileName};
            my $now = time();
            my $stamp =
              Foswiki::Func::formatTime( $now, '$year$mo', 'servertime' );
            $log =~ s/%DATE%/$stamp/go;
            my $time = Foswiki::Func::formatTime( $now, 'iso', 'gmtime' );
            my $remoteAddr = $ENV{'REMOTE_ADDR'} || "";

# Example log line
# | 2009-03-25T22:18:45Z info | MyName | blacklist | Myweb.BlackListTest | /foswiki10/bin/save | 192.168.1.11 |
            my $message =
"| $time info | $user | blacklist | $web.$topic | $theText | $remoteAddr |";
            my $file;
            if ( open( $file, '>>', $log ) ) {
                print $file "$message\n";
                close($file);
            }
            else {
                Foswiki::Func::writeWarning(
"BlackListPlugin could not write to the normal log - message was $message"
                );
            }
        }

        writeDebug("BLACKLIST access, $web/$topic, $theText");
    }
}

# =========================
sub _handleNofollowLink {
    my ( $thePrefix, $theUrl, $thePostfix ) = @_;

    # Codev.SpamDefeatingViaNofollowAttribute: Add a rel="nofollow" to URL
    my $addRel = 0;
    my $text   = "$thePrefix$theUrl$thePostfix";
    $theUrl =~ m/^http/i        && ( $addRel = 1 );    # only for http and hhtps
    $theUrl =~ m/^$urlHost/i    && ( $addRel = 0 );    # not for own host
    $theUrl =~ m/foswiki\.org/i && ( $addRel = 0 );    # not for foswiki.org
    $thePostfix =~ m/^\s?rel/ && ( $addRel = 0 );      # prevent adding it twice

    $addRel = 0 if ( $noFollowAge > 0 && $topicAge > $noFollowAge ); # old topic

    return $text unless ($addRel);
    return "$thePrefix$theUrl rel=\"nofollow\"$thePostfix";
}

# =========================

1;
