#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
# Copyright (C) 2004 Rafael Alvarez, soronthar@yahoo.com
#
# Authors (in alphabetical order)
#   Andrea Bacchetta
#   Richard Bennett
#   Anthon Pang
#   Andrea Sterbini
#   Martin Watt
#   Thomas Eschner
#   Rafael Alvarez (RAF)
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

package TWiki::Plugins::XpTrackerPlugin::HtmlUtil;
use TWiki::Func;
use TWiki::Plugins::XpTrackerPlugin::Status;
use strict;

###########################
# gaugeLite
#
# display gauge using html table. Pass in int value for percentange done
# TODO: Colors for TODO and DONE can be customized
# TODO: Another color for COMPLETED
sub gaugeLite {
    my $done = $_[0];
    my $todo = 100 - $done;

    my $width     = 80;
    my $cellWidth = $width / 10;

    my $line =
      '<table border="0" cellspacing="2" height="20" width="' . $width . '">';
    $line .= '<tr>';

    #my $line="<table height=20 width=\"100%\"><tr>";
    if ( $todo == 0 ) {
        $line .=
            '<td width="'
          . ( $width + 24 )
          . '" bgcolor="#00cc00" align="center" valign="center"> :-) </td>';
    }
    elsif ( $done == 0 ) {
        $line .=
            '<td width="'
          . ( $width + 24 )
          . '" bgcolor="#cc0000" align="center" valign="center"> %X% </td>';
    }
    else {
        $done = $done / 10;
        for my $i ( 1 .. 10 ) {
            if ( $i <= $done ) {
                $line .=
                    '<td width="'
                  . $cellWidth
                  . '" bgcolor="#00cc00" align="right">&nbsp;</td>';
            }
            else {
                $line .=
                    '<td width="'
                  . $cellWidth
                  . '" bgcolor="#cc0000">&nbsp;</td>';
            }
        }
    }
    $line .= '</tr></table>';
    return $line;
}

###########################
# createHtmlForm
#
# Make form to create new subtype

sub createHtmlForm {

    my ( $value, $template, $prompt ) = @_;
    my $list = "";

    # append form for new page creation
    $list .= "<p>\n";
    $list .= "<form name=\"new\">\n";
    $list .= "<input type=\"text\" name=\"topic\" size=\"30\" />\n";
    $list .=
        "<input type=\"hidden\" name=\"templatetopic\" value=\""
      . $template
      . "\" />\n";
    $list .= "<input type=\"hidden\" name=\"parent\" value=\"%TOPIC%\" />\n";
    $list .=
      "<input type=\"submit\" name =\"xpsave\" value=\"" . $prompt . "\" />\n";
    $list .= "</form>\n";
    $list .= "\n";

    return $list;
}

###########################
# emmitArrayInBullets
#
# Creates an html unordered list from
# a Perl list
sub emmitArrayInBullets {
    my @array = @_;
    return "<ul><li> " . join( "<li> ", @array ) . " </ul>",;
}

###########################
# emmitTwikiHeader
#
# Creates a header in the form ---+
# with the specified depth level

sub emmitTwikiHeader {
    my ( $level, $text ) = @_;
    my $plus = "";

    while ( $level > 0 ) {
        $plus .= "+";
        $level--;
    }
    return "\n\n---" . $plus . $text . "\n\n",;
}

1;
