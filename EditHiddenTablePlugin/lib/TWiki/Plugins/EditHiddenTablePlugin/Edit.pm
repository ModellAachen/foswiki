# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2001-2003 John Talintyre, jet@cheerful.com
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2005 TWiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.

use strict;

package TWiki::Plugins::EditHiddenTablePlugin::Edit;

use vars qw( $template $tableName $topic $showtable
  $header $footer $headerislabel $changerows $helptopic
  $editbutton $editlink $headeronempty
);

sub handleEditTableTag {
    my ( $session, $attributes, $topic, $web ) = @_;

    # SMELL: Do these preferences really need to be globals?

    $footer        = '';
    $headerislabel = 1;
    $changerows    = $TWiki::Plugins::EditHiddenTablePlugin::prefCHANGEROWS;
    $editbutton    = $TWiki::Plugins::EditHiddenTablePlugin::prefEDITBUTTON;
    $editlink      = $TWiki::Plugins::EditHiddenTablePlugin::prefEDITLINK;
    $headeronempty = '';
    $helptopic     = '';

    my $tmp;

    $tmp = $attributes->{footer};
    $footer = $tmp if ($tmp);

    $tmp = $attributes->{headerislabel};
    $headerislabel = $tmp if ($tmp);

    $tmp = $attributes->{template};
    $template = $tmp if ($tmp);

    $tmp = $attributes->{changerows};
    $changerows = $tmp if ($tmp);

    $showtable = 'on';
    $tmp       = $attributes->{show};
    $showtable = $tmp if ($tmp);

    $tmp = $attributes->{helptopic};
    $helptopic = $tmp if ($tmp);

    $tmp = $attributes->{editbutton};
    $editbutton = $tmp if ($tmp);

    $tmp = $attributes->{editlink};
    $editlink = $tmp if ($tmp);

    $tmp = $attributes->{headeronempty};
    $headeronempty = $tmp if ($tmp);

    $tmp = $attributes->{tablename};
    $tableName = $tmp if ($tmp);

    $tmp = $attributes->{topic};
    $topic = $tmp if ($tmp);

    $headerislabel = '' if ( $headerislabel =~ /^(off|no)$/oi );
    $footer        = '' if ( $footer        =~ /^(off|no)$/oi );
    $footer =~ s/^\s*\|//o;
    $footer =~ s/\|\s*$//o;
    $changerows    = '' if ( $changerows    =~ /^(off|no)$/oi );
    $showtable     = '' if ( $showtable     =~ /^(off|no)$/oi );
    $headeronempty = '' if ( $headeronempty =~ /^(off|no)$/oi );

    # FIXME: No handling yet of footer

    if ( ( $template ne '' ) && ( $tableName ne '' ) ) {
        return tableTemplateHeader( $template, $tableName, $topic, $changerows,
            $showtable );
    }
}

