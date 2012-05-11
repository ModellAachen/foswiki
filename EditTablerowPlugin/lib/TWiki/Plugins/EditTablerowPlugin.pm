# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2004-2006 Thomas Weigert, weigert@comcast.net
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

# =========================
package TWiki::Plugins::EditTablerowPlugin;

use strict;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug $pluginName
  $renderingWeb
  $preSp %params @format @formatExpanded
  $prefsInitialized $prefCHANGEROWS $prefEDITBUTTON $prefEDITLINK
);

$VERSION          = '$Rev: 0$';
$RELEASE          = 'Dakar';
$pluginName       = 'EditTablerowPlugin';    # Name of this Plugin
$prefsInitialized = 0;

use TWiki::Form;

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning(
            "This version of $pluginName works only with TWiki 4 and greater.");
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    $prefsInitialized = 0;
    $renderingWeb     = $web;

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::EditTablerowPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

# =========================
sub extractParams {
    my ( $theArgs, $theHashRef ) = @_;

    my $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "header" );
    $$theHashRef{"header"} = $tmp if ($tmp);

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "include" );
    $$theHashRef{"include"} = $tmp if ($tmp);

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "footer" );
    $$theHashRef{"footer"} = $tmp if ($tmp);

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "headerislabel" );
    $$theHashRef{"headerislabel"} = $tmp if ($tmp);

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "format" );
    $tmp =~ s/^\s*\|*\s*//o;
    $tmp =~ s/\s*\|*\s*$//o;
    $$theHashRef{"format"} = $tmp if ($tmp);

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "template" );
    $$theHashRef{"template"} = $tmp if ($tmp);

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "changerows" );
    $$theHashRef{"changerows"} = $tmp if ($tmp);

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "show" );
    $$theHashRef{"showtable"} = $tmp if ($tmp);

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "helptopic" );
    $$theHashRef{"helptopic"} = $tmp if ($tmp);

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "editbutton" );
    $$theHashRef{"editbutton"} = $tmp if ($tmp);

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "editlink" );
    $$theHashRef{"editlink"} = $tmp if ($tmp);

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "headeronempty" );
    $$theHashRef{"showHeaderOnEmpty"} = $tmp if ($tmp);

    return;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug(
        "- EditTablerowPlugin::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    return unless $_[0] =~ /%EDITTABLEROW{(.*)}%/os;

    unless ($prefsInitialized) {
        $prefCHANGEROWS =
             &TWiki::Func::getPreferencesValue("CHANGEROWS")
          || &TWiki::Func::getPreferencesValue("EDITTABLEROWPLUGIN_CHANGEROWS")
          || "on";
        $prefEDITBUTTON =
             &TWiki::Func::getPreferencesValue("EDITBUTTON")
          || &TWiki::Func::getPreferencesValue("EDITTABLEROWPLUGIN_EDITBUTTON")
          || "Edit table";
        $prefEDITLINK = &TWiki::Func::getPreferencesValue("EDITLINK")
          || &TWiki::Func::getPreferencesValue("EDITTABLEROWPLUGIN_EDITLINK");
        $prefsInitialized = 1;
    }

    my $theWeb      = $_[2];
    my $theTopic    = $_[1];
    my $result      = "";
    my $tableNr     = 0;
    my $rowNr       = 0;
    my $enableForm  = 0;
    my $insideTable = 0;
    my $cgiRows     = -1;

    # appended stuff is a hack to handle EDITTABLEROW correctly if at end
    foreach ( split( /\r?\n/, "$_[0]\n<nop>\n" ) ) {
        if (
s/(\s*)%EDITTABLEROW{(.*)}%/&handleEditTableTag( $theWeb, $theTopic, $1, $2 )/geo
          )
        {
            $enableForm = 1;
            $tableNr += 1;
        }
        if ($enableForm) {
            if (/^(\s*)\|.*\|\s*$/) {

              # found table row
              # Here we could handle the first row if something needs to be done
                $insideTable = 1;
                $rowNr++;
s/^(\s*)\|(\s*)(.*?)(\s*)\|(.*)/&handleTableRow( $1, $2, $3, $4, $5, $tableNr, $rowNr )/eo;

            }
            elsif ($insideTable) {

                # end of table
                $insideTable = 0;
                $rowNr++;
                $result .= handleTableEnd( $theWeb, $tableNr, $rowNr );
                $enableForm = 0;
                $rowNr      = 0;
            }
            if (/^\s*$/) {    # empty line
                if ($enableForm) {

                    # empty %EDITTABLEROW%, so create a default table
                    if ( $params{"showHeaderOnEmpty"} ) {
                        $result .=
                          handleTableStart( $theWeb, $theTopic, $tableNr );
                    }
                    $result .= handleTableEnd( $theWeb, $tableNr, 0 );
                    $enableForm = 0;
                    $rowNr      = 0;
                }
                $rowNr = 0;
            }
        }
        $result .= "$_\n";
    }
    $result =~ s|\n?<nop>\n$||o
      ;    # clean up hack that handles EDITTABLE correctly if at end

    $_[0] = $result;
}

