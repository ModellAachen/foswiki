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
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# =========================
package TWiki::Plugins::FormFieldsPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  $exampleCfgVar $writeScript %template
);

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

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between FormFieldsPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("FORMFIELDSPLUGIN_DEBUG");

    $writeScript = "";
    %template    = ();

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::FormFieldsPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub init {

    # Lazy initiation
    if ( !$template{"SCRIPT"} ) {
        my $text = &TWiki::Func::readTemplate("formfields");
        my @sections = split( /%SPLIT%/o, $text );
        foreach my $section (@sections) {
            if ( $section =~ /^([^:]+):/o ) {
                my $key = $1;
                $section =~ s/^([^:]+)://o;
                $template{$1} = $section;
            }
        }
    }
}

sub multiselectItem {
    my ($value) = @_;
    my $item = $template{"MULTI-ITEM"};
    $item =~ s/%VALUE%/$value/g;
    return $item;
}

sub singleselectItem {
    my ( $value, $current ) = @_;
    my $item = $template{"SINGLE-ITEM"};
    $item =~ s/%VALUE%/$value/go;
    my $selected = ( $value eq $current ) ? "selected=\"selected\"" : "";
    $item =~ s/%SELECTED%/$selected/go;
    return $item;
}

sub colourChooser {
    my ( $name, $current, $possibleValues ) = @_;

    $current = $possibleValues if ( !$current );
    my $html = $template{"COLOUR-CHOOSER"};
    $html =~ s/%NAME%/$name/g;
    $html =~ s/%VALUE%/$current/g;
    return $html;
}

sub multiselect {
    my ( $name, $size, $current, $possibleValues ) = @_;

    my $right =
"<select multiplex=\"true\" size=\"10\" name=\"${name}R\" style=\"width:150\">\n";
    my @currentValues = split( /,/, $current );
    my %selected      = ();
    my $sep           = "";
    my $values        = "";
    foreach my $item (@currentValues) {
        $selected{$item} = 1;
        $right  .= multiselectItem($item);
        $values .= "$sep$item";
        $sep = ", ";
    }
    $right .= "</select>\n";

    $left = $template{"MULTI-START-LEFT"};
    $left =~ s/%NAME%/$name/go;
    foreach my $item ( @${possibleValues} ) {
        $left .= "   <option value=\"$item\">$item</option>\n"
          if ( !$selected{$item} );
    }
    $left .= "</select>\n";

    my $ret = $template{"MULTI"};
    $ret =~ s/%LEFT%/$left/go;
    $ret =~ s/%NAME%/$name/go;
    $ret =~ s/%RIGHT%/$right/go;
    $ret =~ s/%VALUE%/$values/go;

    return $ret;
}

sub singleselect {
    my ( $name, $size, $current, $possibleValues, $fix ) = @_;

    my $select = "";

#if( $fix eq "no" ) {
#    $select .= singleselectItem("--free form--", $current ? "--free form--" : $current);
#}
    foreach my $item (@$possibleValues) {
        $select .= singleselectItem( $item, $current );
    }

    my $ret = $template{"SINGLE"};

    $ret =~ s/%NAME%/$name/go;
    $ret =~ s/%SIZE%/$size/go;
    $ret =~ s/%VALUE%/$current/go;
    $ret =~ s/%OPTIONS%/$select/o;

    return $ret;
}

# =========================
sub renderFormFieldForEditHandler {
    my ( $name, $type, $size, $value, $attributes, $possibleValues ) = @_;

    &TWiki::Func::writeDebug(
        "- FormFieldsPlugin::renderFormFieldForEditHandler( $web.$topic )")
      if $debug;

# This handler is called by Form.renderForEdit, before built in types are considered

    &TWiki::Func::writeDebug(
"- TWiki::Plugins::FormFieldsPlugin::renderFormFieldForEditHandler( $_[0], $_[1] ) call"
    ) if $debug;

    my $ret = "";

    #my $name = $_[0];
    #my $type = $_[1];
    #if( $type eq "text" ) {
    #    $ret = "xxx";
    #}

    ## TODO: currently uses TWiki::addScript, if this looks good then should move to Functions.pm

    my $needScript = "";

    if ( $type eq "multiselect" ) {

        # FIXME remove this option
        init();
        $ret = &multiselect( $name, $size, $value, $possibleValues );
        &TWiki::addScript(
"toShow[toShow.length]=\"${name}s\";\ntoHide[toHide.length]=\"${name}ns\";"
        );
        $needScript = 1;
    }
    elsif ( $type =~ /colou?rchooser/o ) {
        init();
        $ret = &colourChooser( $name, $value, $possibleValues );
        $needScript = 1;
    }
    elsif ( $type =~ /select *(.*)/o ) {
        my $args = $1;
        my $fix = &TWiki::Func::extractNameValuePair( $args, "fix" ) || "";
        if ( $fix eq "no" ) {
            init();
            $ret = &singleselect( $name, $size, $value, $possibleValues, $fix );
            &TWiki::addScript("toHide[toHide.length]=\"${name}\";");
            $needScript = 1;
        }
        elsif ( $multi eq "twopane" ) {
            init();
            $ret = &multiselect( $name, $size, $value, $possibleValues );
            &TWiki::addScript(
"toShow[toShow.length]=\"${name}s\";\ntoHide[toHide.length]=\"${name}ns\";"
            );
            $needScript = 1;
        }
    }

    if ( $needScript && !$writeScript ) {
        $writeScript = 1;
        &TWiki::addScript( $template{"SCRIPT"} );
    }

    return $ret;
}

# =========================

1;