sub tableTemplateHeader {

    my ( $template, $tableName, $topic, $changerows, $showtable ) = @_;
    my $theTable = '';
    my $session  = $TWiki::Plugins::SESSION;

    # Need to read the template and generate a header
    my $webName = &TWiki::Func::expandCommonVariables("%WEB%");

    use TWiki::Form;
    my $theForm = new TWiki::Form( $session, $webName, $template );
    my $fieldDefs = $theForm->{fields};

    if ( !@{$fieldDefs} ) {

        # Note: size of this is $#{$fieldDefs}
        return
"<font color=red>No Table template found: $webName . $template</font>";
    }
    else {
        my $tableEntries = '';

        # Need to reed the META entries and look for TABLE entries
        my ( $meta, $text ) = &TWiki::Func::readTopic( $webName, $topic );
        foreach my $table ( $meta->find("TABLE") ) {
            if ( $table->{tablename} eq $tableName ) {
                $tableEntries .= "\n";
                $tableEntries .= renderEntryForDisplay(
                    $table,     $topic,     $template,
                    $tableName, $showtable, $fieldDefs
                );
            }
        }
        $theTable .= renderForDisplay($fieldDefs)
          if ( $tableEntries || $headeronempty );
        $theTable .= $tableEntries if $tableEntries;
        $theTable .= "\n";
    }

    ## SMELL: Same as TWiki::Plugins::EditTablerowPlugin::handleTableEnd
    ## except that that has links relative to EditTablerowPlugin for img
    ## and that we use variables directly rather than $params{...}
    ## and tablename is used instead of tableNr

    my $header = '';
    my $button = '';

    my $value = $editbutton;
    my $img   = '';
    if ( $value =~ s/(.+),\s*(.+)/$1/o ) {
        $img = $2;
        $img =~
s|%ATTACHURL%|%PUBURL%/$TWiki::Plugins::EditHiddenTablePlugin::installWeb/EditHiddenTablePlugin|o;
        $img =~ s|%WEB%|$TWiki::Plugins::EditHiddenTablePlugin::installWeb|o;
    }

    if ($img) {
        $button =
"<input class=\"editTableEditImageButton\" type=\"image\" src=\"$img\" alt=\"$value\" />";
    }
    else {
        $button = "<input type=\"submit\" value=\"$value\" />";
    }

    if ($changerows) {
        $header .=
"<form action=\"%SCRIPTURLPATH%/editTable%SCRIPTSUFFIX%/%WEB%/$topic\">
<input type=\"hidden\" name=\"template\" value=\"$template\">
<input type=\"hidden\" name=\"helptopic\" value=\"$helptopic\">
<input type=\"hidden\" name=\"tablename\" value=\"$tableName\">\n"
          . (
            ( $showtable eq "on" )
            ? "<input type=\"hidden\" name=\"showtable\" value=\"on\">\n"
            : "<input type=\"hidden\" name=\"showtable\" value=\"off\">\n"
          ) . "$button</form>";
    }

    $theTable .= $header;

    return &TWiki::Func::expandCommonVariables($theTable);

}

## SMELL: Same as TWiki::Plugins::EditTablerowPlugin::renderForDisplay
sub renderForDisplay {

    my $tableHeader = '| ';

    # Get each field definition
    # | *Name:* | *Type:* | *Size:* | *Value:*  | *Tooltip message:* |
    foreach my $fieldInfo ( @{ $_[0] } ) {
        my $title = $fieldInfo->{title};
        $tableHeader .= "*$title* | ";
    }

    return $tableHeader;

}

sub renderEntryForDisplay {

    my ( $table, $topic, $template, $tableName, $showtable, $fieldDefs ) = @_;
    my $text  = '| ';
    my $count = 0;

    # Get each field definition
    # | *Name:* | *Type:* | *Size:* | *Value:*  | *Tooltip message:* |
    foreach my $fieldInfo ( @{$fieldDefs} ) {
        my $entryName = $fieldInfo->{name};
        my $title     = $table->{$entryName};
        if ( $count == 0 ) {
            my $name = stringConvert( $table->{name} );

      # Add edit links, maybe this should just be a link of the first table item
            my $eurl =
              &TWiki::Func::getScriptUrl(
                $TWiki::Plugins::EditHiddenTablePlugin::web,
                $topic, 'editTable' );
            my $button = '';
            if ($editlink) {
                my $value = $editlink;
                my $img   = "";
                if ( $value =~ s/(.+),\s*(.+)/$1/o ) {
                    $img = $2;
                    $img =~
s|%ATTACHURL%|%PUBURL%/$TWiki::Plugins::EditHiddenTablePlugin::installWeb/EditHiddenTablePlugin|o;
                    $img =~
s|%WEB%|$TWiki::Plugins::EditHiddenTablePlugin::installWeb|o;
                }
                if ($img) {
                    $button =
                      "<img src=\"$img\" alt=\"$value\" border=\"0\" />";
                }
                else {
                    $button = "$value";
                }
            }
            $text .= "<a name=\"Tbl${tableName}Row${count}\" href=\"$eurl\?t="
              . time();

            # my $template = $template;
            if ($template) {
                $text .= "&template=$template";
            }
            else {
## Not supported
##	"&header=" . TWiki::urlEncode($params{'header'})
##	"&format=" . TWiki::urlEncode($params{'format'});
            }
            $text .=
"&helptopic=$helptopic&tablename=$tableName&entry=$name&changerows=$changerows&showtable=$showtable#SECEDITBOX\">$button";
            if ($button) {
                $text .= "</a> $title |";
            }
            else {
                $text .= " $title</a> |";
            }
        }
        else {
            $text .= " $title |";
        }
        $count = $count + 1;
    }

    return $text

}