# =========================
sub handleEditTableTag {
    my ( $theWeb, $theTopic, $thePreSpace, $theArgs ) = @_;

    $preSp = $thePreSpace || "";
    %params = (
        "header"            => "",
        "footer"            => "",
        "headerislabel"     => "1",
        "format"            => "",
        "changerows"        => $prefCHANGEROWS,
        "helptopic"         => "",
        "editbutton"        => $prefEDITBUTTON,
        "editlink"          => $prefEDITLINK,
        "showHeaderOnEmpty" => "",
    );

    my $iTopic = TWiki::Func::extractNameValuePair( $theArgs, 'include' );
    if ($iTopic) {

        # include topic to read definitions
        if ( $iTopic =~ /^([^\.]+)\.(.*)$/o ) {
            $web   = $1;
            $topic = $2;
        }
        my $text = TWiki::Func::readTopicText( $web, $iTopic );
        $text =~ /%EDITTABLE{(.*)}%/os;
        if ($1) {
            my $args = $1;
            if ( $theWeb ne $web || $iTopic ne $theTopic ) {

                # expand common vars, unless oneself to prevent recursion
                $args = TWiki::Func::expandCommonVariables( $1, $iTopic, $web );
            }
            extractParams( $args, \%params );
        }
    }

    extractParams( $theArgs, \%params );

    $params{"header"} =~ s/^\s*\|//o;
    $params{"header"} =~ s/\|\s*$//o;
    $params{"format"} =~ s/^\s*\|//o;
    $params{"format"} =~ s/\|\s*$//o;
    $params{"headerislabel"} = ""
      if ( $params{"headerislabel"} =~ /^(off|no)$/oi );
    $params{"footer"} = "" if ( $params{"footer"} =~ /^(off|no)$/oi );
    $params{"footer"} =~ s/^\s*\|//o;
    $params{"footer"} =~ s/\|\s*$//o;
    $params{"changerows"} = "" if ( $params{"changerows"} =~ /^(off|no)$/oi );
    $params{"showtable"}  = "" if ( $params{"showtable"}  =~ /^(off|no)$/oi );
    $params{"showHeaderOnEmpty"} = ""
      if ( $params{"showHeaderOnEmpty"} =~ /^(off|no)$/oi );

    # FIXME: No handling yet of footer

    return "$preSp<nop>";
}

