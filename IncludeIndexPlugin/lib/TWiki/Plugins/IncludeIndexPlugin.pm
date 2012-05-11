#
# TWiki WikiClone ($wikiversion has version info)
#
# @(#)$Id: IncludeIndexPlugin.pm 6827 2005-10-07 19:13:28Z CrawfordCurrie $
#
# Copyright (C) 2002 Peter Klausner pklausner(at)bluewin.ch
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
# This is the IncludeIndex TWiki plugin.
#

# =========================
package TWiki::Plugins::IncludeIndexPlugin;    # change the package name!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# =========================
sub initPlugin {
    return 1;
}

# =========================
sub linkToInclude    # instead of handling %INCLUDE, return link to it
{
    my ( $theAttributes, $format ) = @_;
    my $incfile = &TWiki::Func::extractNameValuePair($theAttributes);
    my $linktext = " &bull;&nbsp;[[$incfile]]";    # tbd: get default from pref

    if ($format) {
        $linktext = $format;
        $linktext =~ s/\$topic/$incfile/;          # straight substition
        $linktext =~ s/\$page/$incfile/;

        if ( $linktext =~ /\$/ ) {    # delegate complex formats to %SEARCH:
            $linktext =
                '%SEARCH{topic="' 
              . $incfile
              . '" "." regex="on" nosearch="on"'
              . ' scope="topic" nototal="on" format="'
              . $format . '"}%';
        }
    }
    return $linktext;
}

# =========================
sub handleIncludeIndex    # clone of TWiki::handleIncludeFile
{
    my ( $theAttributes, $theWeb ) = @_;
    my $incfile = &TWiki::Func::extractNameValuePair($theAttributes);
    my $headers =
      &TWiki::Func::extractNameValuePair( $theAttributes, "headers" );
    my $format = &TWiki::Func::extractNameValuePair( $theAttributes, "format" );

    $headers = 4 unless $headers =~ /^[0-6]$/;

    # CrisBailiff, PeterThoeny 12 Jun 2000: Add security
    if ( defined($TWiki::securityFilter) ) {
        $incfile =~ s/$TWiki::securityFilter//go;    # zap anything suspicious
    }
    else {
        $incfile =~ s/$TWiki::cfg{NameFilter}//go;    # zap anything suspicious
    }
    $incfile =~ s/passwd//goi;    # filter out passwd filename

    if ($TWiki::doSecureInclude) {

        # Filter out ".." from filename, this is to
        # prevent includes of "../../file"
        $incfile =~ s/\.+/\./g;
    }

    if ( $incfile =~ m|^(.+)[./](.*)$| ) {
        $theWeb   = $1;
        $theTopic = $2;
    }
    else {
        $theTopic = $incfile;
    }

    my $text = "";
    my $meta = "";

    # set include web/filenames and current web/filenames
    {

        ( $meta, $text ) = &TWiki::Func::readTopic( $theWeb, $theTopic );

        # remove everything before %STARTINCLUDE% and after %STOPINCLUDE%
        $text =~ s/.*?%STARTINCLUDE%//os;
        $text =~ s/%STOPINCLUDE%.*//os;
    } # FIXME what if it's not a topic, is this possible given only dataDir above?

    my @lines = split /^/m, $text;
    $text = "";
    foreach $line (@lines) {
        if ( $line =~ /^\s*%INCLUDE{/ ) {
            $line =~ s/%INCLUDE{(.*?)}%/&linkToInclude($1, $format)/geo;
            $text .= $line;
        }
        elsif ( $headers && $line =~ /^----*\+/ ) {
            $line =~ s/^----*\+\+\+\+\s+/				0 <nop>/mg;
            $line =~ s/^----*\+\+\+\s+/			0 <nop>/mg;
            $line =~ s/^----*\+\+\s+/		0 <nop>/mg;
            $line =~ s/^----*\+\s+/	0 <nop>/mg;
            $text .= $line;
        }
        elsif ( $headers && $line =~ /^\s*<[Hh][1-4]/ ) {
            $line =~ s/<[Hh]4[^>]*>\s*/				0 <nop>/mg;
            $line =~ s/<[Hh]3[^>]*>\s*/			0 <nop>/mg;
            $line =~ s/<[Hh]2[^>]*>\s*/		0 <nop>/mg;
            $line =~ s/<[Hh]1[^>]*>\s*/	0 <nop>/mg;
            $text .= $line;
        }
    }
    chomp $text;
    return $text;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/geo;
    $_[0] =~ s/%INCLUDEINDEX{(.*?)}%/&handleIncludeIndex($1,$_[2])/geo;
}

# =========================
1;

