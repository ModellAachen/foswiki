#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2001 John talintyre, jet@cheerful.com for Dresdner Kleinwort Wasserstein
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
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional.
# For increased performance, DISABLE (or comment) handlers you don't need.

# TODO:
#   1. Only read information once
#   2. Don't analyse text fields by default
#   3. Watch out for rendering of data in tables e.g. in hrefs
#   4. Pivot on two fields

# =========================
package TWiki::Plugins::FormPivotPlugin;

use strict;

# =========================
use vars qw( $web $topic $user $installWeb $VERSION $RELEASE
  $myConfigVar );

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
    ( $topic, $web, $user, $installWeb ) = @_;

    #TWiki::Func::writeDebug( "init FormPivot ..." );

    # Plugin correctly initialized
    return 1;
}

# =========================
sub DISABLEcommonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    #    print "DefaultPlugin::commonTagsHandler called<br>";

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

}

# =========================
sub DISABLEstartRenderingHandler {
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    #    print "DefaultPlugin::startRenderingHandler called<br>";

    # This handler is called by getRenderedVersion just before the line loop

}

sub pivot {
    my ($args) = @_;

    my $form    = TWiki::Func::extractNameValuePair( $args, "form" );
    my $fieldsp = TWiki::Func::extractNameValuePair( $args, "fields" );
    my $type    = TWiki::Func::extractNameValuePair( $args, "type" );

    my @fields = split( /,/, $fieldsp );

    if ( !@fields ) {
        my ( $formMeta, $formDef ) = TWiki::Func::readTopic( $web, $form );
        my @fieldDefs = TWiki::Form::getFormDefinition($formDef);
        foreach my $fieldDefP (@fieldDefs) {
            my $name = $fieldDefP->[1];
            if ( $fieldDefP->[2] !~ /^text/ ) {
                push @fields, $name;
            }
        }

    }

    # Find all topics with this form.

    my $searchVal = "%META:FORM\{.*name=\\\"$form\\\".*\}%";

    my $search =
      &TWiki::Search::searchWeb( "1", $web, $searchVal, "", "", "on", "", "",
        "", "on", "on", "on", "on", "", "", "", "on", "", "", '$topic$n' );

    my $pivot      = "";
    my @found      = ();
    my @foundTopic = ();

    for ( my $i ; $i <= $#fields ; $i++ ) {
        my %hash      = ();
        my %hashTopic = ();
        $found[$i]      = \%hash;
        $foundTopic[$i] = \%hashTopic;
    }

    foreach my $formTopic ( split( /\s/, $search ) ) {
        my ( $meta, $text ) = TWiki::Func::readTopic( $web, $formTopic );
        for ( my $i ; $i <= $#fields ; $i++ ) {
            my $name = $fields[$i];
            $name =~ s/\s*//go;
            my %field0 = $meta->findOne( "FIELD", $name );
            my @values = split( /,/, $field0{"value"} );
            foreach my $value (@values) {
                $value =~ s/^\s*//go;    # Trim left
                $value =~ s/\s*$//go;    # Trim right
                if ( !$found[$i]->{$value} ) {
                    $found[$i]->{$value} = 1;
                }
                else {
                    $found[$i]->{$value} += 1;
                }
                if ( !$foundTopic[$i]->{$value} ) {
                    my %topics = ();
                    $foundTopic[$i]->{$value} = \%topics;
                }
                $foundTopic[$i]->{$value}->{$formTopic} = 1;
            }
        }
    }

    if ( $type ne "grid" ) {
        for ( my $i ; $i <= $#fields ; $i++ ) {
            my $field = $fields[$i];
            $pivot .= "---++ $field\n";

            my $table  = "| *Field* | *Count* |\n";
            my $found1 = $found[$i];
            foreach my $key ( keys %$found1 ) {
                my $title = $key || "blank";

                # FIXME should use field name not title without spaces
                $field =~ s/\s*//go;

                # Problems passing = and " to URL
                my $searchVal =
                  "%META:FIELD\{.*name..$field..*value..$key.*\}%";
                $title =
                    "<a href=\""
                  . &TWiki::Func::getScriptUrl( $web, "", "search" )
                  . "?regex=on&search=$searchVal&nosearch=on\">$title</a>";
                $table .= "| $title | " . $found[$i]->{$key} . " |\n";
            }
            $pivot .= "$table";
        }
    }

    if ( $type eq "grid" ) {
        my $fieldCol = $fields[1];
        my $hashCol  = $foundTopic[1];
        my $fieldRow = $fields[0];
        my $hashRow  = $foundTopic[0];
        $pivot .= "| |";
        foreach my $valueCol ( keys %$hashCol ) {
            $pivot .= " *$valueCol* |";
        }
        $pivot .= "\n";
        foreach my $valueRow ( keys %$hashRow ) {
            $pivot .= "| *$valueRow*  |";
            foreach my $valueCol ( keys %$hashCol ) {
                my $count         = 0;
                my $hashRowTopics = $hashRow->{$valueRow};
                my $hashColTopics = $hashCol->{$valueCol};
                foreach my $rowTopic ( keys %$hashRowTopics ) {
                    $count++ if ( $hashColTopics->{$rowTopic} );
                }
                my $searchVal =
                  "%META:FIELD\{.*name%3D.$fieldRow..*value..$valueRow.*\}%%3B"
                  . "%META:FIELD\{.*name%3D.$fieldCol..*value..$valueCol.*\}%";

#my $searchVal = "FIELD,$fieldRow,value,$valueRow,FIELD,$fieldCol,value,$valueCol";
                my $link =
                    "<a href=\""
                  . &TWiki::Func::getScriptUrl( $web, "", "search" )
                  . "?regex=on&search=$searchVal&nosearch=on\">$count</a>";
                $pivot .= " $link |";
            }
            $pivot .= "\n";
        }
    }

    $pivot = &TWiki::Func::renderText( $pivot, $web );

    return $pivot;
}

# =========================
sub outsidePREHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    # This handler is called by getRenderedVersion, in loop outside of <PRE> tag
    # This is the place to define customized rendering rules

    $_[0] =~ s/%FORMPIVOT{([^}]+)}%/&pivot( $1 )/geo;

}

# =========================
sub DISABLEinsidePREHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    #    print "DefaultPlugin::insidePREHandler called<br>";

    # This handler is called by getRenderedVersion, in loop inside of <PRE> tag
    # This is the place to define customized rendering rules

}

# =========================
sub DISABLEendRenderingHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    #    print "DefaultPlugin::endRenderingHandler called<br>";

    # This handler is called by getRenderedVersion just after the line loop

}

# =========================

1;