# =========================
# Add/update Table entries for a topic
# $text is full set of attachments, new attachments will be added to the end.
sub updateTable {

    my ( $meta, $template, $tableName, $fieldElements ) = @_;
    $fieldElements->{tablename} = $tableName;
    $fieldElements->{template}  = $template;
    $meta->putKeyed( 'TABLE', $fieldElements );

}

## SMELL: Same as TWiki::Plugins::EditTablerowPlugin::carriageReturnConvert
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

## SMELL: Same as TWiki::Plugins::EditTablerowPlugin::stringConvert
sub stringConvert {
    my ($string) = @_;

    $string =~ s/\ /+/g;    #Uses '+' character to denote spaces

    return ($string);
}

## SMELL: Same as TWiki::Plugins::EditTablerowPlugin::doEnableEdit
sub doEnableEdit {
    my ( $theWeb, $theTopic, $user, $query, $script ) = @_;

    if (
        !&TWiki::Func::checkAccessPermission(
            'change', $user->webDotWikiName, "", $theTopic, $theWeb
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
          &TWiki::Func::checkTopicEditLock( $theWeb, $theTopic, $script );
        if ( $lockUser && !( $lockUser eq $user->login ) ) {

            # warn user that other person is editing this topic
            &TWiki::Func::redirectCgiQuery( $query, $oopsUrl );
            return 0;
        }
        TWiki::Func::setTopicEditLock( $theWeb, $theTopic, 1 );
    }

    return 1;
}

sub editTable {

    my $session = shift;
    $TWiki::Plugins::SESSION = $session;

    $session->enterContext('edit');
    my $query   = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic   = $session->{topicName};
    my $user    = $session->{user};

    my $tmpl      = '';
    my $atext     = '';
    my $template  = $query->param('template') || '';
    my $tableName = $query->param('tablename') || '';
    my $entry     = $query->param('entry') || '';
    my $showtable = $query->param('showtable') || 'on';
    my $helptopic = $query->param('helptopic') || '';
    my $skin      = TWiki::Func::getSkin();

    my $fileUser = '';

    ### TW: Could ommit
    TWiki::UI::checkWebExists( $session, $webName, $topic, 'edit' );
    TWiki::UI::checkMirror( $session, $webName, $topic );

    return
      unless ( &doEnableEdit( $webName, $topic, $user, $query, 'editTable' ) );

    my ( $meta, $text ) = &TWiki::Func::readTopic( $webName, $topic );

    ### TW: Omitted logging the edit, should be further down

    ## SMELL: almost the same as templates/editTableRow.pattern.tmpl
    $tmpl = &TWiki::Func::readTemplate( 'editnewTable', $skin );

    # This loads the table that you want
    $tmpl =~ s/%TEMPLATE%/$template/go;
    $tmpl =~ s/%TABLENAME%/$tableName/go;
    $tmpl =~ s/%EDITTOPIC%//go;
    $tmpl =~ s/<a [^>]*?>Attach<\/a>//goi;
    if ( $showtable eq 'on' ) {
        $tmpl =~
s/%SHOWTABLE%/\n---++ Current Table Entries for <nop>$tableName in topic <nop>%TOPIC%\n%BR%\n%EDITHIDDENTABLE{template=\"$template\" tablename=\"$tableName\" topic=\"%TOPIC%\" changerows=\"off\"}%
/go;
    }
    else {
        $tmpl =~ s/%SHOWTABLE%//go;
    }

    # This renders the editable fields
    use TWiki::Form;
    my $theForm = new TWiki::Form( $session, $webName, $template );
    my $fieldDefs = $theForm->{fields};

    # If we are editing an existing Form add meta fields
    if ( $entry ne '' ) {
        my $table = $meta->get( 'TABLE', stringConvert($entry) );
        if ( $table->{name} eq '' )
        { #This was added to support the original style (Should eventually take out)
            $table = $meta->get( 'TABLE', $entry );
        }
        foreach my $fieldInfo ( @{$fieldDefs} ) {
            my $entryName = $fieldInfo->{name};
            my $value     = $table->{$entryName};
            my $tmpArgs   = {
                'name'  => $entryName,
                'value' => carriageReturnConvert($value)
            };
            $meta->putKeyed( 'FIELD', $tmpArgs );
        }

        #$entry = stringConvert($entry);
        $tmpl =~ s/%ENTRY%/$entry/go;
    }
    else {
        my $id = time;
        foreach my $fieldInfo ( @{$fieldDefs} ) {
            my $entryName = $fieldInfo->{name};
            my $tmpArgs   = {
                'name'  => $entryName,
                'value' => carriageReturnConvert( $fieldInfo->{value} )
            };
            $meta->putKeyed( 'FIELD', $tmpArgs );
        }
        $tmpl =~ s/%ENTRY%/$id/go;
    }

    my $helpText = '';
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

    ## TW: Can we differentiate adding/updating row? Differentiate labels and delete key...
    # Add action buttons
##TW: Why is cancel not in the buttons inside the table?
##%TMPL:DEF{"topicaction"}%<table class="twikiTopicAction">
##<tr class="twikiTopicAction">
##<td class="twikiCancelCol"><a id="cancel" href="%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%?unlock=on" accesskey="c">Cancel</a></td>
    #...
    my $actions = "";
    $actions .=
"<input type=\"submit\" class=\"twikiSubmit twikiSecondary\" name=\"addElement\" id=\"addElement\" value=\""
      . "Update/Add"
      . "\" /><label accesskey=\"s\" for=\"addElement\"></label>&nbsp;";
    $actions .=
"<input type=\"submit\" class=\"twikiSubmit twikiSecondary\" name=\"deleteElement\" id=\"deleteElement\" value=\"Delete\" /><label accesskey=\"d\" for=\"deleteElement\"></label>&nbsp;";
    $actions .=
"<input type=\"submit\" class=\"twikiSubmit\" name=\"copyElement\" id=\"copyElement\" value=\"Copy\" /><label accesskey=\"a\" for=\"copyElement\"></label>";
    $tmpl =~ s/%ACTIONBUTTONS%/$actions/go;

    ## TW: Can we differentiate adding/updating row?
    $tmpl =~ s/%HEADERTEXT%/Update Table Row/go;

    my $formText = $theForm->renderForEdit( $webName, $topic, $meta );
    $tmpl =~ s/%ATTACHTABLE%/$atext/go;
    $tmpl = &TWiki::Func::expandCommonVariables( $tmpl, $topic, $webName );
## TW: duplicate?
    #    $tmpl = &TWiki::handleMetaTags( $webName, $topic, $tmpl, $meta );
    $tmpl = &TWiki::Func::renderText($tmpl);
    $tmpl =~ s/%TABLEFIELDS%/$formText/go
      ;    #Moved after getRenderedVersion so that TWiki Syntax does not expand

    TWiki::Func::writeHeader($query);
    print $tmpl;
}

# =========================
sub handleError {
    my ( $message, $query, $theWeb, $theTopic, $theOopsTemplate, $oopsArg1,
        $oopsArg2 )
      = @_;

    my $url =
      &TWiki::Func::getOopsUrl( $theWeb, $theTopic, $theOopsTemplate, $oopsArg1,
        $oopsArg2 );
    TWiki::Func::redirectCgiQuery( $query, $url );
}

# =========================
sub uploadTable {

    my $session = shift;
    $TWiki::Plugins::SESSION = $session;

    $session->enterContext('edit');
    my $query   = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic   = $session->{topicName};
    my $user    = $session->{user};

    my $template  = $query->param( 'template'  || '' );
    my $tableName = $query->param( 'tablename' || '' );
    my $name      = $query->param( 'name'      || '' );
    my $deleteElement = $query->param('deleteElement');
    my $copyElement   = $query->param('copyElement');
    my $showtable     = $query->param('showtable');

    ### TW: Could ommit
    TWiki::UI::checkWebExists( $session, $webName, $topic, 'edit' );
    TWiki::UI::checkMirror( $session, $webName, $topic );

    return
      unless (
        &doEnableEdit( $webName, $topic, $user, $query, 'uploadTable' ) );

    my $filePath = $query->param('filepath') || '';
    my $fileName = $query->param('filename') || '';
    if ( $filePath && !$fileName ) {
        $filePath =~ m|([^/\\]*$)|;    #)
        $fileName = $1;
    }

    # Need to cycle through the fieldDefs and query the parameters to fill the
    # the associative array
    use TWiki::Form;
    my $theForm = new TWiki::Form( $session, $webName, $template );
    my $fieldDefs = $theForm->{fields};

    my $fieldElements = {};

    # Name is name based upon a unique time-stamp. This is based to the
    # editTable.tmpl and is transparent to the user. This removes the
    # constraint of unique first columns.
    my $sortName = $name;

    if ($copyElement) {    #Give unique table element keys for copied elements
        $sortName = time;
    }

    my $firstEntry = 1;
    foreach my $fieldInfo ( @{$fieldDefs} ) {
        my $entryName  = $fieldInfo->{name};
        my $title      = $fieldInfo->{title};
        my $type       = $fieldInfo->{type};
        my $size       = $fieldInfo->{size};
        my $tableEntry = $query->param($entryName);
        my $cvalue     = '';

        # Puts default text '---' for first entry
        if ( $firstEntry == 1 ) {
            $tableEntry = '---' if ( $tableEntry eq '' );
            $firstEntry = 0;
        }

        # Takes care of special checkbox entry (Form.pm -- line : 376)
        if ( !$tableEntry && $type =~ '^checkbox' ) {
            foreach my $name ( @{$fieldInfo} ) {
                $cvalue = $query->param( "$entryName" . "$name" );
                if ( defined($cvalue) ) {
                    if ( !$tableEntry ) {
                        $tableEntry = '';
                    }
                    else {
                        $tableEntry .= ', ' if ($cvalue);
                    }
                    $tableEntry .= "$name" if ($cvalue);
                }
            }
        }

        $fieldElements->{$entryName} = carriageReturnConvert($tableEntry);
    }
    $fieldElements->{name} = stringConvert($sortName);

    # need to change windows path to unix path
    my $tmpFilename =~ s@\\@/@go;
    $tmpFilename =~ /(.*)/;
    $tmpFilename = $1;

    my ( $fileSize, $fileUser, $fileDate, $fileVersion ) = '';

    # update topic
    my ( $meta, $text ) = &TWiki::Func::readTopic( $webName, $topic );

# Remove any elements that have spaces in the name. They will be added without spaces (This should be removed)
    if ( $sortName ne stringConvert($sortName) ) {
        $meta->remove( 'TABLE', $sortName );
    }

    if ($deleteElement) {
        $meta->remove( 'TABLE', stringConvert($sortName) );
    }
    else {
        updateTable( $meta, $template, $tableName, $fieldElements );
    }

    my $error = &TWiki::Func::saveTopic( $webName, $topic, $meta, $text );
    TWiki::Func::setTopicEditLock( $webName, $topic, 0 );
    if ($error) {
        handleError( 'Save topic error',
            $query, $webName, $topic, 'oopssaveerr', $error );
    }
    else {

        # and finally display topic
        TWiki::Func::redirectCgiQuery( $query,
            &TWiki::Func::getViewUrl( $webName, $topic ) );
    }
}

1;