# =========================
sub handleTableStart {
    my ( $theWeb, $theTopic, $theTableNr ) = @_;

    my $theForm;
    my $template = $params{"template"};
    if ($template) {
        $theForm =
          new TWiki::Form( $TWiki::Plugins::SESSION, $theWeb, $template );
    }
    else {
        $theForm->{fields} =
          _parseIntoFormDef( $params{"header"}, $params{"format"}, $theWeb,
            $theTopic );
    }

    my $fieldDefs = $theForm->{fields};
    if ( !@{$fieldDefs} ) {
        return
"<font color=red>No Table template found: $theWeb . $params{'template'}</font>";
    }
    else {
        my $tableHeader .= renderForDisplay($fieldDefs);
        $tableHeader .= "\n";
        return $tableHeader;
    }

}

# =========================
sub renderForDisplay {

    my $tableHeader = "| ";

    # Get each field definition
    # | *Name:* | *Type:* | *Size:* | *Value:*  | *Tooltip message:* |
    foreach my $fieldInfo ( @{ $_[0] } ) {
        my $title = $fieldInfo->{title};
        $tableHeader .= "*$title* | ";
    }

    return $tableHeader;

}

# =========================
sub handleTableEnd {
    my ( $theWeb, $theTableNr, $theRowNr ) = @_;

    my $header = "";
    my $button = "";

    my $value = $params{"editbutton"};
    my $img   = "";
    if ( $value =~ s/(.+),\s*(.+)/$1/o ) {
        $img = $2;
        $img =~ s|%ATTACHURL%|%PUBURL%/$installWeb/EditTablerowPlugin|o;
        $img =~ s|%WEB%|$installWeb|o;
    }

    if ($img) {
        $button =
"<input class=\"editTableEditImageButton\" type=\"image\" src=\"$img\" alt=\"$value\" />";
    }
    else {
        $button = "<input type=\"submit\" value=\"$value\" />";
    }

    if ( $params{"changerows"} ) {
        $header .=
"<form action=\"%SCRIPTURLPATH%/editTableRow%SCRIPTSUFFIX%/%WEB%/$topic\">
<input type=\"hidden\" name=\"template\" value=\"$params{'template'}\">
<input type=\"hidden\" name=\"header\" value=\"$params{'header'}\">
<input type=\"hidden\" name=\"format\" value=\"$params{'format'}\">
<input type=\"hidden\" name=\"helptopic\" value=\"$params{'helptopic'}\">
<input type=\"hidden\" name=\"sec\" value=\"0\">
<input type=\"hidden\" name=\"tablename\" value=\"$theTableNr\">\n"
          . (
            ( $params{'showtable'} && $theRowNr )
            ? "<input type=\"hidden\" name=\"showtable\" value=\"on\">\n"
            : "<input type=\"hidden\" name=\"showtable\" value=\"off\">\n"
          ) . "$button</form>";
    }

    return "$header<br>\n";

}

# =========================
sub handleTableRow {
    my ( $thePre, $r1, $title, $r2, $tail, $theTableNr, $theRowNr ) = @_;

    $thePre = "" unless ( defined($thePre) );
    my $text = "$thePre\|$r1";

    # Find out whether this is title row
    my $boldTitle = 0;
    if ( $params{"headerislabel"} && $title =~ m/^\s*\*(.*)\*\s*$/ ) {

        # title is headercell; all cells must be header cells
        my $isTitle = 1;
        $boldTitle = $1;
        my @fields = split( /\|/, $tail );
        foreach my $fld (@fields) {
            if ( $fld !~ m/\s*\*.*\*\s*/o ) { $isTitle = 0; last; }
        }
        return "$text$title$r2\|$tail" if $isTitle;
    }

    $title = $boldTitle if $boldTitle;
    $title = "---" unless $title;
    $text .= "*" if $boldTitle;

    # Add edit links, maybe this should just be a link of the first table item
    my $eurl = &TWiki::Func::getScriptUrl( $web, $topic, "editTableRow" );
    my $button = '';
    if ( $params{'editlink'} ) {
        my $value = $params{'editlink'};
        my $img   = "";
        if ( $value =~ s/(.+),\s*(.+)/$1/o ) {
            $img = $2;
            $img =~ s|%ATTACHURL%|%PUBURL%/$installWeb/EditTablerowPlugin|o;
            $img =~ s|%WEB%|$installWeb|o;
        }
        if ($img) {
            $button = "<img src=\"$img\" alt=\"$value\" border=\"0\" />";
        }
        else {
            $button = "$value";
        }
    }
    $text .=
      "<a name=\"Tbl${theTableNr}Row${theRowNr}\" href=\"$eurl\?t=" . time();
    my $template = $params{"template"};
    if ($template) {
        $text .= "&template=$params{'template'}";
    }
    else {
        $text .=
            "&header="
          . TWiki::urlEncode( $params{'header'} )
          . "&format="
          . TWiki::urlEncode( $params{'format'} );
    }
    $text .=
"&helptopic=$params{'helptopic'}&tablename=$theTableNr&sec=$theRowNr&changerows=$params{'changerows'}&showtable=$params{'showtable'}#SECEDITBOX\">$button";
    if ($button) {
        $text .= "</a> $title";
    }
    else {
        $text .= " $title</a>";
    }

    $text .= "*" if $boldTitle;

    $text .= "$r2\|$tail";

    return $text;
}

