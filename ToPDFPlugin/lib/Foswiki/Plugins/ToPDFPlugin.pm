#!/usr/local/bin/perl -wI.
#
# This script Copyright (c) 2008 Impressive.media
# and distributed under the GPL (see below)
#
# Based on parts of GenPDF, which has several sources and authors
# This script uses html2pdf as backend, which is distributed under the LGPL
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

=pod

=head1 Foswiki::Plugins::ToPDFPlugin

FosWiki::Plugins::ToPDFPlugin - Displays Foswiki topics as PDF using html2pdf

=head1 DESCRIPTION

See the ToPDFPlugin.

=head1 METHODS

Methods with a leading underscore should be considered local methods and not called from
outside the package.

=cut

package Foswiki::Plugins::ToPDFPlugin;

use strict;

require CGI;
require Foswiki::Func;
require Foswiki::Plugins;    # For the API version
require Foswiki::UI::View;
use File::Temp qw( tempfile );
use File::Basename;
use Error qw( :try );
use URI::Escape;
use Encode;
use Encode::Encoding;
use HTML::TreeBuilder;

#use utf8;

use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$| = 1;    # Autoflush buffers

our $query;
our %tree;
our %prefs;

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package.
use HTML::Parser;

# This should always be $Rev$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '(1.6)';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION = 'Exports Foswiki topics as PDF using html2pdf';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use preferences
# stored in the plugin topic. This default is required for compatibility with
# older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, use $Foswiki::cfg entries set in LocalSite.cfg, or
# if you want the users to be able to change settings, then use standard Foswiki
# preferences that can be defined in your %USERSWEB%.SitePreferences and overridden
# at the web and topic level.
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'ToPDFPlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }
    Foswiki::Func::registerRESTHandler( 'convert', \&toPDF );
    Foswiki::Func::registerTagHandler( "TOPDFBUTTON", \&_showButton );
    Foswiki::Func::registerTagHandler( "TOPDFBUTTONLINK",
        \&_getButtonLinkOnly );
    return 1;
}

sub _getRenderedView {
    my ( $webName, $topic ) = @_;

    # Read topic data.
    my ( $meta, $text ) = Foswiki::Func::readTopic( $webName, $topic );

    # FIXME - must be a better way?
    if ( $text =~ /^http.*\/.*\/oops\/.*oopsaccessview$/ ) {
        Foswiki::Func::redirectCgiQuery( $query, $text );
    }
    $text =~ s/\%TOC({.*?})?\%//g;    # remove Foswiki TOC
                                      #Expand and render the topic text
    $text =
      Foswiki::Func::expandCommonVariables( $text, $topic, $webName, $meta );

    $text = Foswiki::Func::renderText($text);

    # Expand and render the template
    my $tmpl =
      Foswiki::Func::readTemplate( "viewprint",
        $Foswiki::cfg{Plugins}{ToPDFPlugin}{PrintTemplate} );
    $tmpl =
      Foswiki::Func::expandCommonVariables( $tmpl, $topic, $webName, $meta );
    $tmpl =~ s/%TEXT%/$text/g;
    $tmpl = Foswiki::Func::renderText( $tmpl, $webName );

    return $tmpl;
}

=head2 _fixHtml($html)

Cleans up the HTML as needed before htmldoc processing. This currently includes fixing
img links as needed, removing page breaks, META stuff, and inserting an h1 header if one
isn't present. Returns the modified html.

=cut

