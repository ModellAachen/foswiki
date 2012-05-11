# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009-2011 Andrew Jones, http://andrew-jones.com
# Copyright (C) 2002-2006 Peter Thoeny, peter@thoeny.org
#
# For licensing info read LICENSE file in the Foswiki root.
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
# As per the GPL, removal of this notice is prohibited.
#
# =========================
#
# This file contains routines for producing PNG graphic files containing
# gauge information, useful for building dashboards.
#    NOTE: ONLY in the case where an old version of GD (1.19 or earlier) is
#    available will GIF's be created.  If the GD version is > 1.19, then
#    PNG's are created.

# =========================
package Foswiki::Plugins::GaugePlugin;

use strict;
use warnings;

# =========================
use vars qw(
  $debug
  $pluginInitialized $perlGDModuleFound
  $defaultType $defaultColors
  $defaultTambarScale $defaultTambarWidth $defaultTambarHeight
  $defaultTrendWidth $defaultTrendHeight
);

our $VERSION = '$Rev$';
our $RELEASE = '1.2';
our $SHORTDESCRIPTION =
'Build dashboards that contain graphical images of gauges defined with =%<nop>GAUGE%= macros.';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName        = 'GaugePlugin';

$pluginInitialized = 0;
$perlGDModuleFound = 0;

# =========================
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # Get plugin debug flag
    $debug = Foswiki::Func::getPluginPreferencesFlag("DEBUG") || 0;

    Foswiki::Func::writeDebug(
        "- Foswiki::Plugins::GaugePlugin::initPlugin($web.$topic) is OK")
      if $debug;

    Foswiki::Func::registerTagHandler( 'GAUGE', \&_make_gauge );

    # Mark that we are not fully initialized yet.  Only get the default
    # values from the plugin topic page iff a GAUGE is found in a topic
    $pluginInitialized = 0;
    return 1;
}

# =========================

# Initialize all default values from the plugin topic page.
sub _init_defaults {
    $pluginInitialized = 1;
    eval {
        $perlGDModuleFound = require GD;
        require POSIX;
    };

    # Get default gauge type
    $defaultType = Foswiki::Func::getPluginPreferencesValue("TYPE")
      || 'tambar';

    # Get 'tambar' default values
    $defaultTambarScale =
      Foswiki::Func::getPluginPreferencesValue("TAMBAR_SCALE")
      || "0, 10, 20, 30";
    $defaultTambarWidth =
      Foswiki::Func::getPluginPreferencesValue("TAMBAR_WIDTH") || 60;
    $defaultTambarHeight =
      Foswiki::Func::getPluginPreferencesValue("TAMBAR_HEIGHT") || 16;
    $defaultColors = Foswiki::Func::getPluginPreferencesValue("TAMBAR_COLORS")
      || "#FF0000 #FFCCCC #FFFF00 #FFFFCC #00FF00 #CCFFCC";

    # Get 'trend' default values
    $defaultTrendWidth = Foswiki::Func::getPluginPreferencesValue("TREND_WIDTH")
      || 16;
    $defaultTrendHeight =
      Foswiki::Func::getPluginPreferencesValue("TREND_HEIGHT") || 16;
}

# Return the maximum value of the two specified numbers.
sub _max {
    my ( $v1, $v2 ) = @_;
    return $v1 if ( $v1 > $v2 );
    return $v2;
}

# Return the minimum value of the two specified numbers.
sub _min {
    my ( $v1, $v2 ) = @_;
    return $v1 if ( $v1 < $v2 );
    return $v2;
}

