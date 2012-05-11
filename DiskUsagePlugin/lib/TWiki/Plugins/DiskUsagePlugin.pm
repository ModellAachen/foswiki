#! perl -w
use strict;

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional.
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# =========================
package TWiki::Plugins::DiskUsagePlugin
  ;    # change the package name and $pluginName!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $pluginName
  $debug $exampleCfgVar $usedColour $unusedColour
);

$VERSION    = '1.010';
$pluginName = 'DiskUsagePlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    $usedColour = TWiki::Func::getPluginPreferencesValue("UNUSED")
      || "lightblue";
    $unusedColour = TWiki::Func::getPluginPreferencesValue("UNUSED")
      || "lightcyan";

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

sub logSizes {
    my $debugSize   = -s $TWiki::cfg{DebugFileName};
    my $configSize  = -s $TWiki::cfg{ConfigurationLogName};
    my $logfile     = $TWiki::cfg{LogFileName};
    my $warningfile = $TWiki::cfg{WarningFileName};

    # allow for logfiles that have %DATE% in the filename...
    # obtain the size for the current log file...
    my $time = TWiki::Time::formatTime( time(), '$year$mo', 'servertime' );
    $logfile     =~ s/%DATE%/$time/go;
    $warningfile =~ s/%DATE%/$time/go;
    my $logSize     = -s $logfile;
    my $warningSize = -s $warningfile;
    if ( not $debugSize )   { $debugSize   = 0; }
    if ( not $warningSize ) { $warningSize = 0; }
    if ( not $logSize )     { $logSize     = 0; }
    if ( not $configSize )  { $configSize  = 0; }
    return
        "   * Debug log is $debugSize bytes\n"
      . "   * Current Warning log is $warningSize bytes\n"
      . "   * Current Access log is $logSize bytes\n"
      . "   * Configuration log is $configSize bytes\n";
}

sub diskusage {
    my $sandbox = $TWiki::sharedSandbox || $TWiki::sandbox;
    my $web = TWiki::Func::extractNameValuePair( @_, "web" );
    $web =~ s/\W//go;
    TWiki::Func::writeDebug("- ${pluginName}::diskusage($web)") if $debug;
    my $datadir = $TWiki::cfg{DataDir};
    my $cmd     = "/usr/bin/du -b $datadir/$web/*.txt 2>&1";
    my ( $result, $code ) = $sandbox->sysCommand($cmd);
    my @lines = split m#$/#, $result;
    my %usageByTopic;

    foreach my $line (@lines) {
        my ( $bytes, $file ) = split /\s+/, $line;
        $topic = $file;
        $topic =~ s!$datadir/(.*).txt!$1!;
        $topic =~ s!/!.!;
        $usageByTopic{$topic}{text}    = $bytes           || 0;
        $usageByTopic{$topic}{history} = ( -s "$file,v" ) || 0;
    }
    my $pubdir = $TWiki::cfg{PubDir};
    $cmd = "/usr/bin/du -b $pubdir/$web/* 2>&1";
    ( $result, $code ) = $sandbox->sysCommand($cmd);
    @lines = split m#$/#, $result;

    my %pubByTopic;

    foreach my $line (@lines) {
        my ( $bytes, $topic ) = split /\s+/, $line;
        $topic =~ s!$pubdir/(.*)!$1!;
        $topic =~ s!/!.!;
        $usageByTopic{$topic}{attachments} = $bytes || 0;
    }

    my $ans =
"| *Topic* | *Topic (bytes)* | *History (bytes)* | *Attachments (bytes)* | *Total (bytes)*| \n";
    my @topics = sort keys %usageByTopic;
    my $sum    = 0;
    foreach my $topic (@topics) {
        my $lineTotal =
          ( $usageByTopic{$topic}{text}        || 0 ) +
          ( $usageByTopic{$topic}{history}     || 0 ) +
          ( $usageByTopic{$topic}{attachments} || 0 );
        $ans .=
            "| $topic |  "
          . ( $usageByTopic{$topic}{text}        || "0" ) . "|  "
          . ( $usageByTopic{$topic}{history}     || "0" ) . "|  "
          . ( $usageByTopic{$topic}{attachments} || "0" ) . "|  "
          . $lineTotal . "|\n";
        $sum += $lineTotal;
    }
    $ans .= "| Total |||| " . $sum . "|\n";

    return $ans;
}

sub quotaData {
    my $cmd = "/usr/bin/quota -v 2>&1";
    my $sandbox = $TWiki::sharedSandbox || $TWiki::sandbox;

    my ( $result, $code ) = $sandbox->sysCommand($cmd);
    my @lines = split m#$/#, $result;

    my $lastLine = $lines[$#lines] || "";
    my @fields = split /\s+/, $lastLine;
    return ( $fields[2], $fields[3] );
}

sub quotaString {
    my ( $blocks, $quota ) = quotaData();
    if ($quota) {
        return "$blocks of $quota";
    }
    else {
        return "No Quota";
    }
}

sub quotaPercentage {
    my ( $blocks, $quota ) = quotaData();
    if ($quota) {
        return $blocks / $quota;
    }
    else {
        return 0;
    }
}

sub quotaGraph {
    my $length = quotaPercentage() * 100;
    if ($length) {
        return
"<TABLE WIDTH=100 CELLSPACING=0 CELLPADDING=0><TR><TD BGCOLOR=$usedColour WIDTH='$length'></TD><TD bgcolor=$unusedColour>&nbsp;</TD><TR></TABLE>";
    }
    else {
        return "";
    }
}

sub quota {
    return quotaGraph() . " " . quotaString();
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    my $web = $_[2];
    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    $_[0] =~ s/%DISKUSAGE%/&diskusage("web=\"$web\"")/ge;
    $_[0] =~ s/%DISKUSAGE{(.*?)}%/&diskusage($1)/ge;

    $_[0] =~ s/%QUOTA%/&quota()/ge;
    $_[0] =~ s/%LOGSIZES%/&logSizes()/ge;
}

# =========================

1;
