#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
package TWiki::Plugins::SectionalEditPlugin;

# =========================
use strict;

use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug $pluginName
  $bgcolor $label $skipskin $leftjustify $alwayssection
  $sectiondepth $sectiondepthmin $sectioninit $editstyle $placement
);

use TWiki::Contrib::EditContrib;

$VERSION = '17 Aug 2006';

$RELEASE = 'Dakar';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between ${pluginName} and Plugins.pm");
        return 0;
    }

    $bgcolor = &TWiki::Func::getPreferencesValue("SECTIONALEDITPLUGIN_BGCOLOR")
      || "silver";
    $bgcolor = &TWiki::Func::expandCommonVariables( $bgcolor, $topic, $web );
    $label = &TWiki::Func::getPreferencesValue("SECTIONALEDITPLUGIN_LABEL")
      || "Edit";
    $label = TWiki::Func::expandCommonVariables($label);
    $skipskin =
      &TWiki::Func::getPreferencesValue("SECTIONALEDITPLUGIN_SKIPSKIN") || "";
    $leftjustify =
      &TWiki::Func::getPreferencesValue("SECTIONALEDITPLUGIN_JUSTIFICATION")
      || "left";
    $leftjustify = ( $leftjustify =~ /left/i ? 1 : 0 );

    $alwayssection = &TWiki::Func::getPreferencesValue("EDITSECTIONS") || 0;
    $sectiondepth  = &TWiki::Func::getPreferencesValue("SECTIONDEPTH") || "all";
    $sectiondepth =~ s/all/6/gio;
    $sectiondepthmin = &TWiki::Func::getPreferencesValue("SECTIONDEPTHMIN")
      || 0;
    $sectiondepthmin = $sectiondepth if ( $sectiondepthmin > $sectiondepth );
    $sectioninit = ($sectiondepthmin) ? 0 : 1;
    $sectiondepthmin = 1 unless $sectiondepthmin;
    $editstyle = &TWiki::Func::getPreferencesValue("SECTIONALEDITPLUGIN_STYLE")
      || "";

    if ($editstyle) {
        $placement =
          &TWiki::Func::getPreferencesValue("SECTIONALEDITPLUGIN_PLACEMENT")
          || "above";
        $placement = ( $placement =~ /above/i ? 1 : 0 );
    }
    else {
        $placement = $leftjustify;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("SECTIONALEDITPLUGIN_DEBUG");

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub blankCell {
    return ($editstyle) ? "" : "<td></td>";
}

# =========================
sub editLink {
    my ( $eurl, $pos, $title ) = @_;
    return
        "<a href=\"$eurl\?t="
      . time()
      . "&sec=$pos#SECEDITBOX\"><small> $title </small></a>";
}

# =========================
sub editCell {
    my ( $eurl, $pos ) = @_;
    if ($editstyle) {
        return
            "<div align=\""
          . ( ($leftjustify) ? "left" : "right" ) . "\">"
          . editLink( $eurl, $pos, $label )
          . "</div>";
    }
    else {
        return
"<td bgcolor=\"$bgcolor\" align=\"right\" valign=\"top\" width=\"0%\">"
          . editLink( $eurl, $pos, $label ) . "</td>";
    }
}

# =========================
sub editableContentCell {
    if ($editstyle) {
        return "<div $editstyle>\n" . join( "", @_ ) . "</div>";
    }
    else {
        return
          "<td align=\"left\" valign=\"top\" width=\"100%\">\n"
          . join( "", @_ ) . "</td>";
    }
}

sub contentCell {
    if ($editstyle) {
        return join( "", @_ );
    }
    else {
        return
          "<td align=\"left\" valign=\"top\" width=\"100%\">\n"
          . join( "", @_ ) . "</td>";
    }
}

# =========================
sub editRow {
    my ( $eurl, $pos, @content ) = @_;
    return ( ($editstyle) ? "" : "<tr>" )
      . (
        $placement
        ? editCell( $eurl, $pos ) . editableContentCell(@content)
        : editableContentCell(@content) . editCell( $eurl, $pos )
      ) . ( ($editstyle) ? "" : "</tr>" );
}

# =========================
sub displayRow {
    return ( ($editstyle) ? "" : "<tr>" )
      . (
        $placement
        ? blankCell() . contentCell(@_)
        : contentCell(@_) . blankCell()
      ) . ( ($editstyle) ? "" : "</tr>" );
}

# =========================
sub preRenderingHandler {
### my ( $text, $pmap ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &TWiki::Func::writeDebug("- ${pluginName}::preRenderingHandler( $topic )")
      if $debug;

    # This handler is called by getRenderedVersion just before the line loop
    # Only bother with this plugin if viewing (i.e. not searching, etc)
    return unless ( $0 =~ m/view|viewauth|render/o );

    my $ctmpl = $TWiki::Plugins::SESSION->{cgiQuery}->param('template') || '';
    my $cskin = &TWiki::Func::getSkin() || '';
    my $skipit = 0;
    foreach my $ss ( split( /\s*,\s*/, $skipskin ) ) {
        if ( ( $cskin eq $ss ) || ( $ctmpl eq $ss ) ) {
            $skipit = 1;
            last;
        }
    }

    unless ($skipit) {
        my $editsections = 'EditSections'
          if (
            (
                   $alwayssection
                && $_[0] !~ /\<body class\=/is
                && $_[0] !~ /\<\/body\>/is
            )
            || ( $_[0] =~ m%<editsections\s*/>%i )
          );

      # <sectionbreak/> inserts break in sections, <editsections/> sections all.
      # why did we also use <sectionbreak/> in the first line to section all?
      # Make sure space before /> is allowed also in the script
        my $sectionbreak = 'SectionBreak'
          if ( $_[0] =~ m%<sectionbreak\s*/?>%i );

        # Why is the /> possible?
        my $sectionedit = 'SectionEdit' if ( $_[0] =~ m%<sectionedit.*?>%i );
        my $activate = $editsections || $sectionbreak || $sectionedit;

        if ($activate) {
            my $ret = '';
            $ret = '<table border="0" width="100%">' unless $editstyle;
            my $eurl =
              TWiki::Func::getScriptUrlPath() . "/editsection/$web/$topic";
            &TWiki::Func::writeDebug("- $activate Found") if $debug;

            if ($editsections) {
                my $pos      = 0;
                my $lastpos  = 0;
                my $lastmark = "";
                my $text     = $_[0];
                my $sec      = "";
                my $foundit  = ($sectioninit) ? 1 : 0;
                while ( $text =~ m/^---(\+{1,$sectiondepth})[^+]/mg ) {

                    # Minor bug in the above regex: A "---+" with no
                    # title text before either newline or end of topic
                    # does not render as heading but is treated as
                    # editable section
                    my $curpos  = pos $text;
                    my $curmark = $&;
                    $sec =
                      substr( $text, $lastpos,
                        $curpos - length($&) - $lastpos );
                    if ($foundit) {
                        $ret .=
                          editRow( $eurl, $pos,
                            ( $pos > 0 ? "\n" . $lastmark : "" ) . $sec )
                          unless ( $sec =~ /^\s*$/o );
                    }
                    else {
                        if ($editstyle) {
                            $ret .= ( $pos > 0 ? "\n" . $lastmark : "" ) . $sec;
                        }
                        else {
                            $ret .= "<tr><td>";
                            $ret .= ( $pos > 0 ? "\n" . $lastmark : "" ) . $sec;
                            $ret .= "</td></tr>";
                        }
                    }
                    if ( length($1) < $sectiondepthmin ) {
                        $foundit = 0;
                    }
                    else {
                        $foundit = 1;
                    }
                    $lastmark = $curmark;
                    $lastpos  = $curpos;
                    $pos++;
                }

                # If there were no sections, leave text alone
                return if ( $lastpos == $pos );

                # Otherwise, complete the section
                $sec = substr( $text, $lastpos );
                if ($foundit) {
                    $ret .=
                      editRow( $eurl, $pos,
                        ( $pos > 0 ? "\n" . $lastmark : "" ) . $sec )
                      unless ( $sec =~ /^\s*$/o );
                }
                else {
                    if ($editstyle) {
                        $ret .= ( $pos > 0 ? "\n" . $lastmark : "" ) . $sec;
                    }
                    else {
                        $ret .= "<tr><td>";
                        $ret .= ( $pos > 0 ? "\n" . $lastmark : "" ) . $sec;
                        $ret .= "</td></tr>";
                    }
                }
            }
            elsif ($sectionbreak) {
                my @sections = split( /<sectionbreak\s*\/?>/i, $_[0] );
                my $pos = 0;
                foreach my $sec (@sections) {
                    $ret .= editRow( $eurl, $pos, $sec );
                    $pos++;
                }
            }
            elsif ($sectionedit) {
                my @sections  = split( /(<\/?sectionedit.*?>)/i, $_[0] );
                my $pos       = 0;
                my $state     = "noedit";
                my $origstyle = $editstyle;
                foreach my $sec (@sections) {
                    if ( $sec =~ m/<sectionedit(.*?)>/i ) {
                        $editstyle = $1 if $1;
                        $state = "edit";
                        next;
                    }
                    if ( $sec eq "</sectionedit>" ) {
                        $editstyle = $origstyle;
                        $state     = "noedit";
                        next;
                    }
                    if ( $state eq "edit" ) {
                        $ret .= editRow( $eurl, $pos, $sec );
                    }
                    else { $ret .= displayRow($sec); }
                    $pos++;
                }
            }
            $ret .= '</table>' unless $editstyle;
            $_[0] = $ret;
        }
    }
}

# =========================
sub edit {
    my $session = shift;

    $TWiki::Plugins::SESSION = $session;
    $session->enterContext('edit');
    my $text = '';
    my $tmpl = '';
    ( $session, $text, $tmpl ) = &TWiki::Contrib::EditContrib::edit($session);

    my $query   = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic   = $session->{topicName};
    my $theSec  = int( $query->param('sec') ) || 0;
    my $theEditUrl =
      &TWiki::Func::getScriptUrl( $webName, $topic, "editsection" );
    my $theEditUrlParams = "&sec=$theSec#SECEDITBOX";
    $tmpl =~ s/%EDIT%/$theEditUrl/go;
    $tmpl =~ s/%EDITPARAMS%/$theEditUrlParams/go;
    my $sectxt       = "";
    my $pretxt       = "";
    my $postxt       = "";
    my $pos          = 0;
    my $editsections = 0;

    # Get rid of CRs (we only want to deal with LFs)
    $text =~ s/\r//g;

    if ( $text =~ m/<sectionbreak\s*\/?>/i ) {
        my @sections = split( /<sectionbreak\s*\/?>/i, $text );

  # The following does not honor the literal spelling of the <sectionbreak/> tag
        foreach my $s (@sections) {
            if ( $pos < $theSec ) {
                unless ( $pretxt eq "" ) {
                    $pretxt .= "<sectionbreak/>";
                }
                $pretxt .= $s;
            }
            elsif ( $pos > $theSec ) {
                $postxt .= "<sectionbreak/>";
                $postxt .= $s;
            }
            else {
                $sectxt = $s;
            }
            $pos++;
        }
        unless ( $pretxt eq "" ) {
            $pretxt .= "<sectionbreak/>\n";
        }
    }
    elsif ( $text =~ m/<\/?sectionedit.*?>/i ) {
        my @sections = split( /(<\/?sectionedit.*?>)/i, $text );
        foreach my $s (@sections) {
            if ( $pos < $theSec ) {
                if ( $s =~ m/<(\/?)sectionedit(.*?)>/ ) {
                    $pretxt .= "<$1sectionedit$2>";
                    next;
                }
                $pretxt .= $s;
            }
            elsif ( $pos > $theSec ) {
                if ( $s =~ m/<(\/?)sectionedit(.*?)>/ ) {
                    $postxt .= "<$1sectionedit$2>";
                    next;
                }
                $postxt .= $s;
            }
            else {
                if ( $s =~ m/<(\/?)sectionedit(.*?)>/ ) {
                    $pretxt .= "<$1sectionedit$2>";
                    next;
                }
                $sectxt = $s;
            }
            $pos++;
        }
    }
    else {

# assume that $TWiki::Plugins::SectionalEditPlugin::alwayssection || ($editsections = $text =~ m/<editsections\s*\/>/i)
# cannot check for this, as we might have used %TEXTSTART%
        my $lastmark = "";
        my $lastpos  = 0;
        while ( $text =~ m/^---\+{1,$sectiondepth}[^+]/mg ) {
            if ( $pos == $theSec ) {
                $postxt = $& . $';
                $sectxt = $lastmark
                  . substr( $text, $lastpos,
                    ( pos $text ) - length($&) - $lastpos );
                $pos++;
                last;
            }
            elsif ( $pos == ( $theSec - 1 ) ) {
                $lastmark = $&;
                $lastpos  = pos $text;
                $pretxt   = $`;
            }
            $pos++;
        }
        if ( $pos == $theSec ) {

            # The target section was the last section
            #$postxt = "";
            $sectxt = $lastmark . substr( $text, $lastpos );
        }
        if ($editsections) {

            # move the <editsections/> command into $pretxt
            if ( $sectxt =~ s|<editsections\s*\/>||i ) {
                $pretxt = "<editsections\/>\n$pretxt";
            }
        }

        # Move the end of line to the beginning of postxt
        # So that sections aren't accidentally collapsed
        # (by user deleting the trailing newline in section)
        if ( $sectxt =~ s/[\n\r]$//s ) {
            $postxt = "\n" . $postxt;
        }
    }
    TWiki::Contrib::EditContrib::finalize_edit( $session, $pretxt, $sectxt,
        $postxt, $pretxt, $postxt, $tmpl );

}

1;