# Convert a color in the form of either #RRGGBB or just RRGGBB (both in hex
# format) to a 3 element array of decimal numbers in the form
# (RED GREEN BLUE).
sub _convert_color {
    my ($hexcolor) = @_;
    my ( $red, $green, $blue );
    $hexcolor =~ /#(..)(..)(..)/;
    $red   = hex($1);
    $green = hex($2);
    $blue  = hex($3);
    return ( $red, $green, $blue );
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

# Generate the file name in which the graphic file will be placed.  Also
# make sure that the directory in which the graphic file will be placed
# exists.  If not, create it.
sub _make_filename {
    my ( $type, $name, $topic, $web ) = @_;

    # Generate the file name to be created
    my $fullname;

    # If GD version 1.19 or earlier, then create gif files else png files.
    if ( $GD::VERSION > 1.19 ) {
        $fullname = "_GaugePlugin_${type}_${name}.png";
    }
    else {
        $fullname = "_GaugePlugin_${type}_${name}.gif";
    }

    # before save, create directories if they don't exist.
    # If the top level "pub/$web" directory doesn't exist, create it.
    my $dir = Foswiki::Func::getPubDir() . "/$web";
    if ( !-e "$dir" ) {
        umask( oct(777) - $Foswiki::cfg{RCS}{dirPermission} );
        mkdir( $dir, 0775 );
    }

    # If the top level "pub/$web/$topic" directory doesn't exist, create
    # it.
    my $tempPath = "$dir/$topic";
    if ( !-e "$tempPath" ) {
        umask( oct(777) - $Foswiki::cfg{RCS}{dirPermission} );
        mkdir( $tempPath, 0775 );
    }

    # Return both the directory and the filename
    return ( $tempPath, $fullname );
}

# This routine returns an red colored error message.
sub _make_error {
    my ($msg) = @_;
    return "<span class='foswikiAlert'>GaugePlugin error: $msg</font>";
}

# This routine creates and returns a PNG (optionally GIF) containing an
# error message.
sub _make_error_image {
    my ( $msg, $dir, $filename, $width, $height, $parameters ) = @_;
    my $msglen = length($msg);

    # Get info on the font used in the message so we know how much space
    # will be required to hold the message.
    my $font        = GD::gdSmallFont();
    my $font_width  = $font->width;
    my $font_height = $font->height;

    # Calculate the minimum size of graphic to hold the error message
    $width = _max( $width, $font_width * ( $msglen + 2 ) );
    $height = _max( $height, $font_height + 2 );

    # Create the new image.
    my $im = new GD::Image( $width, $height );

    # Allocate colors needed in the graphic.
    my $white = $im->colorAllocate( 255, 255, 255 );    # white background
    my $black = $im->colorAllocate( 0,   0,   0 );      # black border
    my $red   = $im->colorAllocate( 255, 0,   0 );      # Red letters
                                                        # Make white background
    $im->filledRectangle( 0, 0, $width - 1, $height - 1, $white );

    # Write text error message into graphic (centered)
    $im->string(
        $font,
        ( $width - ( $font_width * length($msg) ) ) / 2,
        ( $height - $font_height ) / 2,
        $msg, $red
    );

    # Make the black border
    $im->rectangle( 0, 0, $width - 1, $height - 1, $black );

    # Write image file.
    umask( oct(777) - $Foswiki::cfg{RCS}{dirPermission} );
    open( IMAGE, ">$dir/$filename" )
      || return _make_error "Can't create '$dir/$filename': $!";
    binmode IMAGE;
    if ( $GD::VERSION > 1.19 ) {
        print IMAGE $im->png;
    }
    else {
        print IMAGE $im->gif;
    }
    close IMAGE;

    # Make a unique value to append to the image name that forces a web
    # browser to reload the image each time the image is viewed.  This is
    # done so value or scale changes are seen immediately and not ignored
    # because the browser has cached the image.  Eventually a hash value
    # should be used such that the user's browser CAN cache the image iff
    # none of the values used in creating the gauge have changed.
    my $timestamp = time();

    # Get remaining parameters and pass to <img ... />
    my $options = "";
    foreach my $k ( keys %$parameters ) {
        next if $k =~ /^_/;
        $options .= "$k=\"$$parameters{$k}\" ";
    }
    return "<img src=\"%ATTACHURL%/$filename?t=$timestamp\" alt=\"$msg\""
      . " width=\"$width\" height=\"$height\" $options />";
}

# Make a polygon that matches the gauge scale size.  Then scale the polygon
# to fit into the width/height of the actual image.
sub _make_poly_box {
    my ( $x1, $y1, $x2, $y2, $yoffset, $width, $left, $right ) = @_;

    # Clip the x values so they stay inside of gauge.
    $x1 = _max( $x1, $left );
    $x2 = _min( $x2, $right );
    my $xscale = ( $width / ( $right - $left ) );
    my $poly = new GD::Polygon;
    $poly->addPt( $x1, $y1 );
    $poly->addPt( $x2, $y1 );
    $poly->addPt( $x2, $y2 );
    $poly->addPt( $x1, $y2 );
    $poly->offset( -$left, $yoffset );
    $poly->scale( $xscale, 1, 0, 0 );
    my @b = $poly->bounds;
    return $poly;
}

# Make a gauge.  Determine the type so we know what to do.
sub _make_gauge {
    my ( $sesstion, $parameters, $topic, $web, $topicObject ) = @_;
    _init_defaults() if ( !$pluginInitialized );

    # If the GD module was found, then create an error image.
    if ($perlGDModuleFound) {
        my ($type) = _get_parameter( "type", $defaultType, $parameters );
        return _make_tambar_gauge( $topic, $web, $parameters )
          if ( $type eq "tambar" );
        return _make_trend_gauge( $topic, $web, $parameters )
          if ( $type eq "trend" );
        return _make_error("Unknown gauge type '$type'");
    }
    else {

        # It appears that the GD library wasn't found so we return a
        # different type of error that is just plain text.
        return _make_error("Required Perl module 'GD' not found");
    }
}

# Make a tambar gauge
sub _make_tambar_gauge {
    my ( $topic, $web, $parameters ) = @_;
    my ( $poly, $i, $scale );
    my ( $color_fg, $color_bg, $value_color_dark, $value_color_light );

    # Get the gauge colors (use defaults if not specified).
    my $tambar_colors = _get_parameter( "colors", $defaultColors, $parameters );
    my @tambar_colors = split( /[\s,]+/, $tambar_colors );

    # Get the tambar gauge scale values (use defaults of not specified).
    my $tambar_scale =
      _get_parameter( "scale", $defaultTambarScale, $parameters );
    my @tambar_scale = split( /[\s,]+/, $tambar_scale );

    # Get the left and right side values.  Needed to scale to the image
    # size.
    my $tambar_left  = $tambar_scale[0];
    my $tambar_right = $tambar_scale[ @tambar_scale - 1 ];

    # Check to see if this is a reverse gauge where the scale goes from
    # higher values down to lower values.  If so, then we need to do some
    # extra work to get this to display correctly.
    my $reverseGauge = 0; # 0 = scale lower to higher, 1 = scale higher to lower
    if ( $tambar_left > $tambar_right ) {
        $reverseGauge = 1;

        # Negate all scale values
        foreach my $s (@tambar_scale) {
            $s = -$s;
        }

        # Reset the left/right side of tambar
        $tambar_left  = -$tambar_left;
        $tambar_right = -$tambar_right;
    }

    # Get the tambar gauge width and height (different from scale used)
    my $tambar_width =
      _get_parameter( "width", $defaultTambarWidth, $parameters );
    my $tambar_height =
      _get_parameter( "height", $defaultTambarHeight, $parameters );

    # Compute the height of the scale portion of the gauge.  A minimum
    # value of 2, but is in general an 8th the size of the gauge value
    # part.
    my $tambar_scale_height = _max( 2, $tambar_height / 8 );

    # See if the parameter 'name' is available.  This is a required
    # parameter.  If it is missing, then generate an error message.
    my $name = _get_parameter( "name", undef, $parameters );
    return _make_error("parameter *name* must be specified")
      if ( !defined $name );

    # Generate the name of the graphic file that will be referenced
    my ( $dir, $filename ) = _make_filename( "tambar", $name, $topic, $web );

    # Get the gauge value.
    my $value = _get_parameter( "value", undef, $parameters );

# Get the gauge IMG 'alt' text.  If there is no value, then use 'value' as the default;
    my $alt = _get_parameter( "alt", $value, $parameters ) || "";

    # clean up numerical value
    $value =~ s/<[^>]+//g if ($value);
    if ( ( defined $value ) && ( $value =~ /^.*?([\+\-]?[0-9\.]+).*$/ ) ) {
        $value = $1;
    }
    else {

 # If there is no numerical value, then create an error graphic noting the error
        return _make_error_image( "no data", $dir, $filename, $tambar_width,
            $tambar_height, $parameters );
    }

    # If this is a reverse gauge, then negate the value (leaving 'alt' alone)
    $value = -$value if ($reverseGauge);

    # OK, we are ready to generate the tambar gauge.
    # Create an image with a width = the last value specified in
    # tambar_scale.
    my $im = new GD::Image( $tambar_width, $tambar_height );

    # Allocate some colors used by the image.
    my $white = $im->colorAllocate( 255, 255, 255 );
    my $black = $im->colorAllocate( 0,   0,   0 );

    # Make white the transparent color
    $im->transparent($white);

    undef $value_color_dark;
    undef $value_color_light;

    # Draw the scale for the bar gauge
    for $i ( 1 .. @tambar_scale - 1 ) {

        # Obtain the colors for the dark and light versions of each color.
        $color_fg = $im->colorAllocate(
            _convert_color( $tambar_colors[ ( $i - 1 ) * 2 ] ) );
        $color_bg = $im->colorAllocate(
            _convert_color( $tambar_colors[ ( $i - 1 ) * 2 + 1 ] ) );

        # Make a polygon that is initially in scale specified by the user
        # but then is remapped to fit inside the actual graphic size.
        $poly = _make_poly_box(
            $tambar_scale[ $i - 1 ],                   0,
            $tambar_scale[$i],                         $tambar_scale_height,
            $tambar_height - $tambar_scale_height - 2, $tambar_width,
            $tambar_left,                              $tambar_right
        );
        $im->filledPolygon( $poly, $color_fg );

        # Determine the dark/light color to be used to represent the actual
        # value of the gauge.
        if ( ( $value <= $tambar_scale[$i] ) && !defined $value_color_dark ) {
            $value_color_dark  = $color_fg;
            $value_color_light = $color_bg;
        }
    }

    # If not defined, then the value is greater than the max of the scale
    # so use the last colors seen
    if ( !defined $value_color_dark ) {
        $value_color_dark  = $color_fg;
        $value_color_light = $color_bg;
    }

    # Compute a 'value' to display.  If 'value' < min gauge value, then
    # force the 'value' to a value inside of the scale such that when
    # displayed, there is at least 1 pixels worth of dark color.  The
    # amount to add to value is calculated as a percentage since the amount
    # to add will vary depending on how width the scale actually is
    # compared to the actual width (in pixels) of the image.
    my $values_per_pixel = ( $tambar_right - $tambar_left ) / $tambar_width;
    my $v =
      _max( $value, $tambar_left + POSIX::ceil( $values_per_pixel + 0.5 ) );

    # Draw the gauge value
    $poly =
      _make_poly_box( $tambar_left, 0, $v,
        $tambar_height - $tambar_scale_height - 2,
        0, $tambar_width, $tambar_left, $tambar_right );
    $im->filledPolygon( $poly, $value_color_dark );

    # Fill out a lighter color from the gauge value to the end of the
    # gauge.
    $poly =
      _make_poly_box( $v, 0, $tambar_right,
        $tambar_height - $tambar_scale_height - 2,
        0, $tambar_width, $tambar_left, $tambar_right );
    $im->filledPolygon( $poly, $value_color_light );

    # Draw a black line at the gauge value.  Use the poly routine since it
    # does the scaling automatically for us.
    $poly =
      _make_poly_box( $v, 0, $v, $tambar_height - $tambar_scale_height - 2,
        0, $tambar_width, $tambar_left, $tambar_right );
    $im->filledPolygon( $poly, $black );

    # Draw the black line separating the gauge value from the gauge scale.
    my $line_y = $tambar_height - $tambar_scale_height - 2;
    $im->line( 0, $line_y, $tambar_width, $line_y, $black );

    # Draw a black border around the entire gauge.
    $im->rectangle( 0, 0, $tambar_width - 1, $tambar_height - 1, $black );

    # Create the file.
    Foswiki::Func::writeDebug("$pluginName: creating image at $dir/$filename")
      if $debug;
    umask( oct(777) - $Foswiki::cfg{RCS}{dirPermission} );
    open( IMAGE, ">", "$dir/$filename" )
      || return _make_error "Can't create '$dir/$filename': $!";
    binmode IMAGE;
    if ( $GD::VERSION > 1.19 ) {
        print IMAGE $im->png;
    }
    else {
        print IMAGE $im->gif;
    }
    close IMAGE;
    Foswiki::Func::writeDebug("$pluginName: image created OK")
      if $debug;

    # Make a unique value to append to the image name that forces a web
    # browser to reload the image each time the image is viewed.  This is
    # done so value or scale changes are seen immediately and not ignored
    # because the browser has cached the image.  Eventually a hash value
    # should be used such that the user's browser CAN cache the image iff
    # none of the values used in creating the gauge have changed.
    my $timestamp = time();

    # Get remaining parameters and pass to <img ... />
    my $options = "";
    foreach my $k ( keys %$parameters ) {
        next if $k =~ /^_/;
        $options .= "$k=\"$$parameters{$k}\" ";
    }
    return "<img src=\"%ATTACHURL%/$filename?t=$timestamp\" alt=\"$alt\""
      . " width=\"$tambar_width\" height=\"$tambar_height\" $options />";
}

# Make a trend gauge (an arrow)
sub _make_trend_gauge {
    my ( $topic, $web, $parameters ) = @_;
    my ( $poly, $i, $scale );
    my ( $color_fg, $color_bg, $value_color_dark, $value_color_light );

    # Get the trend gauge width and height (different from scale used)
    my $trend_width =
      _get_parameter( "width", $defaultTrendWidth, $parameters );
    my $trend_height =
      _get_parameter( "height", $defaultTrendHeight, $parameters );

# Get the trend value.  If there is no value, then create an error graphic noting the error
    my $filename;
    my $value = _get_parameter( "value", undef, $parameters );

# Get the gauge IMG 'alt' text.  If there is no value, then use 'value' as the default
    my $alt = _get_parameter( "alt", $value, $parameters ) || "";

    # clean up numerical value
    $value =~ s/<[^>]+//g if ($value);
    if ( ( defined $value ) && ( $value =~ /^.*?([\+\-]?[0-9\.]+).*$/ ) ) {
        $value = $1;

        # OK, we are ready to generate the trend gauge.  This is simple since
        # the graphics are assumed to already exist so we just figure out which
        # one to display and then display it.
        $filename = "trenddn.gif" if ( $value < 0 );
        $filename = "trendeq.gif" if ( $value == 0 );
        $filename = "trendup.gif" if ( $value > 0 );

    }
    else {

        # show the "no data" gif
        $filename = "trendnd.gif";
        $alt = "no data" unless ($alt);
    }

    # Get remaining parameters and pass to <img ... />
    my $options = "";
    foreach my $k ( keys %$parameters ) {
        next if $k =~ /^_/;
        $options .= "$k=\"$$parameters{$k}\" ";
    }
    my $timestamp = time();
    return
        "<img src=\"%PUBURL%/%SYSTEMWEB%/GaugePlugin/$filename?t=$timestamp\""
      . " width=\"$trend_width\" height=\"$trend_height\" alt=\"$alt\" $options />";
}

1;
