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
package TWiki::Plugins::MultiEditPlugin;

# =========================
use vars qw(
  $VERSION $pluginName $debug
  $label $skipskin $placement %renderedText $prefix
);

use TWiki::Func;
use TWiki::Contrib::EditContrib;

$VERSION    = '$Rev: 0000';
$pluginName = 'MultiEditPlugin';

$RELEASE = 'Dakar';

use strict;

# =========================
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning(
            "This version of $pluginName works only with TWiki 4 and greater.");
        return 0;
    }

    $label = &TWiki::Func::getPreferencesValue("\U$pluginName\E_LABEL")
      || "Edit";

    #Figure out how to do security in Dakar
    #$label =~ s/$TWiki::securityFilter//go;    # zap anything suspicious
    #$label = eval $label;
    $label = TWiki::Func::expandCommonVariables($label);

#Example for img tag:
#$label = "<br><img src=\"". &TWiki::Func::getPubUrlPath() . "/$installWeb/EditTablePlugin/edittable.gif\" alt=\"Edit\" border=\"0\">";
    $skipskin = &TWiki::Func::getPreferencesValue("\U$pluginName\E_SKIPSKIN")
      || '';
    $placement = &TWiki::Func::getPreferencesValue("\U$pluginName\E_PLACEMENT")
      || 'after';
    $placement = ( $placement =~ /before/i ? 1 : 0 );

    #initialize a few other things
    %renderedText = ();
    $prefix       = "<_render_>";

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================

# NOTE: At preRenderingHandler (were all the heavy lifting is done),
# we have lost the information that the text might be included from
# another topic, and all edit links will be not to the included topic
# but the including topic, resulting in the edit failing.
# As a workaround (TWiki core should really help here) remember the
# web and topic in commonTagsHandler (the only place where the included
# topic is accessible) in the section tag. Unfortunately we cannot use
# the more efficient registered tags, as this only works for tags
# delimited with '%' (then we would use $this->{SESSION_TAGS}{'TOPIC'}
# to access the topic.

# NOTE: Requires patch to TWiki.pm. Otherwise sections in included topics
# can only be edited if all sections are being included, as otherwise
# the sections start from the wrong place (i.e., after the %STARTINCLUDE%)
# This could be solved also by having a =beforeIncludeHandler= (see
# TWiki:Codev.NeedBeforeIncludeHandler)

sub beforeCommonTagsHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug(
        "- ${pluginName}::beforeIncludeHandler( $_[2].$_[1] )")
      if $debug;

    my $sec = 0;
    $_[0] =~
      s/<section((\s+[^>]+)?)>/&rememberTopic($_[1], $_[2], $1, $sec)/geo;

    TWiki::Func::writeDebug(
        "- after ${pluginName}::beforeIncludeHandler( $_[2].$_[1] )")
      if $debug;

}

sub rememberTopic {
    my ( $topic, $web, $posattr ) = @_;

##SMELL: Need to make sure the section attribute is given, even if
##topic was passed already
##SMELL: Not sure what the label="..." parameter is all about but it
##does not allow editing later as the edit does not find the prefixed section
    my $seclabel = '';
    if ( $posattr =~ s/label\s*=\"(.*?)\"//o ) {
        $seclabel = $1;
    }
    if ( $posattr =~ / topic=/o ) {
        return "<section$posattr>";
    }
    else {
        $_[3]++;
        return
"<section$posattr topic=\"$topic\" web=\"$web\" section=\"$seclabel$_[3]\">";
    }
}

# =========================

