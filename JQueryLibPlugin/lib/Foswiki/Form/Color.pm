# See bottom of file for license and copyright details
package Foswiki::Form::Color;
use Foswiki::Form::FieldDefinition;
our @ISA = qw( Foswiki::Form::FieldDefinition );

use strict;

our $firstField = 1;

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);

    #my $size  = $this->{size} || '';
    #$size =~ s/\D//g;
    #$size = 10 if ( !$size || $size < 1 );
    #Need enough space to input 'transparent'
    $this->{size} = 11;
    return $this;
}

#TODO: move behavior constant in configuration. Things like the 250ms for instance.
sub renderForEdit {
    my ( $this, $web, $topic, $value ) = @_;

    my $field = CGI::textfield(
        -class => $this->cssClasses('foswikiInputField'),
        -name  => $this->{name},
        -size  => $this->{size},
        -value => $value,
        -id    => $this->{name},

        #We hide the colorpicker when loosing the focus
        -onblur => '$(\'#colorpicker\').farbtastic().fadeOut(250);',

        #We link and show the colorpicker when clicking the field
        -onclick => '$.farbtastic(\'#colorpicker\').linkTo(\'#'
          . $this->{name}
          . '\'); var pos=$(this).position(); pos.top+=$(this).outerHeight(); $(\'#colorpicker\').farbtastic().offset(pos).fadeIn(250);'
      )

      #Now make sure the color of the text field gets initialized
      . '<script type="text/javascript">  $(document).ready(function() {$.farbtastic(\'#colorpicker\').linkTo(\'#'
      . $this->{name}
      . '\');});</script>';

    #If this is the first field on this page then we output the colorpicker div
    if ($firstField) {
        $firstField = 0;

        addScriptToHead("plugins/farbtastic/farbtastic.js");
        addStyleToHead("plugins/farbtastic/farbtastic.css");
        $field =
'<div id="colorpicker" class="ui-component-content ui-widget-content ui-hidden ui-helper-hidden" style="position: absolute;" ondblclick="$(this).farbtastic().fadeOut(250);"></div>'
          . $field;
    }

    return ( '', $field );
}

############ We duplicated a whole bunch of code from JQueryLibPlugin.pm so that we could include farbtastic.js and farbtastic.css from here.

sub addStyleToHead {
    my $style = shift;
    $style = trim($style);
    my $styleid = "JQueryLibPlugin_$style";
    Foswiki::Func::addToHEAD( $styleid, JQueryStyle($style) );
}

############

sub addScriptToHead {
    my $script = shift;
    $script = trim($script);
    my $scriptid = "JQueryLibPlugin_$script";
    Foswiki::Func::addToHEAD( $scriptid, JQueryScript($script) );
}

############

sub JQueryScript {
    my ($scriptFileName) = @_;
    return
"<script type=\"text/javascript\" src=\"%PUBURLPATH%/%SYSTEMWEB%/JQueryLibPlugin/$scriptFileName\"></script>";
}

############

sub JQueryStyle {
    my ($styleFileName) = @_;
    return
"<style type='text/css'>\@import url('%PUBURLPATH%/%SYSTEMWEB%/JQueryLibPlugin/$styleFileName');</style>";
}

############

sub trim {
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{size};
    undef $firstField;
}

1;
__DATA__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

# Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

