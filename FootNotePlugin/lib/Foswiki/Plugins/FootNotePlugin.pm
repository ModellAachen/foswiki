# FootNotePlugin for Foswiki Collaboration Platform, http://foswiki.org/
#
# Copyright (C) 2009 Ian Bygrave, ian@bygrave.me.uk
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

# =========================
package Foswiki::Plugins::FootNotePlugin;

use strict;

require Foswiki::Func;
require Foswiki::Plugins;

use Foswiki::Plugins::FootNotePlugin::Note;

our $VERSION          = '$Rev:$';
our $RELEASE          = '$Date:$';
our $SHORTDESCRIPTION = 'Place footnotes at the end of a page.';

our $NO_PREFS_IN_TOPIC = 1;

# =========================
use vars qw(
  $web $topic $user $installWeb $pluginName
  $debug $header $footer $maintopic
  $stylesheet
);

$pluginName = 'FootNotePlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between ',
      __PACKAGE__, ' and Plugins.pm"
        );
        return 0;
    }

    # Get plugin debug flag
    $debug = $Foswiki::cfg{Plugins}{$pluginName}{Debug} || 0;

    # Get footnotes header
    $header = $Foswiki::cfg{Plugins}{$pluginName}{Header} || 0;
    Foswiki::Func::writeDebug( __PACKAGE__, " header = ${header}" ) if $debug;

    # Get footnotes footer
    $footer = $Foswiki::cfg{Plugins}{$pluginName}{Footer} || 0;
    Foswiki::Func::writeDebug( __PACKAGE__, " footer = ${footer}" ) if $debug;

    # Get configured stylesheet
    $stylesheet = $Foswiki::cfg{Plugins}{$pluginName}{CSS}
      || '%PUBURLPATH%/%SYSTEMWEB%/FootNotePlugin/styles.css';
    Foswiki::Func::writeDebug( __PACKAGE__, " stylesheet = ${stylesheet}" )
      if $debug;

    $maintopic = "$web.$topic";
    Foswiki::Plugins::FootNotePlugin::Note::reset();

    # Plugin correctly initialized
    Foswiki::Func::writeDebug( __PACKAGE__,
        "::initPlugin( $web.$topic ) is OK" )
      if $debug;
    return 1;
}

# =========================
# Store a footnote, returning the note placeholder.
sub storeNote {
    my ( $page, %params ) = @_;
    my $note = new Foswiki::Plugins::FootNotePlugin::Note( $page, %params );
    return $note->text();
}

# =========================
# Print a table of footnotes for the given page.
sub printNotes {
    my ( $page, %params ) = @_;
    return "" if ( $page ne $maintopic );

    my $result =
      Foswiki::Plugins::FootNotePlugin::Note::printNotes( $params{"LIST"} );
    return "" if ( $result eq "" );

    return Foswiki::Func::renderText( "\n\n$header\n\n$result\n\n$footer\n\n",
        $web );
}

# =========================
sub noteHandler {
    Foswiki::Func::writeDebug( __PACKAGE__, "::noteHandler( $_[0], $_[1] )" )
      if $debug;

    my %params = Foswiki::Func::extractParameters( $_[1] );

    $params{"_DEFAULT"} = $_[2] if ( $_[2] );

    return storeNote( $_[0], %params ) if ( exists $params{"_DEFAULT"} );

    return printNotes( $_[0], %params ) if ( exists $params{"LIST"} );

    return "";
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    Foswiki::Func::writeDebug( __PACKAGE__,
        "::commonTagsHandler( $_[1], $_[2] )" )
      if $debug;
    my $thistopic = "$_[2].$_[1]";

    if ( $_[3] ) {

        # bail out, handler called from an %INCLUDE{}%
        return;
    }

    # Translate all markup into the %FOOTNOTE{...}% form
    $_[0] =~
      s/%FOOTNOTELIST%/%STARTFOOTNOTE{LIST="$web.$topic"}%%ENDFOOTNOTE%/g;
    $_[0] =~ s/%FOOTNOTE{(.*?)}%/%STARTFOOTNOTE{$1}%%ENDFOOTNOTE%/sg;
    $_[0] =~
      s/{{(?:(\w+)::)(.*?)}}/%STARTFOOTNOTE{LABEL="$1"}%$2%ENDFOOTNOTE%/sg;
    $_[0] =~
      s/{{(?:(\w):)(.*?)}}/%STARTFOOTNOTE{LABELFORMAT="$1"}%$2%ENDFOOTNOTE%/sg;
    $_[0] =~ s/{{(.*?)}}/%STARTFOOTNOTE{}%$1%ENDFOOTNOTE%/sg;

    # Process all footnotes and footnote lists in page order.
    $_[0] =~
s/%STARTFOOTNOTE{(.*?)}%(.*?)%ENDFOOTNOTE%/&noteHandler("$_[2].$_[1]",$1,$2)/sge;
}

# =========================
sub postRenderingHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    #my $text = shift;
    # Print remaining footnotes
    $_[0] = $_[0] . printNotes( $maintopic, ( "LIST" => "ALL" ) );
    my $head = <<HERE;
<link rel="stylesheet" href="$stylesheet" type="text/css" media="all" />
HERE
    Foswiki::Func::addToHEAD( 'FOOTNOTEPLUGIN_LINKCSS', $head );
}

# =========================

1;

# vim:ts=2:sts=2:sw=2:et