sub preRenderingHandler {
### my ( $text, $pmap ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    my $session = $TWiki::Plugins::SESSION;
    &TWiki::Func::writeDebug(
"- ${pluginName}::preRenderingHandler( $session->{webName}.$session->{topicName} )"
    ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # Only bother with this plugin if viewing (i.e. not searching, etc)
    my $cgiAction = TWiki::Contrib::EditContrib::getCgiAction();
    return unless ( $cgiAction =~ m/view|viewauth|render/o );

    my $ctmpl = $session->{cgiQuery}->param('template') || '';
    my $cskin = &TWiki::Func::getSkin() || '';
    my $skipit = 0;
    foreach my $ss ( split( /\s*,\s*/, $skipskin ) ) {
        if ( ( $cskin eq $ss ) || ( $ctmpl eq $ss ) ) {
            $skipit = 1;
        }
    }

    #    return if $skipit; ## SMELL: Why has this been removed by MD?
    my $ret  = '';
    my $eurl = TWiki::Func::getScriptUrlPath() . '/editonesection';

    my $sectionedit = ( $_[0] =~ m%<section( |>)%i );

    if ($sectionedit) {
        my @sections = split( /(<\/?section(\s+[^>]+)?>)/i, $_[0] );
        my $dontedit;
        my $pos     = 0;
        my $state   = 'noedit';
        my $skip    = 0;
        my $lastsec = '';
        my $topic;
        my $web;
        my $cnt = 0;

        foreach my $sec (@sections) {
            if ($skip) { $skip = 0; next; }
            if ( $sec =~ m/<section(.*)>/i ) {
                use TWiki::Attrs;
                my $attrs = new TWiki::Attrs( $1, 1 );
                $dontedit = ( defined $attrs->{edit} && !$attrs->{edit} )
                  || $skipit;
                $topic = $attrs->{topic};
                $web   = $attrs->{web};
                $pos   = $attrs->{section};
                $cnt++;
                $pos   = $cnt unless $pos;
                $state = 'edit';
                $skip  = 1;
                next;
            }
            if ( $sec eq "</section>" ) {
                $skip = 1;
                my $tmp = TWiki::Func::renderText( $lastsec, $web );

                # restore verbatim markers
                $tmp =~
s/\<\!\-\-\!([a-z0-9]+)\!\-\-\>/\<\!\-\-$TWiki::TranslationToken$1$TWiki::TranslationToken\-\-\>/gio;
                my $rText =
                  ($dontedit)
                  ? $tmp
                  : &editRow( "$eurl/$web/$topic", $pos, $tmp );

                # now restore pre
##SMELL: This should work also for verbatim, etc., but that information
##is (contrary to the documentation) not passed into a handler. Need to
##continue to rely on the deprecated endRenderingHandler.
                putBackBlocks( \$rText, $_[1], 'pre' );

                $renderedText{"$pos$web$topic"} = $rText;
                $lastsec = '';
                $ret .= "$prefix$pos$web$topic$prefix";
                $dontedit = 0;
                $state    = 'noedit';
                next;
            }
            if ( $state eq 'edit' ) { $lastsec = $sec; }
            else                    { $ret .= $sec; }
        }
        $_[0] = $ret . $lastsec;

    }
}

sub putBackBlocks {
    my ( $text, $map, $tag ) = @_;

    foreach my $placeholder ( keys %$map ) {
        if ( $placeholder =~ /^$tag\d+$/ ) {
            my $params = $map->{$placeholder}{params} || '';
            my $val = $map->{$placeholder}{text};
            $$text =~
s(<!--$TWiki::TranslationToken$placeholder$TWiki::TranslationToken-->)(<$tag$params>$val</$tag>);
        }
    }
}

# =========================
sub editLink {
    my ( $eurl, $pos, $title ) = @_;
    my $session = $TWiki::Plugins::SESSION;
    return
        "<a class=\"multiEditLink\" href=\"$eurl\?t="
      . time()
      . "&sec=$pos&redirectto="
      . $session->{webName} . '.'
      . $session->{topicName}
      . "#SECEDITBOX\">$title</a>";
}

# =========================
sub editRow {
    my ( $eurl, $pos, @content ) = @_;
    return '<div class="multiEditSection">'
      . (
        $placement
        ? editLink( $eurl, $pos, $label ) . join( "", @content )
        : join( '', @content ) . editLink( $eurl, $pos, $label )
      ) . '</div>';
}

# =========================
# Need to use this deprecated plugin, as otherwise the verbatim does not
# get put back in. Eventually, add verbatim etc. insertion back into her
# from TWiki::Render::getRenderedVersion.
# Note that the current version does not handle pre sections correctly,
# as this handler runs after the pre is restored.
# TODO: move to postRenderingHandler, but restore verbatim and pre.
sub endRenderingHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    return if ( $_[0] =~ m/\<\/?body[^>]*\>/o );

    my $session = $TWiki::Plugins::SESSION;
    TWiki::Func::writeDebug(
"- ${pluginName}::endRenderingHandler( $session->{webName}.$session->{topicName} )"
    ) if $debug;

    while ( $_[0] =~ s/$prefix(.*?)$prefix/$renderedText{$1}/e ) { }
}

# =========================

sub doEdit {
    my $session = shift;
    my $text    = '';
    my $tmpl    = '';
    ( $session, $text, $tmpl ) = &TWiki::Contrib::EditContrib::edit($session);

    my $query         = $session->{cgiQuery};
    my $webName       = $session->{webName};
    my $topic         = $session->{topicName};
    my $theSec        = int( $query->param('sec') ) || 0;
    my $editUrlParams = "&sec=$theSec#SECEDITBOX";
    $tmpl =~ s/%EDIT%/editonesection/go;
    $tmpl =~ s/%EDITPARAMS%/$editUrlParams/go;
    my $sectxt = '';
    my $pretxt = '';
    my $postxt = '';
    my $pos    = 1;

    # Get rid of CRs (we only want to deal with LFs)
    $text =~ s/\r//g;

    if ( $text =~ m/<\/?section>/i ) {
        my @sections = split( /(<\/?section\s*(\s+[^>]+)?>)/i, $text );
        $pretxt .= $sections[0];
        for ( my $s = 1 ; $s < $#sections ; $s += 6 ) {
            if ( $pos < $theSec ) {
                $pretxt .=
                    $sections[$s]
                  . $sections[ $s + 2 ]
                  . $sections[ $s + 3 ]
                  . $sections[ $s + 5 ];
            }
            elsif ( $pos > $theSec ) {
                $postxt .=
                    $sections[$s]
                  . $sections[ $s + 2 ]
                  . $sections[ $s + 3 ]
                  . $sections[ $s + 5 ];
            }
            else {
                $pretxt .= $sections[$s];
                $sectxt = $sections[ $s + 2 ];
                $postxt .= $sections[ $s + 3 ] . $sections[ $s + 5 ];
            }
            $pos++;
        }
    }

    TWiki::Contrib::EditContrib::finalize_edit( $session, $pretxt, $sectxt,
        $postxt, '', '', $tmpl );

}

1;
