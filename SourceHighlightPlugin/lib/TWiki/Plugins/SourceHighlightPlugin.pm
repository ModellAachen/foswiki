# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2003 Chris Winters, chris@cwinters.com
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

########################################
# This plugin is based on BeautifierPlugin except it uses the GNU
# source-highlight package to do the work.
#
# NOTE: We use temp files during the request but clean them up when
# we're done.

package TWiki::Plugins::SourceHighlightPlugin;

# $Id: SourceHighlightPlugin.pm 6827 2005-10-07 19:13:28Z CrawfordCurrie $

use strict;
use vars qw( $VERSION $RELEASE );

use File::Spec;
use File::Temp;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# These are set at initialization

my $DEBUG        = 0;
my $DEFAULT_LANG = undef;
my $COMMAND      = undef;
my $FORMAT_CLASS = undef;

# If source-highlight gets upgraded to handle new languages, update
# this listing accordingly

my %LANGS = map { $_ => 1 } qw( cpp flex java perl php3 prolog python );

# Default values for the configuration above

my $DEFAULT_SPACE        = 4;
my $DEFAULT_FORMAT_CLASS = 'codefragment';

sub initPlugin {
    my ( $topic, $web, $user, $install_web ) = @_;

    # Ensure we're up-to-date
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between SourceHighlightPlugin and Plugins.pm");
        return 0;
    }

# Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
# $exampleCfgVar = &TWiki::Func::getPreferencesValue( "EMPTYPLUGIN_EXAMPLE" ) || "default";

    # Get plugin debug flag

    my $key = 'SOURCEHIGHLIGHTPLUGIN';
    $DEBUG = TWiki::Func::getPreferencesFlag("${key}_DEBUG");

    # This should be set to something like
    # /usr/local/bin/source-highlight or source-highlight-cgi

    my $bin = TWiki::Func::getPreferencesValue("${key}_BINARY");
    unless ( $bin and $bin =~ /source\-highlight(\-cgi)?$/ and -x $bin ) {
        TWiki::Func::writeWarning("Invalid source-highlight binary [$bin]");
        return 0;
    }

    # It's okay if this is empty, just means that there's no default

    $DEFAULT_LANG = TWiki::Func::getPreferencesValue("${key}_DEFAULTLANGUAGE");

    # It's okay if these two are empty since we have a reasonable
    # default defined

    my $spacing = TWiki::Func::getPreferencesValue("${key}_SPACE")
      || $DEFAULT_SPACE;
    $FORMAT_CLASS = TWiki::Func::getPreferencesValue("${key}_FORMATCLASS")
      || $DEFAULT_FORMAT_CLASS;

    $COMMAND = "$bin -f html -t $spacing -s %s";

    $DEBUG && _w("SourceHighlightPlugin will use command [$COMMAND]");
    $DEBUG
      && _w(
        "TWiki::Plugins::SourceHighlightPlugin::initPlugin( $web.$topic ) OK");

    return 1;
}

# Args: ( $text, $topic, $web )

sub commonTagsHandler {

# &TWiki::Func::writeDebug( "- SourceHighlightPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;
    $_[0] =~ s/%CODE({"([a-z0-9]+)"})?%(.*?)%ENDCODE%/&render_code($2, $3)/gseo;
}

sub render_code {
    my ( $lang, $data ) = @_;

    # Ensure the command is defined

    unless ($COMMAND) {
        return error_msg( $data,
            'Must define path to binary. (See log at initialization.)' );
    }

    # Ensure we have a valid language choice

    $lang ||= $DEFAULT_LANG;
    my $lookup_lang = lc $lang;
    unless ( $lookup_lang and $LANGS{$lookup_lang} ) {
        my $valid_lang = join( ', ', sort keys %LANGS );
        return error_msg( $data,
            "Unable to handle '$lang' syntax. Please use one of $valid_lang" );
    }

    # Create a temporary file to hold the data; we clean it up before
    # the routine ends

    my $tmp_dir = File::Spec->tmpdir();
    my $tmp_file = File::Spec->catdir( $tmp_dir, mktemp('twikishp-XXXXXX') );
    eval { open( TMP, "> $tmp_file" ) || die $! };
    if ($@) {
        return error_msg(
            $data,
            "Failed to open working file",
            "Failed to open temp file [$tmp_file] for writing: $@"
        );
    }
    print TMP $data;
    close(TMP);

    # Send the temp file data to the source-highlight command,
    # capturing the output in @lines

    my $this_cmd = sprintf( $COMMAND, $lookup_lang );
    eval { open( CMD, "$this_cmd < $tmp_file |" ) || die $! };
    if ($@) {
        return error_msg(
            $data,
            "Cannot open pipe to program",
            "Failed to open pipe to command [$this_cmd]"
        );
    }
    my @lines = <CMD>;
    close(CMD);

    unlink($tmp_file)
      || TWiki::Func::writeWarning(
" - SourceHighlightPlugin Error: cannot delete temp file [$tmp_file]: $!"
      );

    # Cosmetic: Get rid of lines 1 and 2 (0-based), plus the
    # next-to-last line

    splice( @lines, 1, 2 );
    splice( @lines, scalar @lines - 2, 1 );

    return join( '', qq(<div class="$FORMAT_CLASS">\n), @lines, qq(\n</div>) );
}

sub error_msg {
    my ( $data, $msg, $admin_msg ) = @_;
    $admin_msg ||= $msg;
    TWiki::Func::writeWarning(" - SourceHighlightPlugin Error: $msg");
    return join( "\n",
        qq(<b>SourceHighlightPlugin Error: $msg</b>),
        qq(<div class="$FORMAT_CLASS"><pre>$data</pre></div>) );
}

sub _w {
    TWiki::Func::writeDebug( join( '', @_ ) );
}

1;