sub _fixHtml {
    my ( $html, $topic, $webName, $refTopics ) = @_;
    my $docroot = Foswiki::Func::getPubDir();
    $docroot =~ s/^(.*)\/pub/$1/sg;
    my $urlhost = Foswiki::Func::getUrlHost();

#replace all @import urls with  <link href=""> with absolute pathes, to fetch them all locally
    while ( $html =~
s/(<style)([^<>]*)(>)([^<>]?)(\s*)(\@import url\(['|"])(\/[^']+)(['|"]\);)(.*)/<link rel="stylesheet"$2 href="$docroot$7">\n$1$2$3$9/gi
      )
    {
    }

    my $tree = HTML::TreeBuilder->new_from_content($html);

# replace all occurences of urlhost with the full local path to fetch them locally
    foreach my $e ( $tree->look_down( _tag => "img", src => qr|^$urlhost| ) ) {
        my $tmp = $e->attr("src");
        $tmp =~ s/^$urlhost/$docroot/;
        $e->attr( "src", $tmp );
    }

# all pathes are relative to docroot should get expanded to absolute paths for the local-fetcher
    $_->attr( "src", $docroot . $_->attr("src") )
      for $tree->look_down( _tag => "img", src => qr|^(?!$docroot)| );

    $_->delete() for $tree->look_down( _tag => "script" );
    $_->delete() for $tree->look_down( _tag => "meta" );
    $_->delete()
      for $tree->look_down( _tag => "link", rel => qr|^(?!stylesheet)| );

    $html = $tree->as_HTML( "", "\t" );

    # remove <nop> tags
    $html =~ s/<nop>//g;

    #remove TOC links, as they are represented as a linebreak
    $html =~ s/<a name="(.*?)"><\/a>//g;

    #remove toc links
    $html =~ s/<a href="#toc" class="tocLink">&uarr;<\/a>//g;

    # remove doctype
    $html =~ s/<!DOCTYPE[^>]*>//gsi;

    #

  # remove all page breaks
  # FIXME - why remove a forced page break? Instead insert a <!-- PAGE BREAK -->
  #         otherwise dangling </p> is not cleaned up
    $html =~
s/(<p(.*) style="page-break-before:always")/\n<!-- PAGE BREAK -->\n<p$1/gis;

    # remove %META stuff
    $html =~ s/%META:\w+{.*?}%//gs;

    # As of HtmlDoc 1.8.24, it only handles HTML3.2 elements so
    # convert some common HTML4.x elements to similar HTML3.2 elements
    # TODO: do we need this for html2pdf?
    #$html =~ s/&ndash;/&shy;/g;
    #$html =~ s/&[lr]dquo;/"/g;
    #$html =~ s/&[lr]squo;/'/g;
    #$html =~ s/&brvbar;/|/g;

    # convert FoswikiNewLinks to normal text
    $html =~ s/<span class="foswikiNewLink".*?>([\w\s]+)<.*?\/span>/$1/gs;

  # Fix the image tags to use hard-disk path rather than relative url paths for
  # images.  Needed if wiki requires authentication like SSL client certifcates.
  # Fully qualify any unqualified URLs (to make it portable to another host)
    my $url   = Foswiki::Func::getUrlHost();
    my $pdir  = Foswiki::Func::getPubDir();
    my $purlp = Foswiki::Func::getPubUrlPath();

    # link internally if we include the topic
    for my $wikiword (@$refTopics) {
        $url = Foswiki::Func::getScriptUrl( $webName, $wikiword, 'view' );
        $html =~ s/([\'\"])$url$1/$1#$wikiword$1/g;    # not anchored
        $html =~ s/$url(#\w*)/$1/g;                    # anchored
    }

    # change <li type=> to <ol type=>
    $html =~ s/<ol>\s+<li\s+type="([AaIi])">/<ol type="$1">\n<li>/g;
    $html =~ s/<li\s+type="[AaIi]">/<li>/g;

    return $html;
}

=podheader

=head2 toPDF

This is the core method to convert the current page into PDF format.

=cut

sub toPDF {
    my $session = shift;

# using Foswiki::UI so i have a sessin object. There had been some issues with the user / caller of the script and
# with the old implementation. But there have also been thoughts of the Foswiki::UI way being to "heavy" for this puporse
# SMELL: maybe Foswiki::UI should not be used. RestHandler is an option

# this is for letting Foswiki::Func functions work properly ( as in plugin scope )
# $Foswiki::Plugins::SESSION=$session;
# initialize module wide variables
    my $query = $session->{cgiQuery};

    # Initialize Foswiki
    my $topic    = $session->{topicName};
    my $webName  = $session->{webName};
    my $userName = Foswiki::Func::getWikiName();
    my $theUrl   = $query->url;

    # Check for existence
    Foswiki::Func::redirectCgiQuery( $query,
        Foswiki::Func::getOopsUrl( $webName, $topic, "oopsmissing" ) )
      unless Foswiki::Func::topicExists( $webName, $topic );

    my @webTopicPairs;

# FEATURE: viewPDF should get a list of topics, which have to be rendered to one PDF.
#  This could be e.g. a parent topic with all its childs or just a set of topics out of diffrent webs etc.
#  Let this be as "powerfull" as possible. SMELL this feature is interferring with PublishAddon
# this is a dummy, as we only support one, the current topic
    $webTopicPairs[0]{'web'}   = $webName;
    $webTopicPairs[0]{'topic'} = $topic;
    my @topicHTMLfiles = _renderTopics( $session, @webTopicPairs );
    my $inputFile = $topicHTMLfiles[0];

# we use he first topic tmp file as pdf name, so something like html2pdfXXXX will be the result,
# nice for debugging if needed. outputFilen is not allowed to have a fileext as it will be escaped
# .pdf will be attached to the filename by html2pdf automatically
    my ( $outputFilename, $outputDir, $suffix ) =
      fileparse( $inputFile, ".html" );

# TODO: maybe this should be changed latter, to process all html files. Yet, this is a hack for supporting only the current topic
    my $finalPDF = $outputDir . $outputFilename . ".pdf";

# the command to be run to convert our html file(s) to pdf, BACKEND
# we pass webName, topic and username to be used as paramaters in header/footer.
# FEATURE: maybe construct the header/footer out of Foswiki topics or similar, so they can be customized user-friendlier
    my $pubDir = Foswiki::Func::getPubDir();

# SMELL the path to the php binary should be configureable or the script shoudl depend on it to be in PATH

#have to be utf8 to let html2pdf work properly. They will be converted to the specified encoding in html2pdf later.
    my $utf8topic    = encode( "utf8", $topic );
    my $utf8webName  = encode( "utf8", $webName );
    my $utf8userName = encode( "utf8", $userName );
    my $headerFile   = _getHeaderFile();
    my $footerFile   = _getFooterFile();
    my $Cmd =
"/usr/bin/php $pubDir/System/ToPDFPlugin/topdf.php \"$inputFile\" \"$outputFilename\" \"$outputDir\" \"$utf8webName/$utf8topic\" \"$utf8userName\" \"$headerFile\" \"$footerFile\"";

    # actually run the converting command
    system($Cmd);
    if ( $? == -1 ) {
        die "Failed to run html2pdf ($Cmd): $!\n";
    }
    elsif ( $? & 127 ) {
        printf STDERR "child died with signal %d, %s coredump\n",
          ( $? & 127 ), ( $? & 128 ) ? 'with' : 'without';
        die "Conversion failed: '$!'";
    }
    else {
        printf STDERR "child exited with value %d\n", $? >> 8
          unless $? >> 8 == 0;
    }

    #  output the HTML header and the output of HTMLDOC
    my $cd = "filename=${webName}_$topic.";
    print CGI::header(
        -TYPE                => 'application/pdf',
        -Content_Disposition => $cd . 'pdf'
    );

    open my $ofh, '<', $finalPDF
      or die "I cannot open $finalPDF for reading, cap'n: $!";
    while (<$ofh>) {
        print;
    }
    close $ofh;

    # Cleaning up temporary files
    unlink $finalPDF;
    unlink @topicHTMLfiles;
    unlink $headerFile;
    unlink $footerFile;
    return;
}

sub _renderTopic {
    my ( $session, $webName, $topic ) = @_;
    my $htmlData = _getRenderedView( $webName, $topic );

# clean up the HTML, remove things not working with html2pdf backend
# SMELL: really really important and critical function, should be thought especially well
    $htmlData = _fixHtml( $htmlData, $topic, $webName );

    # The data returned also includes the header. Remove it.
    #$htmlData =~ s|.*(<!DOCTYPE)|$1|s;
    #$htmlData =~ s|.*(import)|$1|s;
    return $htmlData;
}

sub _renderTopics {
    my ( $session, @webTopicPairs ) = @_;
    my @topicHTMLfiles;
    foreach my $webTopicPair (@webTopicPairs) {
        my ( $webName, $topic ) =
          ( $webTopicPair->{'web'}, $webTopicPair->{'topic'} );
        my $topicAsHTML = _renderTopic( $session, $webName, $topic );

        # Save this to a temp file for converting by command line
        my ( $cfh, $newFile ) = tempfile(
            'html2pdfXXXX',

            DIR    => "/tmp",
            UNLINK => 0,        # DEBUG
            SUFFIX => '.html'
        );
        @topicHTMLfiles = ( @topicHTMLfiles, $newFile );

        # throw in our content
        print $cfh $topicAsHTML;
        close($cfh);
    }
    return @topicHTMLfiles;
}

sub _getHeaderFile {

    my ($session) = @_;
    my ( $cfh, $path ) = tempfile(
        'html2pdfHeaderXXXX',
        DIR    => "/tmp",
        UNLINK => 0,
        SUFFIX => '.html'
    );
    my $topicAsHTML = _renderTopicContentOnly( "System", "ToPDFPluginHeader" );
    print $cfh $topicAsHTML;
    close($cfh);
    return $path;
}

sub _getFooterFile {
    my ($session) = @_;
    my ( $cfh, $path ) = tempfile(
        'html2pdfFooterXXXX',
        DIR    => "/tmp",
        UNLINK => 0,
        SUFFIX => '.html'
    );
    my $topicAsHTML = _renderTopicContentOnly( "System", "ToPDFPluginFooter" );
    print $cfh $topicAsHTML;
    close($cfh);
    return $path;
}

sub _renderTopicContentOnly {
    my ( $webName, $topic ) = @_;

    # Read topic data.
    my ( $meta, $text ) = Foswiki::Func::readTopic( $webName, $topic );

    $text =~ s/\%TOC({.*?})?\%//g;    # remove Foswiki TOC
                                      #Expand and render the topic text
    $text =
      Foswiki::Func::expandCommonVariables( $text, $topic, $webName, $meta );

    $text = Foswiki::Func::renderText($text);
    $text =~ s/<nop>//g;
    return $text;
}

sub _showButton {
    my ( $this, $params, $topic, $web ) = @_;
    $web   = $params->{'web'}   || $web;
    $topic = $params->{'topic'} || $topic;
    my $label = $params->{'label'} || 'PDF';

    my $button = "";
    $button = _getButtonLinkOnly();
    $button = "<a href='$button'>$label</a>";
    return $button;
}

sub _getButtonLinkOnly {
    my ( $this, $params, $topic, $web ) = @_;
    $web   = $params->{'web'}   || $web;
    $topic = $params->{'topic'} || $topic;

    return
        Foswiki::Func::getScriptUrlPath()
      . "/rest/ToPDFPlugin/convert/?topic=$web.$topic"
      . '&t=%GMTIME{"$epoch"}%';
}
1;

# vim:et:sw=3:ts=3:tw=0