# =========================
sub carriageReturnConvert {
    my ($string) = @_;

    if ( $string =~ /\<br\>/ ) {
        $string =~ s/\<br\>/\n/g;
    }
    else {
        $string =~ s/\n/\<br\>/g;
        $string =~ s/\r//g;
    }

    return ($string);
}

# =========================
sub stringConvert {
    my ($string) = @_;

    $string =~ s/\ /+/g;    #Uses '+' character to denote spaces

    return ($string);
}

# =========================
sub updateTableRow {

    my ( $query, $line, $deleteElement, $copyElement, $fieldsInfo ) = @_;

    my @fieldElements = ();

    # found row
    my $result = "";
    if ($deleteElement) {
        return "";
    }
    if ($copyElement) {

        # Copy the entry
        $result .= $line;
    }

    # Update the entry
    $result .= "\|";

    foreach my $fieldInfo ( @{$fieldsInfo} ) {
        my $entryName  = $fieldInfo->{name};
        my $title      = $fieldInfo->{title};
        my $type       = $fieldInfo->{type};
        my $size       = $fieldInfo->{size};
        my $tableEntry = $query->param($entryName);
        my $cvalue     = "";

        # Takes care of special checkbox entry (Form.pm -- line : 376)
        if ( $type =~ "^checkbox" ) {
            my @values = $query->param($entryName);
            $tableEntry = shift @values;
            foreach my $val (@values) {
                $tableEntry .= ", $val";
            }
        }
        $tableEntry = " " unless $tableEntry;
        $result .= carriageReturnConvert($tableEntry) . "\|";

    }
    return "$result\n";
}

# =========================
sub appendToTable {

    my ( $query, $line, $rowNr, $deleteElement, $copyElement, $fieldsInfo ) =
      @_;

    my @fieldElements = ();

    # found row
    my $result = "";
    if ($deleteElement) {
        return "";
    }
    if ($copyElement) {

        # Copy the entry
        $result .= $line;
    }

    # Update the entry
    $result .= "\|";
    foreach my $fieldInfo ( @{$fieldsInfo} ) {
        my $entryName  = $fieldInfo->{name};
        my $title      = $fieldInfo->{title};
        my $type       = $fieldInfo->{type};
        my $size       = $fieldInfo->{size};
        my $tableEntry = $query->param($entryName);
        my $cvalue     = "";

        # Takes care of special checkbox entry (Form.pm -- line : 376)
        if ( $type =~ "^checkbox" ) {
            my @values = $query->param($entryName);
            $tableEntry = shift @values;
            foreach my $val (@values) {
                $tableEntry .= ", $val";
            }
        }
        $tableEntry = " " unless $tableEntry;
        $result .= carriageReturnConvert($tableEntry) . "\|";

    }
    return "$result\n$line";

}

