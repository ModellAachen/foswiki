# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Steven Sprouse, steve04@meitek.com
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
# copyright (C) 2009 Foswiki Contributors
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
# This file contains routine for producing a PNG barcode
# Requires Barcode::Code128 be installed .
# I used several routines from the GaugePlugin

# =========================
package Foswiki::Plugins::BarcodePlugin
  ;    # change the package name and $pluginName!!!

# =========================

use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug
  $barcodeCount
  $defaultText
  $defaultPadding
  $defaultHeight
  $defaultScale
  $defaultBorder
  $defaultFont
  $defaultTransparentText
  $defaultFontAlign;
  $defaultShowText;
  $defaultCueCat;
  $pluginInitialized;
);

# This should always be $Rev$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '30 Mar 2009';

$pluginName = 'BarcodePlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = Foswiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

 # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
 # $barcodeCount is used to assign a unique filename to each barcode in a topic.
    $barcodeCount      = 0;
    $pluginInitialized = 0;

    # Plugin correctly initialized
    Foswiki::Func::writeDebug(
        "- Foswiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# Initialize all default values for the barcode plugin
sub _init_defaults {
    $defaultText            = 'R.T.F.M.';
    $defaultPadding         = 5;
    $defaultHeight          = 0;
    $defaultScale           = 2;
    $defaultBorder          = 0;
    $defaultFont            = 'medium';
    $defaultFontAlign       = 'center';
    $defaultTransparentText = 1;
    $defaultShowText        = 1;
    $defaultCueCat          = 0;
}

# Parse the parameter list returning a hash of all found parameters
sub _parse_parameters {
    my ($args) = @_;
    my %args;
    my $length = length($args);
    my ( $char, @field );

    # First break the args into individual parameters
    my $in_quote = 0;
    my $field    = "";
    my $index    = 0;
    for ( my $i = 0 ; $i < $length ; $i++ ) {

        # Get character
        $char = substr( $args, $i, 1 );
        if ( $char eq '"' ) {
            if ($in_quote) {    # If a " and already in a quote, then the end
                $in_quote = 0;
            }
            else {              # Beginning of quoted field
                $in_quote = 1;
            }
        }
        else {
            if ( $char =~ /[,\s]+/ ) {  # A field separater only if not in quote
                if ($in_quote) {
                    $field .= $char;
                }
                else {
                    $field[ $index++ ] = $field if ( $field ne "" );
                    $field = "";
                }
            }
            else {
                $field .= $char;
            }
        }
    }

    # Deal with last field
    $field[ $index++ ] = $field if ( $field ne "" );

    # Now break each parameter into a key=value pair.
    for ( my $i = 0 ; $i < $index ; $i++ ) {
        my ( $key, $value ) = split( /=/, $field[$i] );

        #print "field[$i] = [$field[$i]]\n";
        $args{$key} = $value;
    }
    return %args;
}

# Return the value for the specified Foswiki plugin parameter.  If the
# parameter does not exist, then return the specified default value.  The
# parameter is deleted from the list of specified parameters allowing the
# code to determine what parameters remain and were not requested.
sub _get_parameter {
    my ( $var_name, $default, $parameters ) = @_;
    my $value = delete $$parameters{$var_name};   # Delete since already parsed.
    if ( defined $value && $value ne "" ) {
        return $value;
    }
    else {
        return $default;
    }
}

sub _make_error {
    my ($msg) = @_;
    return "<font color=red>BarcodePlugin error: $msg</font>";
}

# Generate the file name in which the graphic file will be placed.  Also
# make sure that the directory in which the graphic file will be placed
# exists.  If not, create it.
sub _make_filename {
    my ( $type, $name, $topic, $web ) = @_;

    # Generate the file name to be created
    my $fullname;
    $fullname = "_BarcodePlugin_${type}_${name}.png";

    # before save, create directories if they don't exist.
    # If the top level "pub/$web" directory doesn't exist, create it.
    my $dir = Foswiki::Func::getPubDir() . "/$web";
    if ( !-e "$dir" ) {
        umask(002);
        mkdir( $dir, 0775 );
    }

    # If the top level "pub/$web/$topic" directory doesn't exist, create
    # it.
    my $tempPath = "$dir/$topic";
    if ( !-e "$tempPath" ) {
        umask(002);
        mkdir( $tempPath, 0775 );
    }

    # Return both the directory and the filename
    return ( $tempPath, $fullname );
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    Foswiki::Func::writeDebug(
        "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    $_[0] =~ s/%BARCODE{(.*?)}%/&_makeBarcode($1,$_[1], $_[2])/geo;
}

# =========================
sub _makeBarcode {
    Foswiki::Func::writeDebug("- ::makeBarcode ") if $debug;
    my ( $args, $topic, $web ) = @_;
    if ( !$pluginInitialized ) {
        $pluginInitialized = 1;
        _init_defaults();
        eval { require Barcode::Code128; };
    }

    #Parse the args
    my %parameters = _parse_parameters($args);

    Foswiki::Func::writeDebug("- ${pluginName}::handleBarcode( arg=$args )")
      if $debug;

    #Create the PNG
    my $bc = new Barcode::Code128;

    # Get text
    my ($text) = _get_parameter( "text", $defaultText, \%parameters );
    Foswiki::Func::writeDebug("- ${pluginName}::handleBarcode text=$text")
      if $debug;

    # Get Default Paramters
    my ($padding) = _get_parameter( "padding", $defaultPadding, \%parameters );
    my ($height)  = _get_parameter( "height",  $defaultHeight,  \%parameters );
    my ($scale)   = _get_parameter( "scale",   $defaultScale,   \%parameters );
    my ($border)  = _get_parameter( "border",  $defaultBorder,  \%parameters );
    my ($font)    = _get_parameter( "font",    $defaultFont,    \%parameters );
    my ($font_align) =
      _get_parameter( "font_align", $defaultFontAlign, \%parameters );
    my ($transparent_text) =
      _get_parameter( "transparent_text", $defaultTransparentText,
        \%parameters );
    my ($show_text) =
      _get_parameter( "show_text", $defaultShowText, \%parameters );
    $bc->padding($padding);
    $bc->height($height);
    $bc->scale($scale);
    $bc->border($border);
    $bc->font($font);
    $bc->font_align($font_align);
    $bc->transparent_text($transparent_text);
    $bc->show_text($show_text);

    #See if this is for a CueCat
    my ($cue_cat) = _get_parameter( "cue_cat", $defaultCueCat, \%parameters );
    if ($cue_cat) {
        $text =~ tr|A-Za-z\-|a-zA-Z/|;
    }
    my ( $dir, $filename ) =
      _make_filename( "barcode", $barcodeCount++, $topic, $web );
    Foswiki::Func::writeDebug(
        "- ${pluginName}::handleBarcode file=$dir $filename")
      if $debug;

    my $bc_png;
    eval { $bc_png = $bc->png($text) } || return _make_error $@;
    open( PNG, "> $dir/$filename" )
      or return _make_error "Can't write temporary file $dir/$filename";
    print PNG $bc_png;
    close(PNG);

    #Return the link to the barcode image
    return " <img src=\"%ATTACHURL%/$filename?t=timestamp\" alt=\"$text\" />";
}

# =========================

1;
