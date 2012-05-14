# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2003 Jonathan Cline, jcline.at.ieee.org
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
package TWiki::Plugins::SlashFilenamePlugin;

# This plugin implements rendering of slash paths detected in wiki text into
# RFC2396 URI specifications.

# Handles:
#   Microsoft Windows pathnames (drive spec or server spec)
#   Samba (SMB) pathnames (functionally same as MS-Windows)
#   unix style mount points
#   cvs source repository modules (functionally same as mount points)
#
# Example 1 wiki text, for MS-Windows pathnames:
#           H:\Documents\BestPractices.doc
#  anchors as:
#          file:///H:/Documents/BestPractices.doc
#
# Example 2 wiki text, for MS-Windows Sharing or Samba:
#           \\MYSERVER\DOCS\Corporate\NDA.doc
#  anchors as:
#          file:////MYSERVER/DOCS/Corporate/NDA.doc
#
# Example 3 wiki text, for cvs repository module:
#           /src/current/kern/arch/arm32/Makefile
#  might anchor as:
#  http://intranet/cvsweb.cgi/current/kern/arch/arm32/Makefile
#
# Note the use of seemingly redundant slashes for file://
# which are actually important:
#
#  absoluteURI = scheme ":" (heir_part)
#   hier_part  = ( net_path | abs_path ) [ "?" query ]
#   net_path   = "//" authority [ abs_path ]
#   abs_path   = "/" path_segments

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug
  %Shares
  $StrictFilenames
  %Mounts
  $EnableServerMap
  $EnableDriveMapExtReq
  $EnableDriveMapDelimited
  $EnableShareMap
  $EnableMountMap
  $FileChars
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'SlashFilenamePlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # XXX: Manual config required, since array prefs would be ugly

    # -----------------------------------------------------
    # EDIT THE BELOW TO CONFIGURE THIS PLUGIN
    # -----------------------------------------------------
    # SHARE CONFIGURATION %Shares
    #
    #   Format is:
    #   "fake mount point"   "file:////server/share_name_here"
    #   Not case sensitive.
    #
    #   i.e. wiki text:  "\doc\current\"
    #       will anchor as "file:////SERVER/blah/blah/doc/current\"
    %Shares = (
        'd2share',  'file:////d2fs1/d2share',
        'doc',      'file:////d2fs1/doc',
        'projects', 'file:////d2fs1/projects',
        'library',  'file:////d2fs1/library',
        'testvec',  'file:////d2fs1/testvec'
    );

    # MOUNT POINTS %Mounts
    #   Note, there are three slashes in file:/// mounts
    #       (two from file://, one from /directory)
    #   put file: mounts first, url: mounts (cvsweb modules) second
    %Mounts = (
        '/home/',
        'file:///home/',
        '/var/log/messages',
        'file:///var/log/messages',
        '/linux/kernel',

        # LXR ROOT URL:
        'http://lxr.linux.no/source/' .

          # MODULE:
          'arch/i386/kernel',
        '/src/sys/arch',

        # CVSROOT URL:
        'http://cvsweb.netbsd.org/bsdweb.cgi/' .

          # MODULE:
          'src/sys/arch',
        '/twiki/',

        # CVSROOT URL:
        'http://cvs.sourceforge.net/cgi-bin/viewcvs.cgi/twiki'

          # MODULE:
          . '/twiki/'
    );

    # CONFIGURATION FOR MODES
    #   In case you want to turn one type of anchoring completely off,
    #   set to zero.
    # XXX: Make these pref vars

    $EnableServerMap         = 1;
    $EnableDriveMapExtReq    = 1;
    $EnableDriveMapDelimited = 1;
    $EnableShareMap          = 1;
    $EnableMountMap          = 1;

    # ------------------------------------------------------------------------
    # END OF CONFIGURATION SECTION, DON'T EDIT ANY OF THE BELOW WITHOUT RISK
    # ------------------------------------------------------------------------

    # get Preferences
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG") || "off";

    # allow only URI-valid (RFC2396) chars in filenames
    # the following are reserved (not to be used): ;/?:@&=+$,
    # the following are ok: -_.!~*')(
    # but the following will cause problems: *)(
    $StrictFilenames = TWiki::Func::getPreferencesFlag("\U$pluginName\E_STRICT")
      || "off";
    $FileChars = '-.!~' . "'";
    if ( $StrictFilenames =~ /off/i ) {

        # allow some reserved/unwise characters in filenames (be careful)
        # definitely never allow ():<>?* or things will really break
        $FileChars .= '`$,[]+';

        # XXX: the reserved characters should be escaped instead of dis/allowed
    }
    $FileChars =~ s/(.)/\\$1/g;    # must escape the wierd ones, so escape all

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub endRenderingHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    my $url;
    my $sharepath;
    my $mount;

    TWiki::Func::writeDebug(
        "- ${pluginName}::endRenderingHandler( $web.$topic )")
      if $debug;

    # This handler is called by getRenderedVersion just after the line loop,
    # that is, after almost all XHTML rendering of a topic. <nop> tags are
    # removed after this.

    # --- Server Mapping
    # map \\server\share\path\name\file
    #  or //server/share/path/name/file
    #  to file:////server/share/path/name/file link
    # the //server/share part is required, the rest is gobbled
    $_[0] =~ s|
            # outside a word or link://
            ([\s])
            # slash slash
            [/\\]{2}
            # server name - no underlines
            # XXX: what's the correct max length?
            ([a-z\d\-]{1,30})
            # slash
            [/\\]
            # share name
            # XXX: what's the correct max length?
            ([\w\d\-]{1,30})
            # slash plus optional path/name
            (
                [\w$FileChars\\\/]{1,255}
            )
            |$1<a href="file:////$2/$3$4">//$2/$3$4</a>|gix

      # scheme slash slash
      # slash slash server
      # slash share slash path/name
      if $EnableServerMap;

    # --- Drive mapping, extension required
    #  x:/some/dir ectory/name of file.ext
    # spaces in filenames allowed with extension
    # This usage is purposely forced to display in uppercase (CP/M lives!)

    $_[0] =~ s!
            # outside a word or link
            ([^:a-z/]|[>])     
            # drive_letter colon
            ([a-z]\:)    
            # slash
            [/\\]                       
            # path & base name (may include extensions also)
            (
                ([\w$FileChars\\/]
                |
                [\s]){1,255}
            )
            # dot
            (\.)
            # final ending extension
            ([\w$FileChars]{1,9})
            !$1<a href="file:///$2/$3$5$6">\U$2/$3$5$6\E</a>!gix

      # scheme slash slash
      # slash drive_letter colon
      # slash path/name
      if $EnableDriveMapExtReq;

    # --- Drive mapping, delimiter required
    # map common filename with drive letter, delimiter required
    #  x:/some/dir ectory/name of file without extension
    # spaces in filenames allowed with \W boundary
    # This usage is purposely forced to display in uppercase
    $_[0] =~ s!
            ([\s>(])     # outside a word or link, or inside delimiter
            ([a-z]\:)    # drive_letter colon
            [/\\]                       # slash
            # path & base name
            # path/path path/path path \W
            (
                ([\w$FileChars\\/]
                |
                [\s]){1,255}
            )
            # delimiter matches any funny char
            ([\W]{1})             
#           # delimiter matches only html delimiter < or ):
#            ([\<)\:]{1})             
            !$1<a href="file:///$2/$3">\U$2/$3\E</a>$5!gix

      # scheme slash slash
      # slash drive_letter colon
      # slash path/name
      if $EnableDriveMapDelimited;

    # map shares
    # spaces in filenames not allowed (maybe in next version?)

    # XXX: optimize this loop
    if ($EnableShareMap) {
        foreach $share ( keys %Shares ) {
            $sharepath = $Shares{$share};
            $_[0] =~ s|
                    # outside a word or link
                    ([\s])     
                    # slash
                    [/\\]               
                    # sharename
                    ($share)            
                    # slash
                    [/\\]               
                    # path/name (required)
                    (
                        [\w$FileChars\\\/]{1,255}
                    )
                    |$1<a href="$sharepath/$3">/$2/$3</a>|gix;
        }
    }

    # map mount points
    # spaces in filenames not allowed

    # XXX: optimize this loop
    if ($EnableMountMap) {
        foreach $mount ( keys %Mounts ) {
            $url = $Mounts{$mount};
            $_[0] =~ s!
                    # outside a word or link
                    ([^\w$FileChars\\/])
                    # "directory" - key
                    ($mount)         
                    # path - text to concatenate to url, may include slash
                    (
                        [\w$FileChars\\/]{0,255}
                    )
                    !$1<a href="$url$3">$2$3</a>!gix;
        }
    }
}

1;