sub doEnableEdit {
    my ( $theWeb, $theTopic, $user, $query ) = @_;

    if (
        !&TWiki::Func::checkAccessPermission(
            "change", $user->webDotWikiName, "", $theTopic, $theWeb
        )
      )
    {

        # user does not have permission to change the topic
        throw TWiki::OopsException(
            'accessdenied',
            def   => 'topic_access',
            web   => $theWeb,
            topic => $theTopic,
            params =>
              [ 'Edit topic', 'You are not permitted to edit this topic' ]
        );
        return 0;
    }

    my ( $oopsUrl, $lockUser ) =
      &TWiki::Func::checkTopicEditLock( $theWeb, $theTopic, 'edit' );
    my $breakLock = $query->param('breaklock') || '';
    unless ($breakLock) {
        my ( $oopsUrl, $lockUser ) =
          &TWiki::Func::checkTopicEditLock( $theWeb, $theTopic, 'edit' );
        if ( $lockUser && !( $lockUser eq $user->login ) ) {

            # warn user that other person is editing this topic
            &TWiki::Func::redirectCgiQuery( $query, $oopsUrl );
            return 0;
        }
        TWiki::Func::setTopicEditLock( $theWeb, $theTopic, 1 );
    }

    return 1;
}

sub editTablerow {

    my $session = shift;
    $TWiki::Plugins::SESSION = $session;

    $session->enterContext('edit');
    my $query   = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic   = $session->{topicName};
    my $user    = $session->{user};
    return unless ( &doEnableEdit( $webName, $topic, $user, $query ) );

    return unless ($query);
    $query->{'jscalendar'} = 0;    # Is this needed?
    my ( $meta, $text ) = &TWiki::Func::readTopic( $webName, $topic );

    my $template   = $query->param('template')   || "";
    my $header     = $query->param('header')     || "";
    my $format     = $query->param('format')     || "";
    my $tableNr    = $query->param('tablename')  || "";
    my $rowNr      = $query->param('sec')        || "0";
    my $changerows = $query->param('changerows') || "";
    my $showtable  = $query->param('showtable')  || "";
    my $helptopic  = $query->param('helptopic')  || "";

    my $skin = TWiki::Func::getSkin();

    my $tmpl = &TWiki::Func::readTemplate( "editTableRow", $skin );

    # This loads the table that you want
    $tmpl =~ s/%TEMPLATE%/$template/go;
    $tmpl =~ s/%HEADER%/$header/go;       # urlEncode?
    $tmpl =~ s/%FORMAT%/$format/go;       # urlEncode?
    $tmpl =~ s/%TABLENAME%/$tableNr/go;

    # This renders the editable fields
    my $theForm;
    my $fieldDefs;
    if ($template) {
        $theForm = new TWiki::Form( $session, $webName, $template );
        $fieldDefs = $theForm->{fields};
    }
    else {
        $fieldDefs = _parseIntoFormDef( $header, $format, $webName, $topic );
        $theForm = new TWiki::Form( $session, $webName, undef, $fieldDefs );
    }

    # Get rid of CRs (we only want to deal with LFs)
    $text =~ s/\r//g;

    # Need to determine table row
    if ( $text =~ m/%EDITTABLEROW/i ) {
        my @sections = split( /\s*%EDITTABLEROW{.*}%/i, $text );
        my $table    = $sections[$tableNr];
        my @rows     = split( /\n/, $table );
        my $rowidx   = -1;
        my $row      = "";
        foreach $row (@rows) {

            # skip non-table lines
            if ( $row =~ m/^\s*\|/ ) { last; }
            $rowidx++;
        }

        if ( $showtable eq "on" ) {
            my $oldTable      = "";
            my $foundOldTable = 0;
            foreach my $oldrow (@rows) {

                # skip non-table lines
                if ( $oldrow =~ m/^\s*\|/ ) {
                    $oldTable .= $oldrow . "\n";
                    $foundOldTable = 1;
                }
                else {
                    last if $foundOldTable;
                    $oldTable .= $oldrow . "\n";
                }
            }
            $tmpl =~
              s/%SHOWTABLE%/\n---++ Current Table Entries\n%BR%$oldTable\n/go;
        }
        else {
            $tmpl =~ s/%SHOWTABLE%//go;
        }

        $row = $rows[ $rowNr + $rowidx ];
        my @fields = split( /\|/, $row );

        # If we are editing an existing Form add meta fields
        my $idx = 0;
        if ( $rowNr != 0 ) {
            foreach my $fieldInfo ( @{$fieldDefs} ) {
                $idx++;
                my $entryName = $fieldInfo->{name};
                my $value     = $fields[$idx];
                my $tmpArgs   = {
                    "name"  => $entryName,
                    "value" => carriageReturnConvert($value)
                };
                $meta->putKeyed( "FIELD", $tmpArgs );
            }
            $tmpl =~ s/%ENTRY%/$rowNr/go;
        }
        else {
            my $id = time;
            foreach my $fieldInfo ( @{$fieldDefs} ) {
                my $entryName = $fieldInfo->{name};
                my $tmp       = $fieldInfo->{value};
                $tmp =~ s/\$nop(\(\))?//gos;         # remove filler
                $tmp =~ s/\$quot(\(\))?/\"/gos;      # expand double quote
                $tmp =~ s/\$percnt(\(\))?/\%/gos;    # expand percent
                $tmp =~ s/\$dollar(\(\))?/\$/gos;    # expand dollar
                my $tmpArgs = {
                    "name"  => $entryName,
                    "value" => carriageReturnConvert($tmp)
                };
                $meta->putKeyed( "FIELD", $tmpArgs );
            }
            $tmpl =~ s/%ENTRY%/$id/go;
        }
    }

    my $helpText = "";
    if ($helptopic) {

        # read help topic and show below the table
        my $theWeb = $webName;
        if ( $helptopic =~ /^([^\.]+)\.(.*)$/o ) {
            $theWeb    = $1;
            $helptopic = $2;
        }
        $helpText = &TWiki::Func::readTopicText( $theWeb, $helptopic );

        #Strip out the meta data so it won't be displayed.
        $helpText =~ s/%META:[A-Za-z0-9]+{.*?}%//g;
        if ($helpText) {
            $helpText =~ s/.*?%STARTINCLUDE%//os;
            $helpText =~ s/%STOPINCLUDE%.*//os;
        }
    }
    $tmpl =~ s/%HELPTEXT%/$helpText/go;

    # Add action buttons
    my $actions = "";
    $actions .=
"<input type=\"submit\" class=\"twikiSubmit twikiSecondary\" name=\"addElement\" id=\"addElement\" value=\""
      . ( ($rowNr) ? "Update" : "Add" )
      . "\" /><label accesskey=\"s\" for=\"addElement\"></label>&nbsp;";
    $actions .=
"<input type=\"submit\" class=\"twikiSubmit twikiSecondary\" name=\"deleteElement\" id=\"deleteElement\" value=\"Delete\" /><label accesskey=\"d\" for=\"deleteElement\"></label>&nbsp;"
      if ( $rowNr && $changerows && ( $changerows ne "add" ) );
    $actions .=
"<input type=\"submit\" class=\"twikiSubmit\" name=\"copyElement\" id=\"copyElement\" value=\"Copy\" /><label accesskey=\"a\" for=\"copyElement\"></label>"
      if ( $rowNr && $changerows );
    $tmpl =~ s/%ACTIONBUTTONS%/$actions/go;

    if ($rowNr) {
        $tmpl =~ s/%HEADERTEXT%/Update Table Row/go;
    }
    else {
        $tmpl =~ s/%HEADERTEXT%/Add Table Row/go;
    }

    # Note that in above we just write into the metadata for the form
    # to pass the table variables; this overwrites any form data with the
    # same name, but that does not matter as we just use it to render
    # the table row as a form.
    my $formText = $theForm->renderForEdit( $webName, $topic, $meta );
    $tmpl = &TWiki::Func::expandCommonVariables( $tmpl, $topic, $webName );

    # Not needed?
    #    $tmpl = &TWiki::handleMetaTags( $webName, $topic, $tmpl, $meta );
    $tmpl = &TWiki::Func::renderText($tmpl);
    $tmpl =~ s/%TABLEFIELDS%/$formText/go
      ;    #Moved after getRenderedVersion so that TWiki Syntax does not expand

    #    TWiki::Func::writeHeader( $query );
    #    print $tmpl;
    # Need to reach outside of Func, as otherwise the addHEAD has no effect
    $TWiki::Plugins::SESSION->writeCompletePage($tmpl);
}

