# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2000-2003 Peter Thoeny, peter@thoeny.com
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
# This is the default TWiki plugin. Use EmptyPlugin.pm as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
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
# For increased performance, unused handlers are disabled. To
# enable a handler remove the leading DISABLE_ from the function
# name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# =========================
package TWiki::Plugins::MovableTypePlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $renderingWeb $MT_DIR $mt $defaultBlogId
  $blog_name $cfg $path $viewScript $searchScript
);

use lib ('/home/trommett/public_html/cgi-bin/lib/');
use lib ('/home/trommett/public_html/cgi-bin/extlib/');

use MT;
use MT::ConfigMgr;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'MovableTypePlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin preferences
    $MT_DIR = &TWiki::Func::getPreferencesValue("MOVABLETYPEPLUGIN_DIR")
      || "/home/user/public_html/mt/";
    $defaultBlogId =
      &TWiki::Func::getPreferencesValue("MOVABLETYPEPLUGIN_BLOG_ID") || 1;

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    $renderingWeb = $web;

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( MT_DIR = $MT_DIR )")
      if $debug;
    TWiki::Func::writeDebug(
"- TWiki::Plugins::${pluginName}::initPlugin( defaultBlogId = $defaultBlogId )"
    ) if $debug;

    $mt = MT->new(
        Config    => $MT_DIR . "mt.cfg",
        Directory => $MT_DIR
    ) || TWiki::Func::writeDebug( $MT->errstr );
    $cfg  = MT::ConfigMgr->instance;
    $path = $cfg->CGIPath;
    $path .= '/' unless $path =~ m!/$!;
    $viewScript = $path . $cfg->ViewScript;
    TWiki::Func::writeDebug(
"- TWiki::Plugins::${pluginName}::initPlugin( viewScript = $viewScript ) is OK"
    ) if $debug;

    $searchScript = $path . $cfg->SearchScript;
    TWiki::Func::writeDebug(
"- TWiki::Plugins::${pluginName}::initPlugin( searchScript = $searchScript ) is OK"
    ) if $debug;

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
    $_[0] =~ s/( *)%MOVABLETYPE{(.*?)}%/&_handleMovableTypeTag( $1, $2 )/geo;

    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
}

# =========================
sub startRenderingHandler {
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug("- ${pluginName}::startRenderingHandler( $_[1] )")
      if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    $renderingWeb = $_[1];
}

# =========================
sub outsidePREHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::outsidePREHandler( $renderingWeb.$topic )" ) if $debug;

# This handler is called by getRenderedVersion, once per line, before any changes,
# for lines outside <pre> and <verbatim> tags.
# Use it to define customized rendering rules

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/go;

    # render deprecated *_text_* as "bold italic" text:
    $_[0] =~
      s/(^|\s)\*_([^\s].*?[^\s])_\*(\s|$)/$1<strong><em>$2<\/em><\/strong>$3/go;

# Use alternate %Web:WikiName% syntax (versus the standard Web.WikiName).
# This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/(^|\s|\()\%([^\s].*?[^\s]):([^\s].*?[^\s])\%/&TWiki::internalLink($2,$3,"$2:$3",$1,1)/geo;

# Use "forced" non-WikiName links (i.e. %Linkname%)
# This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/(^|\s|\()\%([^\s].*?[^\s])\%/&TWiki::internalLink($web,$2,$2,$1,1)/geo;

# Use "forced" non-WikiName links (i.e. %Web.Linkname%)
# This is an old JosWiki render option combined with the new Web.LinkName notation
# (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/(^|\s|\()\%([a-zA-Z0-9]+)\.(.*?[^\s])\%(\s|\)|$)/&TWiki::internalLink($2,$3,$3,$1,1)/geo;

# Use <link>....</link> links
# This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/<link>(.*?)<\/link>/&TWiki::internalLink("",$web,$1,$1,"",1)/geo;
}

# =========================
sub _handleMovableTypeTag {
    TWiki::Func::writeDebug("- ${pluginName}::_handleMovableTypeTag( $_[1] )")
      if $debug;

    my ( $thePre, $theArgs ) = @_;
    my ( $cat, $cat_id );
    my $text = "";

    #     my $text = "$thePre<noautolink>";

    my $blog_id = &TWiki::Func::extractNameValuePair( $theArgs, "blog_id" )
      || $defaultBlogId;
    my $category = &TWiki::Func::extractNameValuePair( $theArgs, "category" );
    my $format   = &TWiki::Func::extractNameValuePair( $theArgs, "format" );
    TWiki::Func::writeDebug("- ${pluginName}::_handleMovableTypeTag( $format )")
      if $debug;
    my $view_template =
      &TWiki::Func::extractNameValuePair( $theArgs, "view_template" );
    my $search = &TWiki::Func::extractNameValuePair( $theArgs, "search" );
    my $search_template =
      &TWiki::Func::extractNameValuePair( $theArgs, "search_template" );

    #     $format =~ s/\$n([^a-zA-Z])/\n$1/gos; # expand "$n" to new line
    #     $format =~ s/([^\n])$/$1\n/os;        # append new line if needed

    my $version = MT->VERSION;
    my $blog    = MT::Blog->load($blog_id);
    $blog_name = $blog->name;
    TWiki::Func::writeDebug(
        "- ${pluginName}::_handleMovableTypeTag( $blog_name )")
      if $debug;

    if ($category) {
        TWiki::Func::writeDebug(
            "- ${pluginName}::_handleMovableTypeTag( $category )")
          if $debug;
        $cat = MT::Category->load( { label => $category } );
        $cat_id = $cat->id;
    }

    if ($format) {
        TWiki::Func::writeDebug(
            "- ${pluginName}::_handleMovableTypeTag( cat_id = $cat_id )")
          if $debug;
        my $line = "";
        $line = $format;
        $line =~ s/\$blog_id/$blog_id/gos;
        $line =~ s/\$blog_name/$blog_name/gos;
        $line =~ s/\$version/$version/gos;
        $line =~ s/\$cat_id/$cat_id/gos;
        $line =~ s/\$category/$category/gos;
        $text .= $line;
        TWiki::Func::writeDebug(
            "- ${pluginName}::_handleMovableTypeTag( $text )")
          if $debug;
    }

    if ($view_template) {
        $text = TWiki::handleIncludeUrl(
            "$viewScript/$blog_id/section/$cat_id/$view_template");
    }

    if ($search) {
        $text = TWiki::handleIncludeUrl(
            "$searchScript?Template=$search_template\&search=$search");
    }

    return $text;
}

# =========================

1;

