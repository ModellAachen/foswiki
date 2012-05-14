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
package TWiki::Plugins::EmbedBibPlugin
  ;    # change the package name and $pluginName!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $exampleCfgVar
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'EmbedBibPlugin';    # Name of this Plugin

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

 # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $exampleCfgVar = &TWiki::Func::getPreferencesValue("EMPTYPLUGIN_EXAMPLE")
      || "default";

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;

    $_[0] =~ s/%EMBEDBIB{(.*?)}%/&handleEmbedBib($1)/ge;

}

# =========================
sub handleEmbedBib {
    my $defaultWebName =
      TWiki::Func::getPreferencesValue("EMBEDBIBPLUGIN_DEFAULTWEBNAME");
    my $defaultTopic =
      TWiki::Func::getPreferencesValue("EMBEDBIBPLUGIN_DEFAULTTOPICNAME");
    my $defaultStyle =
      TWiki::Func::getPreferencesValue("EMBEDBIBPLUGIN_DEFAULTSTYLE");
    my $defaultSort =
      TWiki::Func::getPreferencesValue("EMBEDBIBPLUGIN_DEFAULTSORT");

    my $meta;
    my $text;

    my ($theAttributes) = @_;
    my $BibSelect1 =
      &TWiki::Func::extractNameValuePair( $theAttributes, "select1" );
    my $BibSelect2 =
      &TWiki::Func::extractNameValuePair( $theAttributes, "select2" );
    my $BibSelect3 =
      &TWiki::Func::extractNameValuePair( $theAttributes, "select3" );
    my $BibSelect4 =
      &TWiki::Func::extractNameValuePair( $theAttributes, "select4" );
    my $BibFile =
      &TWiki::Func::extractNameValuePair( $theAttributes, "bibfile" );
    my $WebName =
      &TWiki::Func::extractNameValuePair( $theAttributes, "webname" );
    my $Topic = &TWiki::Func::extractNameValuePair( $theAttributes, "topic" );
    my $Style = &TWiki::Func::extractNameValuePair( $theAttributes, "style" );
    my $Sort  = &TWiki::Func::extractNameValuePair( $theAttributes, "sort" );

    $WebName = $defaultWebName if $WebName eq "";
    $Topic   = $defaultTopic   if $Topic   eq "";
    $Style   = $defaultStyle   if $Style   eq "";
    $Sort    = $defaultSort    if $Sort    eq "";

    # Check for error
    return "EMBEDBIB Error: missing parameters"
      if ( $BibFile eq '' or $BibSelect1 eq '' );

    return "EMBEDBIB Error: $WebName not found"
      if ( !&TWiki::Func::webExists($WebName) );

    return "EMBEDBIB Error: $Topic not found"
      if ( !&TWiki::Func::topicExists( $WebName, $Topic ) );

    ( $meta, $text ) = &TWiki::Func::readTopic( $WebName, $Topic );
    my %args = $meta->findOne( "FILEATTACHMENT", $BibFile );

    return "EMBEDBIB Error: $BibFile not found" if ( !%args );

    # Translate '(' and ')' to ' " '
    # Translate '|' to '\|'
    foreach my $sel ( $BibSelect1, $BibSelect2, $BibSelect3, $BibSelect4 ) {
        $sel =~ s/(\(|\))/\"/g;
        $sel =~ s/\|/\\\|/g;
    }

    # BibTool command for BibSelect1
    my $bibtoolPath = '/usr/local/bin/bibtool';
    my $bibtoolargs = "-- select\'{$BibSelect1}\'";
    my $bibtoolfile = &TWiki::getPubDir() . "/${WebName}/${Topic}/${BibFile}";
    my $bibtoolcommand = "$bibtoolPath $bibtoolargs $bibtoolfile";

    # BibTool command for BibSelect2, BibSelect3, and BibSelect4
    foreach my $sel ( $BibSelect2, $BibSelect3, $BibSelect4 ) {
        if ( $sel ne '' ) {
            $bibtoolcommand .= " | $bibtoolPath -- select\'{$sel}\'";
        }
    }

    my $sandbox = $TWiki::sharedSandbox || $TWiki::sandbox;
    if ( $Style eq "bibtex" ) {
        return ( $sandbox->sysCommand($bibtoolcommand) )[0];
    }
    elsif ( $Style eq "html" ) {
        my $tmpBibFile      = '/tmp/twiki.bib';
        my $bibtex2htmlPath = '/usr/local/bin/bibtex2html';
        my $bibtex2htmlArgs = "-output - -sort $Sort";

        # This is the configuration string for bibtex2html to format
        # the output nicely
        my $bibtex2htmlConf = <<'EOF';
@string{ file_tag.start = " " }
@string{ file_tag.end = " " }
@string{ head_tag.start = " " }
@string{ head_tag.end = " " }
@string{ file_title_tag.start = " " }
@string{ file_title_tag.end = " " }
@string{ body_tag.start = " " }
@string{ body_tag.end = " " }
@string{ single_output_file_title = " " }
@string{ single_output_page_title = " " }
@string{ single_output_write_disclaimer = 0 }
@string{ single_output_write_date = 0 }
@string{ single_output_write_author = 0 }
@string{ single_output_write_credits = 0 }
@string{ single_output_header_of_body = " " }
@string{ page_title_tag.start = " " }
@string{ page_title_tag.end = " " }
@string{ page_subtitle_tag.start = " " }
@string{ page_subtitle_tag.end = " " }
@string{ item_tag.end = "</li>\n" }
EOF

        # We need to use a temporary file since bibtex2html does not accept
        # input from stdin
        open( TMPFILE, ">$tmpBibFile" ) or return "EMBEDBIB Error: fatal error";
        my ($tmpOut) = $sandbox->sysCommand($bibtoolcommand);
        print TMPFILE $tmpOut;
        print TMPFILE $bibtex2htmlConf;
        close TMPFILE;

        ($tmpOut) =
          $sandbox->sysCommand("$bibtex2htmlPath $tmpBibFile $bibtex2htmlArgs");
        unlink $tmpBibFile;
        return $tmpOut;
    }
}

1;