sub uploadTablerow {

    my $session = shift;
    $TWiki::Plugins::SESSION = $session;

    $session->enterContext('edit');
    my $query   = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic   = $session->{topicName};
    my $user    = $session->{user};
    return unless ( &doEnableEdit( $webName, $topic, $user, $query ) );

    return unless ($query);

    my $template = $query->param( 'template' || "" );
    my $header = $query->param('header') || "";
    my $format = $query->param('format') || "";
    my $tableNr = $query->param( 'tablename' || "" );
    my $rowNr   = $query->param( 'name'      || "" );
    my $deleteElement = $query->param('deleteElement');
    my $copyElement   = $query->param('copyElement');
    my $filePath      = $query->param('filepath') || "";
    my $fileName      = $query->param('filename') || "";
    if ( $filePath && !$fileName ) {
        $filePath =~ m|([^/\\]*$)|;
        $fileName = $1;
    }

    # setup the view url (do now as we need the tableNr, rowNr)
    my $url = &TWiki::Func::getViewUrl( $webName, $topic );
    $url .= "#Tbl${tableNr}Row${rowNr}";

    # Need to cycle through the fieldDefs and query the parameters to fill the
    # the associative array
    my $theForm;
    my $fieldDefs;
    if ($template) {
        $theForm = new TWiki::Form( $session, $webName, $template );
        $fieldDefs = $theForm->{fields};
    }
    else {
        $fieldDefs = _parseIntoFormDef( $header, $format, $webName, $topic );
        $theForm = new TWiki::Form( $session, $webName, undef, $fieldDefs );
    }

    my ( $fileSize, $fileUser, $fileDate, $fileVersion ) = "";

    # update topic
    my $text = &TWiki::Func::readTopicText( $webName, $topic, "", 1 );

    # Get rid of CRs (we only want to deal with LFs)
    #$text =~ s/\r//g;

    my $result      = "";
    my $done        = 0;
    my $insideTable = 0;
    my $enableForm  = 0;

#### Note: Probably need to preserve leader before table (see in EditTablerowPlugin.pm)

    # Need to determine table row
    foreach ( split( /\r?\n/, "$text\n<nop>\n" ) ) {
        my $line = "$_\n";

        if ($done) { $result .= $line; next; }
        if ( $line =~ m/\s*%EDITTABLEROW{.*}%/i ) {
            $tableNr--;
            $enableForm = 1 unless $tableNr;
        }
        if ($enableForm) {
            if ( $line =~ m/^\s*\|.*\|\s*$/ ) {
                $insideTable = 1;
                $rowNr--;
                if ( !$rowNr ) {
                    $line =
                      &updateTableRow( $query, $line, $deleteElement,
                        $copyElement, $fieldDefs );
                    $done       = 1;
                    $enableForm = 0;
                }
            }
            elsif ($insideTable) {
                $insideTable = 0;
                $line = appendToTable( $query, $line, $rowNr, $deleteElement,
                    $copyElement, $fieldDefs );
                $enableForm = 0;
            }
            if ( $line =~ m/^\s*$/ ) {
                if ($enableForm) {

                    # There was no header line, create it
                    if ($template) {
                        $line = '|';
                        foreach my $fieldInfo ( @{$fieldDefs} ) {
                            $line .= '*' . $fieldInfo->{title} . '*|';
                        }
                        $line .= "\n";
                    }
                    else {
                        $line = "|$header|\n";
                    }
                    $line .= appendToTable( $query, '', $rowNr, $deleteElement,
                        $copyElement, $fieldDefs );
                    $enableForm = 0;
                }
            }
        }
        $result .= "$line";
    }
    $result =~ s|\n?<nop>\n$||o
      ;    # clean up hack that handles EDITTABLE correctly if at end

    my $error = &TWiki::Func::saveTopicText( $webName, $topic, $result, 1 );
    TWiki::Func::setTopicEditLock( $webName, $topic, 0 );    # unlock Topic
    if ($error) {

        #TWiki::UI::oops( $webName, $topic, "saveerr", $error );
        TWiki::Func::redirectCgiQuery( $query, $error );
        return 0;
    }
    else {

        # and finally display topic, and move to edited line
        TWiki::Func::redirectCgiQuery( $query, $url );
    }
}

sub renderFormFieldForEditHandler {
    use TWiki::Contrib::JSCalendarContrib;
    TWiki::Contrib::JSCalendarContrib::renderFormFieldForEditHandler(@_);
}

sub _parseIntoFormDef {
    my ( $header, $format, $web, $topic ) = @_;

    my @headers = split( /\|/, $header );
    my @formats = split( /\|/, $format );

    # Should there be some error checking that they are the same size?

    my @fields = ();

    for ( my $idx = 0 ; $idx <= $#headers ; $idx++ ) {

        my $title = $headers[$idx] || '';
        $title =~ s/^\s*\*//go;
        $title =~ s/\*\s*$//go;

        my $tmp = $formats[$idx];
        $tmp =~ s/^([^,]*),?//;
        my $type = $1;
        $tmp =~ s/^([^,]*),?//;
        my $size = $1;
        my $vals = $tmp;

        $type ||= '';
        $type = lc $type;
        $type =~ s/^\s*//go;
        $type =~ s/\s*$//go;
        $type = 'text' if ( !$type );

        $size ||= '';
        $size = TWiki::Form::_cleanField($size);
        unless ($size) {
            if ( $type eq 'text' ) {
                $size = 20;
            }
            elsif ( $type eq 'textarea' ) {
                $size = '40x5';
            }
            else {
                $size = 1;
            }
        }

        $vals ||= '';
        $vals =
          $TWiki::Plugins::SESSION->handleCommonTags( $vals, $web, $topic );

        $vals =~ s/^\s*//go;
        $vals =~ s/\s*$//go;

        # SMELL: see comment in Form.pm
        if ( $vals eq '$users' ) {
            $vals =
              $TWiki::cfg{UsersWebName} . '.'
              . join(
                ", ${TWiki::cfg{UsersWebName}}.",
                (
                    $TWiki::Plugins::SESSION->{store}
                      ->getTopicNames( $TWiki::cfg{UsersWebName} )
                )
              );
        }

        my $definingTopic = "";
        if ( $title =~ /\[\[(.+)\]\[(.+)\]\]/ ) {
            $definingTopic = TWiki::Form::_cleanField($1);
            $title         = $2;
        }

        my $name = TWiki::Form::_cleanField($title);

        # Rename fields with reserved names
        if ( $TWiki::Form::reservedFieldNames->{$name} ) {
            $name  .= '_';
            $title .= '_';
        }

        push(
            @fields,
            {
                name          => $name,
                title         => $title,
                type          => $type,
                size          => $size,
                value         => $vals,
                tooltip       => '',
                attributes    => '',
                definingTopic => $definingTopic
            }
        );

    }

    return \@fields;

# Note that this does not expand searches in fields, etc., as in TWiki::Form::new

}

1;
