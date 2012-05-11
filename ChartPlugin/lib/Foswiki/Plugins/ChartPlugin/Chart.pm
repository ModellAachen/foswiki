# ChartPlugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004-2006 Peter Thoeny, Peter@Thoeny.org
# Plugin written by http://TWiki.org/cgi-bin/view/Main/TaitCyrus
# Copyright (C) 2008,2010 Foswiki Contributors
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
# This file contains routines for creating charts for the ChartPlugin
#
# Access is via object oriented Perl and is as follows.
#
# Constructor:
#    new()                - Create a 'chart' object an initial various default values.
# Getters/Setters
#    setType($type)        - Set the type of chart (line, area, or combo)
#    getType                - Return the chart type
#
#    setTitle($title)        - Set the chart title (top of chart) - default is none
#    getTitle                - Get the chart title
#
#    setXlabel(@labels)        - Set the label under the X axis - default is none
#    getXlabel                - Get the X label
#
#    setYlabel($flag)        - Set the label under the Y axis - default is none
#    getYlabel                - Get the Y label
#
#    setData(@data)        - Set the the data (array) to chart
#    getData                - Get the data (array)
#    getNumDataSets        - Get the number of data sets found in the data.
#    getNumDataPoints        - Get the number of data points in a data set
#
#    setYmin($min)        - Set the minimum Y value to display on the chart
#    getYmin                - Get the minimum Y value.  If no user specified
#                              value via setYmin(), then return the minimum
#                              value actually seen in the data sets
#
#    setYmax($max)        - Set the maximum Y value to display on the chart
#    getYmax                - Get the maximum Y value.  If no user specified
#                              value via setYmax(), then return the maximum
#                              value actually seen in the data sets
#
#    setSubTypes(@types)- Set array describing the subtypes for each data set.
#                              Values can be area or line and corresponds to the
#                              associated data set.
#    getSubTypes        - Get the array of subtypes
#
#    setXaxis(@xaxis)        - Set the array of X axis values
#    getXaxis                - Get the array of X axis values
#
#    setXaxisAngle($angle)
#                       - Set the angle of the X axis labels
#    getXaxisAngle         - Get the angle of the X axis labels
#
#    setYaxis(@yaxis)        - Set Y axis draw flag ("on" or "off")
#    getYaxis                - Get the value of the Y axis draw flag
#
#    setNumYGrids($num)        - Set the number of Y axes to draw
#    getNumYGrids        - Get the number of Y axes to draw
#
#    setNumYTics($num)        - Set the number of tic marks to draw between Y grids
#    getNumYTics        - Get the number of tic marks to draw between Y grids
#
#    setNumXGrids($num) - Set the number of X axis to draw
#    getNumXGrids        - Get the number of X axis to draw
#
#    setXgrid($type)        - Set the type of X grid to draw (off, on, or dot)
#    getXgrid                - Get the type of X grid to draw
#
#    setYgrid($type)        - Set the type of Y grid to draw (off, on, or dot)
#    getYgrid                - Get the type of Y grid to draw
#
#    setScale($scale)        - Set the type of Y scale to use (linear or log)
#    getScale                - Get the type of Y scale to use
#
#    setDataLabels(@lbls)- Set array describing whether to draw data labels
#                              for each data point or not.  Each element
#                              corresponds to the associated data set.
#    getDataLabels        - Get array of data label specifications per data set
#
#    setLegend(@legend)        - Set array of legends (descriptions) for each data set
#    getLegend                - Get array of data set legends (descriptions)
#
#    setImageWidth($w)        - Set width (in pixels) of the resulting chart image
#    getImageWidth        - Get width (in pixels) of the chart image
#
#    setImageHeight($h)        - Set height (in pixels) of the resulting chart image
#    getImageHeight        - Get height (in pixels) of the chart image
#
#    setAreaColors(@c)        - Set array of colors to be used when drawing areas
#    getAreaColors        - Get array of area colors
#    getAreaColorByIndex- Get the next area color by indexing into color array
#
#    setLineColors(@c)        - Set array of colors to be used when drawing lines
#    getLineColors        - Get array of line colors
#    getLineColorByIndex- Get the next line color by indexing into color array
#
#    setColors(@c)        - Set array of colors to be used by each data set.
#    getColors                - Get array of colors
#
#    setAttachmentName($web, $topic, $name)        - Set the name of the chart file
#
#    setMargin($margin)        - Set the margin (in pixels) allocated around the
#                              entire chart.
#    getMargin                - Get the margin size
#
#    setImage($im)        - Set the GD image info
#    getImage                - Get the GD image info
#
#    setFont($type,$font)- Set the font for 'type' types of data
#    getFont($type)        - Get the font for 'type' of data
#    getFontWidth($type)- Get the font width for 'type' of data
#    getFontHeight($type)- Get the font height for 'type' of data
#    setBGcolor(@color)        - Set the background color of the chart
#    getBGcolor()        - Get the background color of the chart
#    setGridColor($color)- Set the color of the grid
#    getGridColor()        - Get the color of the grid
#
#    computeFinalColors        - Computes the final colors to be used by each data
#                              set taking colors from either the user specified
#                              colors or from the 'area' and 'line' color
#                              defaults based on the type of each data set
#    computeSubTypes        - Compute the subtype for each data set based on
#                              'type' and 'subType' specified.
#    setDefaultDataValue($value)
#                       - Set a default value if there is no data seen in
#                         the table.
#    getDefaultDataValue()
#                       - Get the default value to use if there is no data
#                         seen in the table
#    setPointSize($size)- Set the size in pixels of a drawn data point
#    getPointSize()        - Get the size in pixels of drawn data points
#    setLineWidth($width)- Set the width, in pixels, lines are drawn with
#    getLineWidth()        - Get the width of drawn lines
#
#    setBarLeadingSpace($pixels)
#                            - Set the leading space (in pixels) before the first drawn bar graph
#    getBarLeadingSpace()
#                            - Get the space before the first drawn bar graph
#    setBarTrailingSpace($pixels)
#                            - Set the trailing space (in pixels) after the last drawn bar graph
#    getBarTrailingSpace()
#                            - Get the space before the last drawn bar graph
#    setBarSpace($pixels)
#                            - Set the space (in pixels) between bar graphs
#    getBarSpace()
#                            - Get the space between bar graphs

# =========================
package Foswiki::Plugins::ChartPlugin::Chart;

use Exporter;
use GD;

# http://foswiki.org/Tasks/Item1322 - prevent taint issue with certain combinations of perl/gd/cpan
gdBrushed;
gdDashSize;
gdMaxColors;
gdStyled;
gdStyledBrushed;
gdTiled;
gdTransparent;
gdAntiAliased;
gdArc;
gdChord;
gdPie;
gdNoFill;
gdEdged;
gdTinyFont;
gdSmallFont;
gdMediumBoldFont;
gdLargeFont;
gdGiantFont;
gdAlphaMax;
gdAlphaOpaque;
gdAlphaTransparent;
use POSIX;
@ISA    = ();
@EXPORT = qw(
  setType getType
  setTitle getTitle
  setXlabel getXlabel
  setYlabel getYlabel
  setData getData getNumDataSets
  setYmin getYmin
  setYmax getYmax
  setSubTypes getSubTypes
  setXaxis getXaxis
  setXaxisAngle getXaxisAngle
  setNumXGrids getNumXGrids
  setYaxis getYaxis
  setNumYGrids getNumYGrids
  setNumYTics getNumYTics
  setXgrid getXgrid
  setYgrid getYgrid
  setScale getScale
  setDataLabels getDataLabels
  setLegend getLegend
  setImageWidth getImageWidth
  setImageHeight getImageHeight
  setAreaColors getAreaColors
  setLineColors getLineColors
  setColors getColors
  setGridColor getGridColor
  setAttachmentName
  setMargin getMargin
  setPointSize getPointSize
  setLineWidth getLineWidth
  setBarLeadingSpace getBarLeadingSpace
  setBarTrailingSpace getBarTrailingSpace
  setBarSpace getBarSpace
);

use strict;

sub new {
    my ($class) = @_;
    my $this = {};
    bless $this, $class;
    $this->setMargin(10);
    $this->setColors();
    $this->setGridColor("#FFFFFF");
    $this->setLegend();
    $this->setYaxis("off");
    $this->setXaxis();
    $this->setXaxisAngle(0);
    $this->setNumXGrids(10);
    $this->setSubTypes();
    $this->setFont( "title",  GD::gdGiantFont() );    # Set title font
    $this->setFont( "xaxis",  GD::gdSmallFont() );    # Set X axis font
    $this->setFont( "yaxis",  GD::gdSmallFont() );    # Set Y axis font
    $this->setFont( "xlabel", GD::gdSmallFont() );    # Set X label font
    $this->setFont( "ylabel", GD::gdSmallFont() );    # Set Y label font
    $this->setFont( "legend", GD::gdSmallFont() );    # Set legend font
    $this->setFont( "data",   GD::gdSmallFont() );    # Set data values font
    $this->setNumYGrids(10);
    $this->setNumYTics(-1);
    $this->setScale("linear");
    $this->setNumYDigits(0);
    $this->setNumXDigits(0);
    return $this;
}

sub setType { my ( $this, $type ) = @_; $$this{TYPE} = $type; }
sub getType { my ($this) = @_; return $$this{TYPE}; }

sub setTitle { my ( $this, $title ) = @_; $$this{TITLE} = $title; }
sub getTitle { my ($this) = @_; return $$this{TITLE}; }

sub setXlabel { my ( $this, $Xlabel ) = @_; $$this{X_LABEL} = $Xlabel; }
sub getXlabel { my ($this) = @_; return $$this{X_LABEL}; }

sub setYlabel { my ( $this, $Ylabel ) = @_; $$this{Y_LABEL} = $Ylabel; }
sub getYlabel { my ($this) = @_; return $$this{Y_LABEL}; }

sub setDefaultDataValue {
    my ( $this, $defaultValue ) = @_;
    $$this{DEFAULT_VALUE} = $defaultValue;
}
sub getDefaultDataValue { my ($this) = @_; return $$this{DEFAULT_VALUE}; }

# Return the minimum data value seen so the caller can decide if special
# action is needed (as would be the case if scale=semilog and yMin <= 0
sub setData {
    my ( $this, @data ) = @_;

    # Create clean data values and calculate the min/max values to be charted.
    my $yMin   = 9e+40;       # Initialize with some very large value.
    my $yMax   = -9e+40;      # Initialize with some very small value.
    my $value  = 0;
    my $maxRow = @data - 1;
    my $maxCol = 0;
    my $defaultDataValue = $this->getDefaultDataValue();
    for my $r ( 0 .. $maxRow ) {
        $maxCol = @{ $data[$r] } - 1;
        for my $c ( 0 .. $maxCol ) {
            $value = $data[$r][$c];

            # Check to see if the value is non-empty.
            if ( $value !~ /^\s*$/ ) {

                # If there is a non-empty value, then look for the number part
                if ( $value =~ m/([\-]?[0-9.]+[eE]?[+-]?\d*)/ ) {
                    $value = $1;
                }
                else {

                    # If a non-number value in a column (like text for a
                    # column header) assume the user defined default data
                    # value
                    $value = $defaultDataValue;
                }
            }
            else {

                # Value is empty to use the user defined default value
                $value = $defaultDataValue;
            }
            $data[$r][$c] = $value;

            # Since we allow a default value which can be empty, we only
            # want to calculate min/max if the current value is a number.
            if ( $value =~ m/([\-]?[0-9.]+[eE]?[+-]?\d*)/ ) {
                $yMin = $1 if ( $1 < $yMin );
                $yMax = $1 if ( $1 > $yMax );
            }
        }
    }

    # Save the min/max data set values.
    $this->setYminOfData($yMin);
    $this->setYmaxOfData($yMax);

    $$this{DATA}            = \@data;
    $$this{NUM_DATA_SETS}   = @data;
    $$this{NUM_DATA_POINTS} = @{ $data[0] };
    return $yMin;
}
sub getData          { my ($this) = @_; return @{ $$this{DATA} }; }
sub getNumDataSets   { my ($this) = @_; return $$this{NUM_DATA_SETS}; }
sub getNumDataPoints { my ($this) = @_; return $$this{NUM_DATA_POINTS}; }

sub getXminOfData { my ($this) = @_; return $$this{X_DATA_MIN}; }
sub setXminOfData { my ( $this, $xmin ) = @_; $$this{X_DATA_MIN} = $xmin; }

sub setXmaxOfData { my ( $this, $xmax ) = @_; $$this{X_DATA_MAX} = $xmax; }
sub getXmaxOfData { my ($this) = @_; return $$this{X_DATA_MAX}; }

sub setYmin { my ( $this, $yMin ) = @_; $$this{Y_MIN} = $yMin; }
sub getYmin { my ($this) = @_; return $$this{Y_MIN}; }

sub getYminOfData { my ($this) = @_; return $$this{Y_DATA_MIN}; }
sub setYminOfData { my ( $this, $ymin ) = @_; $$this{Y_DATA_MIN} = $ymin; }

sub setYmax { my ( $this, $yMax ) = @_; $$this{Y_MAX} = $yMax; }
sub getYmax { my ($this) = @_; return $$this{Y_MAX}; }
sub setYmaxOfData { my ( $this, $ymax ) = @_; $$this{Y_DATA_MAX} = $ymax; }
sub getYmaxOfData { my ($this) = @_; return $$this{Y_DATA_MAX}; }

sub setSubTypes {
    my ( $this, @subTypes ) = @_;
    $$this{SUB_TYPES} = \@subTypes;
}
sub getSubTypes { my ($this) = @_; return @{ $$this{SUB_TYPES} }; }

sub setXaxis { my ( $this, @xAxis ) = @_; $$this{X_AXIS} = \@xAxis; }
sub getXaxis { my ($this) = @_; return @{ $$this{X_AXIS} }; }

sub setXaxisAngle { my ( $this, $angle ) = @_; $$this{X_AXIS_ANGLE} = $angle; }
sub getXaxisAngle { my ($this) = @_; return $$this{X_AXIS_ANGLE}; }

sub setYaxis { my ( $this, $yAxis ) = @_; $$this{Y_AXIS} = $yAxis; }
sub getYaxis { my ($this) = @_; return $$this{Y_AXIS}; }

sub setNumYGrids {
    my ( $this, $numYGrids ) = @_;
    $$this{NUM_Y_GRIDS} = $numYGrids;
}
sub getNumYGrids { my ($this) = @_; return $$this{NUM_Y_GRIDS}; }

sub setNumYTics {
    my ( $this, $numYTics ) = @_;
    $$this{NUM_Y_TICS} = $numYTics;
}
sub getNumYTics { my ($this) = @_; return $$this{NUM_Y_TICS}; }

sub setNumXGrids {
    my ( $this, $numXGrids ) = @_;
    $$this{NUM_X_GRIDS} = $numXGrids;
}
sub getNumXGrids { my ($this) = @_; return $$this{NUM_X_GRIDS}; }

sub setXgrid { my ( $this, $xGrid ) = @_; $$this{X_GRID} = $xGrid; }
sub getXgrid { my ($this) = @_; return $$this{X_GRID}; }

sub setYgrid { my ( $this, $yGrid ) = @_; $$this{Y_GRID} = $yGrid; }
sub getYgrid { my ($this) = @_; return $$this{Y_GRID}; }

sub setScale { my ( $this, $scale ) = @_; $$this{SCALE} = $scale; }
sub getScale { my ($this) = @_; return $$this{SCALE}; }

sub setDataLabels {
    my ( $this, @dataLabels ) = @_;
    $$this{DATA_LABELS} = \@dataLabels;
}
sub getDataLabels { my ($this) = @_; return @{ $$this{DATA_LABELS} }; }

sub setLegend { my ( $this, @legend ) = @_; $$this{LEGEND} = \@legend; }
sub getLegend { my ($this) = @_; return @{ $$this{LEGEND} }; }

sub setImageWidth {
    my ( $this, $imageWidth ) = @_;
    $$this{IMAGE_WIDTH} = _getInt($imageWidth);
}
sub getImageWidth { my ($this) = @_; return $$this{IMAGE_WIDTH}; }

sub setImageHeight {
    my ( $this, $imageHeight ) = @_;
    $$this{IMAGE_HEIGHT} = _getInt($imageHeight);
}
sub getImageHeight { my ($this) = @_; return $$this{IMAGE_HEIGHT}; }

# Return first integer number found in a string
sub _getInt {
    my ($str) = @_;
    $str = '0' unless ($str);
    if ( $str =~ s/^.*?(\-?)0*([0-9]+).*$/$1$2/o ) {
        return int($str);
    }
    return 0;
}

sub setAreaColors {
    my ( $this, @AreaColors ) = @_;
    $$this{AREA_COLORS}     = \@AreaColors;
    $$this{NEXT_AREA_COLOR} = 0;
}
sub getAreaColors { my ($this) = @_; return @{ $$this{AREA_COLORS} }; }

sub getAreaColorByIndex {
    my ( $this, $index ) = @_;
    my @colors    = $this->getAreaColors();
    my $nextColor = $colors[ $index % @colors ];
    return $nextColor;
}

sub setLineColors {
    my ( $this, @LineColors ) = @_;
    $$this{LINE_COLORS}     = \@LineColors;
    $$this{NEXT_LINE_COLOR} = 0;
}
sub getLineColors { my ($this) = @_; return @{ $$this{LINE_COLORS} }; }

sub getLineColorByIndex {
    my ( $this, $index ) = @_;
    my @colors    = $this->getLineColors();
    my $nextColor = $colors[ $index % @colors ];
    return $nextColor;
}

sub setColors { my ( $this, @Colors ) = @_; $$this{COLORS} = \@Colors; }
sub getColors { my ($this) = @_; return @{ $$this{COLORS} }; }

sub setGridColor {
    my ( $this, @gridColor ) = @_;
    $$this{GRID_COLOR} = \@gridColor;
}
sub getGridColor { my ($this) = @_; return @{ $$this{GRID_COLOR} }; }

sub setAttachmentName {
    my ( $this, $web, $topic, $name ) = @_;
    $this->{WEB}       = $web;
    $this->{TOPIC}     = $topic;
    $this->{FILE_NAME} = $name;
}

sub setMargin { my ( $this, $margin ) = @_; $$this{MARGIN} = $margin; }
sub getMargin { my ($this) = @_; return $$this{MARGIN}; }

sub setImage { my ( $this, $image ) = @_; $$this{IMAGE} = $image; }
sub getImage { my ($this) = @_; return $$this{IMAGE}; }

sub setFont {
    my ( $this, $type, $font ) = @_;
    $$this{"FONT_$type"}        = $font;
    $$this{"FONT_WIDTH_$type"}  = $font->width;
    $$this{"FONT_HEIGHT_$type"} = $font->height;
}
sub getFont { my ( $this, $type ) = @_; return $$this{"FONT_$type"}; }

sub getFontWidth {
    my ( $this, $type ) = @_;
    return $$this{"FONT_WIDTH_$type"};
}

sub getFontHeight {
    my ( $this, $type ) = @_;
    return $$this{"FONT_HEIGHT_$type"};
}

sub setBGcolor { my ( $this, @bgcolor ) = @_; $$this{BGCOLOR} = \@bgcolor; }
sub getBGcolor { my ($this) = @_; return @{ $$this{BGCOLOR} }; }

sub setNumYDigits {
    my ( $this, $numDigits ) = @_;
    $$this{NUM_Y_DIGITS} = $numDigits;
}
sub getNumYDigits { my ($this) = @_; return $$this{NUM_Y_DIGITS}; }

sub setNumXDigits {
    my ( $this, $numDigits ) = @_;
    $$this{NUM_X_DIGITS} = $numDigits;
}
sub getNumXDigits { my ($this) = @_; return $$this{NUM_X_DIGITS}; }

sub setPointSize { my ( $this, $pixels ) = @_; $$this{POINT_SIZE} = $pixels; }
sub getPointSize { my ($this) = @_; return $$this{POINT_SIZE}; }
sub setLineWidth { my ( $this, $pixels ) = @_; $$this{LINE_WIDTH} = $pixels; }
sub getLineWidth { my ($this) = @_; return $$this{LINE_WIDTH}; }

sub setBarLeadingSpace {
    my ( $this, $pixels ) = @_;
    $$this{BAR_LEADING_SPACE} = $pixels;
}
sub getBarLeadingSpace { my ($this) = @_; return $$this{BAR_LEADING_SPACE}; }

sub setBarTrailingSpace {
    my ( $this, $pixels ) = @_;
    $$this{BAR_TRAILING_SPACE} = $pixels;
}
sub getBarTrailingSpace { my ($this) = @_; return $$this{BAR_TRAILING_SPACE}; }
sub setBarSpace { my ( $this, $pixels ) = @_; $$this{BAR_SPACE} = $pixels; }
sub getBarSpace { my ($this) = @_; return $$this{BAR_SPACE}; }

sub computeFinalColors {
    my ($this)      = @_;
    my $numDataSets = $this->getNumDataSets();
    my @subTypes    = $this->getSubTypes();
    my $im          = $this->getImage();

    # Calculate the colors that will be needed.
    # If 'type' = line or area then call getColors().  If no colors
    # defined, then default to getLineColors() for lines and
    # getAreaColors() for areas.
    # If 'type' = combo, then get colors via getColors().  If no colors
    # defined, then call getDataType() to determine if the data sets are
    # specified as lines or areas and get the next available color from
    # getLineColors() and/or getAreaColors().
    my @colors     = $this->getColors();
    my @lineColors = $this->getLineColors();
    my @areaColors = $this->getAreaColors();
    my @chartColors = ();    # Actual colors used for each line/area
    if (@colors) {

        # User defined colors.  Reuse colors if there are more data sets
        # than colors.
        my $numColors = @colors;
        for ( 1 .. POSIX::ceil( $numDataSets / $numColors ) ) {
            push( @chartColors, @colors );
        }
    }
    else {

        # No user defined colors so use the defaults.  This can be a bit
        # tricky since depending on what 'type' the data is will determine
        # where we get the next color.
        my $index = 0;
        for my $subType (@subTypes) {
            my $color;
            if ( $subType =~ /(area|bar)/ ) {
                $color = $this->getAreaColorByIndex($index);
            }
            else {
                $color = $this->getLineColorByIndex($index);
            }
            push( @chartColors, $color );
            $index++;
        }
    }

    # Walk through each color and allocate it in the GD.
    my @allocatedColors;
    for my $color (@chartColors) {
        push( @allocatedColors, $im->colorAllocate( _convert_color($color) ) );
    }
    return @allocatedColors;
}

# Calculate the 'types' for each of the data sets.  If getType() is 'area',
# then artificially fill in subTypes for each data set to match that type.
# If type is 'combo', then subTypes should have been specified by the user.
# If not, then assume that all but the last data set are 'area' and the
# last is 'line'.
sub computeSubTypes {
    my ($this)      = @_;
    my $numDataSets = $this->getNumDataSets();
    my $type        = $this->getType();
    my @subTypes    = ();

    # Deal with types that don't allow subtypes.  In this case force all
    # subtypes to be the same as the type.
    if ( ( $type eq "area" ) || ( $type eq "bar" ) ) {
        for ( 1 .. $numDataSets ) {
            push( @subTypes, $type );
        }
        $this->setSubTypes(@subTypes);
    }
    else {

        # If a user specified subtype, then reuse user's info over and
        # over again if there are more data sets than subtypes specified.
        # If no subtype, then assume all but the last data set are 'area'
        # and the last 'line'.
        my @userSubTypes = $this->getSubTypes();
        if (@userSubTypes) {
            my $numUserSubTypes = @userSubTypes;
            for ( 1 .. POSIX::ceil( $numDataSets / $numUserSubTypes ) ) {
                push( @subTypes, @userSubTypes );
            }
        }
        else {

            # If no 'subtype' specified and type is 'combo' or 'scatter',
            # assume all 'area' except the last which is 'line', otherwise
            # assume a subtype of 'line' for type 'line'.
            if ( $type eq "line" ) {
                for my $y ( 1 .. $numDataSets ) {
                    push( @subTypes, "line" );
                }
            }
            elsif ( $type eq "scatter" ) {
                for my $y ( 1 .. $numDataSets ) {
                    push( @subTypes, "point" );
                }
            }
            else {
                for my $y ( 1 .. $numDataSets - 1 ) {
                    push( @subTypes, "area" );
                }
                push( @subTypes, "line" );
            }
        }
    }

    # Set the subTypes since they will have changed and other calculations
    # need this information.
    $this->setSubTypes(@subTypes);
    return @subTypes;
}

# The main guts of this file.  This routine takes all the information
# specified in the Chart object and constructs a chart based on all of the
# information contained in the object.
sub makeChart {
    my ($this)      = @_;
    my $imageWidth  = $this->getImageWidth();
    my $imageHeight = $this->getImageHeight();

    # Create empty image to get filled in later.
    my $im = new GD::Image( $imageWidth, $imageHeight );
    $this->setImage($im);

    # Define some commonly used colors
    my $defaultBGcolorText = "ffffff";
    my $defaultBGcolor =
      $im->colorAllocate( _convert_color($defaultBGcolorText) );
    my $black = $im->colorAllocate( 0, 0, 0 );    # black

    # Create the background color.  If not defined, default to white, else
    # use the user specified value.
    my @bgcolor = $this->getBGcolor();

    # Start with a totally white background
    $im->filledRectangle(
        0, 0,
        $imageWidth - 1,
        $imageHeight - 1,
        $defaultBGcolor
    );

    # Calculate the 'types' for each of the data sets.
    my @subTypes = $this->computeSubTypes();

    # Count how many of the data sets are 'bar'
    my $numBarDataSets = grep( /bar/, @subTypes );

    my $type = $this->getType;

    # If a scatter chart, then set the following flag
    my $scatterChart;
    $scatterChart = 1 if ( $type eq "scatter" );

    # Get the number of pixels width/height of drawn data points.
    my $pointSize     = $this->getPointSize;
    my $pointSizeHalf = $pointSize / 2;

    # Get the number of pixels width lines are to be drawn with
    my $lineWidth = $this->getLineWidth;

    # Get the Y axis scale to use
    my $scale = $this->getScale();

    # Get the data and info about the data.
    my @data          = $this->getData();
    my $numDataSets   = $this->getNumDataSets();
    my $numDataPoints = $this->getNumDataPoints();
    return "Error: Number of data points needs to be > 1"
      if ( $numDataPoints <= 1 );

    # Calculate the colors that will be needed for the various lines and
    # areas figuring out which color is needed when and also dealing with
    # color reuse (more data sets than colors specified).
    my @allocatedColors = $this->computeFinalColors();

    # Allocate the grid color(s) and define a line style for the grid for
    # grids defined as 'dot'.  For grids defined as 'on', then just use the
    # first color defined
    my $firstColor = undef;
    my %gridColors;

    # Get unique list of colors.
    foreach my $color ( $this->getGridColor() ) {
        $firstColor = $color if ( !defined $firstColor );
        $gridColors{$color} = 1;
    }

    # Allocate color for each unique grid color
    for my $color ( keys %gridColors ) {
        next if ( $color eq "transparent" );
        $gridColors{$color} = $im->colorAllocate( _convert_color($color) );
    }
    my @gridColors;

    # Now define array of colors for grid
    foreach my $color ( $this->getGridColor() ) {
        if ( $color eq "transparent" ) {
            push( @gridColors, gdTransparent );
        }
        else {
            push( @gridColors, $gridColors{$color} );
        }
    }
    $im->setStyle(@gridColors);

    # Get the first color for solid grid lines
    my $gridColor = $gridColors{$firstColor};

    # Calculate the initial pixel locations of lower left side (xLL/yLL)
    # and upper right side (xUR/yUR) of the chart with respect to the
    # graphic image.  Depending on X/Y labels, titles, legends, etc. this
    # will change in the code below.
    my $margin = $this->getMargin();
    my $xLL    = $margin;
    my $yLL    = $imageHeight - 1 - $margin;
    my $xUR    = $imageWidth - 1 - $margin;
    my $yUR    = $margin;

    # Calculate how much space will be needed for the Y label (if specified).
    my $yLabel = $this->getYlabel();
    if ( defined $yLabel ) {

        # Add space for the label as well as some space between the label
        # and the Y Axis labels or the left side of the chart.
        $xLL += $this->getFontHeight("ylabel") + 10;
    }

    # Get various bits of info concerning the chart.
    my $yAxisMin           = $this->getYmin();
    my $yAxisMax           = $this->getYmax();
    my $yAxisDecimalDigits = 0;

    # If the user has not specified either of ymin or ymax, then compute
    # some reasonable values based on the min/max of the actual data
    # itself.  Also compute the number of significant digits in the numbers
    # to aid in knowing how to format the numbers when printing as well as
    # the new number of Y grids.
    my $numYGrids = $this->getNumYGrids();
    if ( !defined($yAxisMin) && !defined($yAxisMax) ) {
        if ( $scale eq "semilog" ) {
            $this->computeYMinMaxLog();
        }
        else {
            my ( $newYmin, $newYmax, $newNumYGrids, $newNumYDecimalDigits ) =
              $this->computeLinearMinMax( $this->getYminOfData(),
                $this->getYmaxOfData(), $numYGrids );
            $this->setYminOfData($newYmin);
            $this->setYmaxOfData($newYmax);
            $this->setNumYGrids( $numYGrids = $newNumYGrids );
            $this->setNumYDigits($newNumYDecimalDigits);
        }
    }
    else {

        # At least one of ymin or ymax specified by the user.
        # If scale=semilog, we still auto compute min/max while if
        # scale=linear we use the users set values.
        if ( $scale eq "semilog" ) {
            $this->setYminOfData($yAxisMin) if ( defined $yAxisMin );
            $this->setYmaxOfData($yAxisMax) if ( defined $yAxisMax );
            $this->computeYMinMaxLog();
            undef $yAxisMin;    # Force re-read below
            undef $yAxisMax;
        }
        else {

            # Compute the number of digits to use when displaying the Y axis
            # labels.
            my $ymin = $this->getYmin();
            my $ymax = $this->getYmax();
            $ymin = $this->getYminOfData() if ( !defined($ymin) );
            $ymax = $this->getYmaxOfData() if ( !defined($ymax) );
            my $maxDigits = $this->computeNumDigits( $ymin, $ymax, $numYGrids );
            $this->setNumYDigits($maxDigits);
        }
    }
    $yAxisMin = $this->getYminOfData() if ( !defined($yAxisMin) );
    $yAxisMax = $this->getYmaxOfData() if ( !defined($yAxisMax) );
    my $scaledYAxisMin = $this->_scale($yAxisMin);
    my $scaledYAxisMax = $this->_scale($yAxisMax);
    $yAxisDecimalDigits = $this->getNumYDigits();
    my $chartHeight = $scaledYAxisMax - $scaledYAxisMin;

    # Check to see if either the user specified ymin/ymax values, or the
    # data itself was such that they are both the same such that there is
    # no height.
    return "Chart height = 0 (ymin($yAxisMin) == ymax($yAxisMax))"
      if ( $chartHeight == 0 );

    # Check to see if either the user specified ymin/ymax values, or the
    # data itself was such that ymin > ymax.
    return "Y max ($yAxisMax) < Y Min ($yAxisMin)" if ( $chartHeight < 0 );

    # To support scatter graphs (where the X data is probably not sorted)
    # we get the X axis labels and sort them (numerically) producing an
    # array of indexes which will then be used when plotting the actual
    # data.  For example, if @xAxis is (1 3 5 2 4), then the indexes of the
    # values to plot would be 0 3 1 4 2
    my @xAxis = $this->getXaxis();
    my $xGrid = $this->getXgrid();
    my $xAxisNumeric = 1;   # Flag whether the X axis values are numeric or not.
    my %xAxisIndex;

    # Check to see if the X axis values are numeric or not.  If not, then
    # we fake X axis data to be the indexes in the array.
    if (@xAxis) {
        foreach my $index ( 0 .. $#xAxis ) {
            if ( $xAxis[$index] =~ m/([\-]?[0-9.]+[eE]?[+-]?\d*)/ ) {
                $xAxisIndex{$index} = $1;
            }
            else {
                $xAxisIndex{$index} = $index;
                $xAxisNumeric = 0;
            }
        }
    }
    else {
        if ($scatterChart) {    # No xaxis specified and scatter graph
            return "xaxis needs to be specified for a scatter graph";
        }
        else {
            foreach my $index ( 0 .. $numDataPoints ) {
                $xAxisIndex{$index} = $index;
            }
        }
    }
    return "non-numeric X axis values not allowed for a scatter graph"
      if ( $scatterChart && !$xAxisNumeric );

    # Get the number of user specified X axis lines/labels to draw.
    my $numXGrids = $this->getNumXGrids();

    # Create an array that will represent the drawn X axis grid lines.  If
    # a chart type is 'scatter', then assume the X axis data is real
    # numbers (not simple text).
    my @xAxisLabels;
    my $xAxisMin;
    my $xAxisMax;
    if ($scatterChart) {
        $xAxisMin = 9e+40;     # Initialize with some very large value.
        $xAxisMax = -9e+40;    # Initialize with some very small value.
        foreach my $i ( 0 .. $#xAxis ) {
            my $value = $xAxisIndex{$i};
            if ( $value =~ m/([\-]?[0-9.]+[eE]?[+-]?\d*)/ ) {
                $xAxisMin = $1 if ( $1 < $xAxisMin );
                $xAxisMax = $1 if ( $1 > $xAxisMax );
            }
        }
        my ( $newXmin, $newXmax, $newNumXGrids, $newNumXDecimalDigits );

        # Since we are 'scatter' and there are 'bar' subtypes, we need to
        # artificially ask for 1 more X grid than normal.
        if ($numBarDataSets) {
            ( $newXmin, $newXmax, $newNumXGrids, $newNumXDecimalDigits ) =
              $this->computeLinearMinMax( $xAxisMin, $xAxisMax + 1,
                $numDataPoints );
        }
        else {
            ( $newXmin, $newXmax, $newNumXGrids, $newNumXDecimalDigits ) =
              $this->computeLinearMinMax( $xAxisMin, $xAxisMax,
                $numXGrids + 1 );
        }
        $this->setXminOfData( $xAxisMin = $newXmin );
        $this->setXmaxOfData( $xAxisMax = $newXmax );
        $this->setNumXGrids( $numXGrids = $newNumXGrids );
        $this->setNumXDigits($newNumXDecimalDigits);
    }
    else {
        $this->setXminOfData( $xAxisMin = 0 );

        # Since not a scatter graph, then assume that the X axis labels are
        # simple text and are drawn in the exact order that they occur in
        # the table.  As an exception, if no X axis is specified, then
        # there are no X labels to draw so just compute the number of grid
        # lines.
        if (@xAxis) {
            @xAxisLabels = @xAxis;
            $this->setXmaxOfData( $xAxisMax = $#xAxis );

            # Set the number of X grids be the smaller of: number of data
            # points to draw or the number of X grids the user specifies
            $this->setNumXGrids( $numXGrids = ( $numDataPoints - 2 ) )
              if ( ( $numDataPoints - 2 ) < $numXGrids );
        }
        else {
            @xAxisLabels = @xAxis;
            $this->setXmaxOfData( $xAxisMax = $numDataPoints );
        }
    }

    # Compute the number of digits to use when displaying the Y axis
    # labels.
    if ($scatterChart) {

        # Check for error situation where there is no chart height as the
        # xmin == xmax
        return "Chart width = 0 (xmin($xAxisMin) == xmax($xAxisMax))"
          if ( $xAxisMin == $xAxisMax );
        my $maxDigits =
          $this->computeNumDigits( $xAxisMin, $xAxisMax, $numXGrids );
        $this->setNumXDigits($maxDigits);
    }

    # Calculate how much space will be needed for the Y axis labels.
    # Although tedious, we need to walk through each number that will be
    # drawn and calculate it's width since the widths can vary from number
    # to number.
    my @yLabels;
    if ( $this->getYaxis() eq "on" ) {

        # Calculate the string width of both the min/max Y axis labels so
        # we know how much room to allocate for them.  Save the values for
        # later use.
        my $labelInc  = ( $yAxisMax - $yAxisMin ) / ( $numYGrids + 1 );
        my $yaxis     = $yAxisMin;
        my $maxLength = 0;
        my $len;
        for my $yAxisIndex ( 0 .. ( $numYGrids + 1 ) ) {
            my $text = _printNumber( $yaxis, $yAxisDecimalDigits );
            $yLabels[$yAxisIndex] = $text;
            $len = length($text);
            $maxLength = $len if ( $len > $maxLength );
            if ( $scale eq "semilog" ) {
                $yaxis *= 10.0;
            }
            else {
                $yaxis += $labelInc;
            }
        }
        $xLL += $this->getFontWidth("yaxis") * $maxLength;
    }

    # Calculate how much space will be needed for the X label (if specified).
    my $xLabel = $this->getXlabel();
    if ( defined $xLabel ) {
        $yLL -= $this->getFontHeight("xlabel");
    }

    # Calculate how much space will be needed for the X axis labels (if
    # specified).  Check the X axis angle to see what the orientation
    # of the labels needs to be.
    # A special case is scatter chart.
    my $xAxisAngle  = $this->getXaxisAngle();
    my $xAxisMaxLen = 0;
    my @xLabels;
    if (@xAxis) {
        if ($scatterChart) {
            my $xaxis = $xAxisMin;
            my $labelInc = ( $xAxisMax - $xAxisMin ) / ( $numXGrids + 1 );
            my $xAxisDecimalDigits = $this->getNumXDigits;
            for my $xAxisIndex ( 0 .. ( $numXGrids + 1 ) ) {
                my $text = _printNumber( $xaxis, $xAxisDecimalDigits );
                $xLabels[$xAxisIndex] = $text;
                $xaxis += $labelInc;
            }
        }
        if ( $xAxisAngle == 0 ) {

            # Horizontal labels so just add the height of the font
            $yLL -= $this->getFontHeight("xaxis");
        }
        else {

            # Note: if the angle is != 0, then assume 90 degrees (for now)
            # so the labels are vertical so use the max length.
            my $maxLen = 0;
            my $len    = 0;
            if ($scatterChart) {
                my $xaxis = $xAxisMin;
                my $labelInc = ( $xAxisMax - $xAxisMin ) / ( $numXGrids + 1 );
                my $xAxisDecimalDigits = $this->getNumXDigits;
                for my $xAxisIndex ( 0 .. ( $numXGrids + 1 ) ) {
                    my $text = _printNumber( $xaxis, $xAxisDecimalDigits );
                    $len = length($text);
                    $maxLen = $len if ( $len > $maxLen );
                    $xaxis += $labelInc;
                }
            }
            else {
                for my $x ( values %xAxisIndex ) {
                    $len = length($x);
                    $maxLen = $len if ( $len > $maxLen );
                }
            }
            $yLL -= $this->getFontWidth("xaxis") * $maxLen;
            $xAxisMaxLen = $maxLen;
        }
    }

    # Calculate how much space will be needed for the legend.
    my @legends = $this->getLegend();
    if (@legends) {
        my $legendWidth;
        my $maxLegendWidth = 0;
        for my $legend (@legends) {
            $legendWidth    = length($legend);
            $maxLegendWidth = $legendWidth
              if ( $legendWidth > $maxLegendWidth );
        }
        $xUR -= $this->getFontWidth("legend") * $maxLegendWidth;
    }

    # Calculate how much space will be needed for the chart title
    if ( defined $this->getTitle() ) {
        $yUR += $this->getFontHeight("title");
    }

    # OK, now that we've calculated the bounding box for the chart, we
    # calculate other various values.

    # Calculate the width/height of the chart portion.
    my $chartWidthInPixels  = $xUR - $xLL;
    my $chartHeightInPixels = $yLL - $yUR;

    # If any of the subTypes are 'bar', then compute how wide the bars need
    # to be given how many bars are to be drawn and how much space is
    # available for them to be drawn in.
    my $xBarWidth    = 0;
    my $barHalfWidth = 0;
    my $xBarLeadingSpace =
      0;    # Define the leading space (in pixels) before the first bar
    my $xBarTrailingSpace = 0
      ; # Define the trailing space (in pixels) after the last bar (in addition to space between bars)
    my $xBarSpace = 0;    # Define the space (in pixels) between bars
    if ($numBarDataSets) {

        # Check to see if any of the types is 'area' as it doesn't make
        # sense to mix 'area' and 'bar' on the same chart.
        return "Error: Can't mix 'area' and 'bar' subtypes on the same chart"
          if ( grep( /area/, @subTypes ) );
        $xBarSpace         = $this->getBarSpace;
        $xBarLeadingSpace  = $this->getBarLeadingSpace;
        $xBarTrailingSpace = $this->getBarTrailingSpace - $xBarSpace;
        $xBarWidth         = (
            (
                ( $chartWidthInPixels / $numDataPoints ) -
                  $xBarLeadingSpace -
                  $xBarTrailingSpace
            ) / $numBarDataSets
        ) - ( $xBarSpace + 1 );
        $barHalfWidth = $xBarWidth / 2;
    }

    # Calculate the width of the chart (in terms of graphed data) and the
    # number of pixels per X value (used for scatter graphs).
    my $chartWidth = $xAxisMax - $xAxisMin;
    $chartWidth = 1 if ( !$scatterChart );
    my $xPixelsPerValue = $chartWidthInPixels / $chartWidth;

    # Calculate the number of pixels per X element (non-scatter)
    my $xDrawInc;
    if ($scatterChart) {
        $xDrawInc = $chartWidthInPixels / ( $numXGrids + 1 );
    }
    else {
        if ($numBarDataSets) {

            # If bars are drawn, then we need to artificially make more room
            # for the bars by assuming 1 extra (undrawn) data set.
            $xDrawInc = $chartWidthInPixels / $numDataPoints;
        }
        else {
            $xDrawInc = $chartWidthInPixels / ( $numDataPoints - 1 );
        }
    }
    my $yPixelsPerValue = $chartHeightInPixels / $chartHeight;

    # Draw box around entire chart so area filling won't get outside of the
    # box
    $im->rectangle( $xLL, $yLL, $xUR, $yUR, $black );

    # If a user specified bgcolor (and it isn't the same as the default
    # background color), then set this color to surround the chart.
    if ( defined $bgcolor[0] && $bgcolor[0] !~ /$defaultBGcolorText/i ) {
        my $bgcolorOutside =
          $im->colorAllocate( _convert_color( $bgcolor[0] ) );
        $im->fill( 1, 1, $bgcolorOutside );
    }

    # If a user also specified bgcolor with a 2nd value (and it isn't the
    # same as the default background color), then set this color to fill
    # the inside of the chart.
    if ( defined $bgcolor[1] && $bgcolor[1] !~ /$defaultBGcolorText/i ) {
        my $bgcolorInside = $im->colorAllocate( _convert_color( $bgcolor[1] ) );
        $im->fill( $xLL + 1, $yUR + 1, $bgcolorInside );
    }

    ########################################################################
    # OK, we are about to actually start drawing things.  The order we draw
    # things is:
    #     1) draw areas
    #     2) draw grid lines and X/Y axis labels
    #     3) draw bars
    #     4) draw lines, points, plines
    #     5) draw rectangle around chart
    #     6) draw data point labels
    #     7) draw chart title, X and Y label
    #     8) draw legends

    # 1111111111111111111111111111111111111111111111111111111111111111111111
    my @dataSetlastValue;

    # Start drawing each data set.  The only exception is if there is no
    # data, then don't draw anything.
    # Note: the data sets are drawn back to front so that areas are drawn
    # correctly.
    # Note: all areas are drawn first so they appear behind the lines and
    # won't hide other data sets.
    foreach ( my $dataSet = $numDataSets - 1 ; $dataSet >= 0 ; $dataSet-- ) {
        my $row = $data[$dataSet];
        my @row = @{ $data[$dataSet] };

        my $color = $allocatedColors[$dataSet];
        if ( $subTypes[$dataSet] eq "area" ) {

            # Data set is an area.  Create a polygon representing the area
            # and then fill in that polygon.  Note: As a special case, if
            # the area to be drawn is lower on the chart than a previously
            # drawn area then just draw a line.
            my $poly = new GD::Polygon;
            my $xIndex;
            my $x;

            # Create the top of the polygon
            for $xIndex ( 0 .. ( $numDataPoints - 1 ) ) {
                my $topYValue = $row[$xIndex];

                # If there is no current value, then there is no default
                # value so assume a value the same as the minimum of the
                # chart.
                if ( $topYValue eq "" ) {
                    $topYValue = $scaledYAxisMin;
                }
                my $y =
                  $yLL - ( $topYValue - $scaledYAxisMin ) * $yPixelsPerValue;
                if ($scatterChart) {
                    $x =
                      $xLL +
                      ( ( $xAxisIndex{$xIndex} - $xAxisMin ) *
                          $xPixelsPerValue );
                }
                else {
                    $x = $xLL + ( $xDrawInc * $xIndex );
                }
                $poly->addPt( $x, $y );
                $dataSetlastValue[$dataSet] = $topYValue;
            }

            # Complete the polygon by adding a point at the bottom right of
            # the graph and then one at the bottom left of the graph.
            $poly->addPt( $x,   $yLL );
            $poly->addPt( $xLL, $yLL );
            $im->filledPolygon( $poly, $color );
        }
    }

    # 2222222222222222222222222222222222222222222222222222222222222222222222
    # Draw the Y axis labels grid lines (if asked for) so the grid lines
    # fall behind the areas/lines.
    my $yAxis = $this->getYaxis();
    my $yGrid = $this->getYgrid();
    if ( ( $yAxis eq "on" ) || ( $yGrid ne "off" ) ) {
        my $yDrawInc = $chartHeightInPixels / ( $numYGrids + 1 );
        for my $yAxisIndex ( 0 .. ( $numYGrids + 1 ) ) {
            my $text = $yLabels[$yAxisIndex];
            if ( $yAxis eq "on" ) {
                $im->string(
                    $this->getFont("yaxis"),
                    $xLL - ( length($text) + 1 ) * $this->getFontWidth("yaxis"),
                    $yLL -
                      ( $yDrawInc * $yAxisIndex ) -
                      ( $this->getFontHeight("yaxis") / 2 ),
                    $text,
                    $black
                );
            }
            my $Y = $yLL - ( $yDrawInc * $yAxisIndex );
            if (   ( $yAxisIndex != 0 )
                && ( $yAxisIndex <= $numYGrids )
                && $yGrid eq "on" )
            {
                $im->line( $xLL - 2, $Y, $xUR + 2, $Y, $gridColor );
            }
            if (   ( $yAxisIndex != 0 )
                && ( $yAxisIndex <= $numYGrids )
                && $yGrid eq "dot" )
            {
                $im->line( $xLL - 2, $Y, $xUR + 2, $Y, gdStyled );
            }

            # Draw tic marks between Y grid lines (if requested -- might be
            # the case if the style of graph is 'semilog')
            my $numYTics = $this->getNumYTics() + 1;

            # Draw tics skipping the tics above last value
            if ( $yAxisIndex < ( $numYGrids + 1 ) ) {
                for ( my $tic = 1 ; $tic <= $numYTics ; $tic++ ) {
                    my $ticY;
                    if ( $scale eq "semilog" ) {
                        $ticY = $Y - $this->_scale($tic) * $yDrawInc;
                    }
                    else {
                        $ticY = $Y - $tic * $yDrawInc / $numYTics;
                    }
                    $im->line( $xLL - 2, $ticY, $xLL + 2, $ticY, $gridColor );
                }
            }
        }
    }

    # Draw the X axis labels and grid lines (if asked for).  To do this we
    # calculate the interval between X axis values to draw based on the
    # user specified number of X axis values to draw.
    my $barNum = 0;
    if (@xAxis) {
        my $xIndexInc;
        my $xIndexMax;
        if ($scatterChart) {
            $xIndexInc = 1;

            # If bars are drawn, then there is 1 fewer X axis label to draw
            # than normal.
            if ($numBarDataSets) {
                $xIndexMax = $numXGrids;
            }
            else {
                $xIndexMax = $numXGrids + 1;
            }
        }
        else {
            if ( $numXGrids == 0 ) {
                $xIndexInc = 1;
            }
            else {
                $xIndexInc = int( $numDataPoints / ( $numXGrids + 1 ) );
            }
            $xIndexMax = $numDataPoints - 1;
        }
        my $xAxisFontWidth     = $this->getFontWidth("xaxis");
        my $xaxis              = $xAxisMin;
        my $xAxisDecimalDigits = $this->getNumXDigits;
        for (
            my $xAxisIndex = 0 ;
            $xAxisIndex <= $xIndexMax ;
            $xAxisIndex += $xIndexInc
          )
        {

            # Calculate what the X axis label will be.  If scatter then
            # compute the value, if not scatter then use the user specified
            # value.
            my $label;
            if ($scatterChart) {
                $label = $xLabels[$xAxisIndex];
            }
            else {
                $label = $xAxis[$xAxisIndex];
            }
            $label = "" if ( !defined $label );
            my $xLoc = $xLL + ( $xDrawInc * $xAxisIndex );

            # If a horizontal xaxis, then attempt to center the label
            # around the X axis.  A special case is when there are 'bar's
            # being drawn so the label then needs to be centered under the
            # are the bars are drawn in.
            if ( $xAxisAngle == 0 ) {

                # Calculate the centered X position of the axis label.
                my $len            = length($label);
                my $halfLabelWidth = $len / 2 * $xAxisFontWidth;
                my $xLabelLoc      = $xLoc - $halfLabelWidth;

             # Compute the X position of each X axis label.  In general we want
             # each label centered on the X axis line, but the first and last
             # labels need some extra care.  The first label might not have
             # enough room to be centered about the (0,0) point so needs to
             # positioned so the left part of the label lines up with (0,0).
             # The last label has a similar problem in that there might not be
             # enough room on the right side of the chart to center the label so
             # the right side of the label may need to be aligned with the right
             # side of the chart.
             # Note: if a bar data set, then just center under the bar
             # area
                my $xPos;
                if ($numBarDataSets) {
                    $xPos =
                      $xLabelLoc + $chartWidthInPixels / $numDataPoints / 2;
                }
                elsif ( $xLabelLoc > 0 ) {
                    if ( ( $xLabelLoc + $halfLabelWidth * 2 ) >= $imageWidth ) {
                        $xPos = $xUR - $len * $xAxisFontWidth;
                    }
                    else {
                        $xPos = $xLabelLoc;
                    }
                }
                else {
                    $xPos = $xLL;
                }

                # If any bars are drawn, then center the X axis label under
                # the bar area.
                $im->string( $this->getFont("xaxis"),
                    $xPos, $yLL + 3, $label, $black );
            }
            else {

                # Assuming a vertical label
                my $len             = length($label);
                my $halfLabelHeight = $this->getFontHeight("xaxis") / 2;
                my $yLabelLoc       = $yLL + $len * $xAxisFontWidth;
                $im->stringUp(
                    $this->getFont("xaxis"),
                    $xLoc - $halfLabelHeight,
                    $yLabelLoc + 3,
                    $label, $black
                );
            }
            if (   ( $xAxisIndex != 0 )
                && ( $xAxisIndex <= $xIndexMax )
                && $xGrid eq "on" )
            {
                $im->line( $xLoc, $yLL + 2, $xLoc, $yUR - 2, $gridColor );
            }
            if (   ( $xAxisIndex != 0 )
                && ( $xAxisIndex <= $xIndexMax )
                && $xGrid eq "dot" )
            {
                $im->line( $xLoc, $yLL + 2, $xLoc, $yUR - 2, gdStyled );
            }
        }
    }

    # 3333333333333333333333333333333333333333333333333333333333333333333333
    # Now draw any bars.
    $barNum = 0;
    for my $dataSet ( 0 .. $numDataSets - 1 ) {
        my $row = $data[$dataSet];
        my @row = @{ $data[$dataSet] };

        my $color = $allocatedColors[$dataSet];
        if ( $subTypes[$dataSet] eq "bar" ) {
            for my $xIndex ( 0 .. ( $numDataPoints - 1 ) ) {
                my $currentYValue = $row[$xIndex];

                # If there is no current value, then there is no default
                # value so assume a value the same as the minimum of the
                # chart.
                if ( $currentYValue eq "" ) {
                    $currentYValue = $scaledYAxisMin;
                }
                my $y = $yLL -
                  ( $currentYValue - $scaledYAxisMin ) * $yPixelsPerValue;
                my $x;
                if ($scatterChart) {
                    $x =
                      $xLL +
                      ( ( $xAxisIndex{$xIndex} - $xAxisMin ) *
                          $xPixelsPerValue );
                }
                else {
                    $x = $xLL + ( $xDrawInc * $xIndex );
                }
                $x +=
                  $xBarLeadingSpace +
                  ( ( $xBarWidth + ( $xBarSpace + 1 ) ) * $barNum ) +
                  $barHalfWidth;
                $im->filledRectangle(
                    $x - $barHalfWidth,
                    $y, $x + $barHalfWidth,
                    $yLL, $color
                );
                $im->rectangle(
                    $x - $barHalfWidth,
                    $y, $x + $barHalfWidth,
                    $yLL, $black
                );
            }
            $barNum++;
        }
    }

    # 4444444444444444444444444444444444444444444444444444444444444444444444
    # Now that the areas and bars are drawn, draw the lines and even redraw
    # lines outlining the already drawn areas (since some areas might have
    # been overwritten).
    for my $dataSet ( 0 .. $numDataSets - 1 ) {
        my $row = $data[$dataSet];
        my @row = @{ $data[$dataSet] };

        my $color = $allocatedColors[$dataSet];
        my ( $x1, $x2 );

        # Draw the data set (if an area, it gets filled in by code below).
        for my $xIndex ( 0 .. ( $numDataPoints - 2 ) ) {
            my $currentYValue = $row[$xIndex];
            my $nextYValue    = $row[ $xIndex + 1 ];
            $currentYValue = $this->_scale($currentYValue)
              if ( $currentYValue ne "" );
            $nextYValue = $this->_scale($nextYValue) if ( $nextYValue ne "" );

            # Deal with sparse data.  If there is:
            #    - current but no next value, draw a point at current
            #    - no current but a next value, draw a point at next
            #    - if both, draw a line between them if asked to
            if ( $currentYValue ne "" && $nextYValue eq "" ) {
                if ($scatterChart) {
                    $x1 =
                      $xLL +
                      ( ( $xAxisIndex{$xIndex} - $xAxisMin ) *
                          $xPixelsPerValue );
                }
                else {
                    $x1 = $xLL + ( $xDrawInc * $xIndex );
                }

                # If any bars were drawn, then place all lines, plines,
                # points in the middle of the area in which the bars were
                # drawn.
                if ($numBarDataSets) {
                    $x1 += $xDrawInc / 2;
                }
                my $y1 = $yLL -
                  ( $currentYValue - $scaledYAxisMin ) * $yPixelsPerValue;
                if ( $subTypes[$dataSet] ne "bar" ) {
                    $im->filledRectangle(
                        $x1 - $pointSizeHalf,
                        $y1 - $pointSizeHalf,
                        $x1 + $pointSizeHalf,
                        $y1 + $pointSizeHalf,
                        $color
                    );
                }
                $dataSetlastValue[$dataSet] = $currentYValue;
            }
            elsif ( $currentYValue eq "" && $nextYValue ne "" ) {
                if ($scatterChart) {
                    $x2 =
                      $xLL +
                      ( ( $xAxisIndex{ ( $xIndex + 1 ) } - $xAxisMin ) *
                          $xPixelsPerValue );
                }
                else {
                    $x2 = $xLL + ( $xDrawInc * ( $xIndex + 1 ) );
                }

                # If any bars were drawn, then place all lines, plines,
                # points in the middle of the area in which the bars were
                # drawn.
                if ($numBarDataSets) {
                    $x2 += $xDrawInc / 2;
                }
                my $y2 =
                  $yLL - ( $nextYValue - $scaledYAxisMin ) * $yPixelsPerValue;
                if ( $subTypes[$dataSet] ne "bar" ) {
                    $im->filledRectangle(
                        $x2 - $pointSizeHalf,
                        $y2 - $pointSizeHalf,
                        $x2 + $pointSizeHalf,
                        $y2 + $pointSizeHalf,
                        $color
                    );
                }
            }
            elsif ( $currentYValue ne "" && $nextYValue ne "" ) {
                if ($scatterChart) {
                    $x1 =
                      $xLL +
                      ( ( $xAxisIndex{$xIndex} - $xAxisMin ) *
                          $xPixelsPerValue );
                    $x2 =
                      $xLL +
                      ( ( $xAxisIndex{ ( $xIndex + 1 ) } - $xAxisMin ) *
                          $xPixelsPerValue );
                }
                else {
                    $x1 = $xLL + ( $xDrawInc * $xIndex );
                    $x2 = $xLL + ( $xDrawInc * ( $xIndex + 1 ) );
                }

                # If any bars were drawn, then place all lines, plines,
                # points in the middle of the area in which the bars were
                # drawn.
                if ($numBarDataSets) {
                    $x1 += $xDrawInc / 2;
                    $x2 += $xDrawInc / 2;
                }
                my $y1 = $yLL -
                  ( $currentYValue - $scaledYAxisMin ) * $yPixelsPerValue;
                my $y2 =
                  $yLL - ( $nextYValue - $scaledYAxisMin ) * $yPixelsPerValue;

                # If just a line, then draw a second and 3rd line slightly
                # below the line to make it appear thicker.
                if (   $subTypes[$dataSet] eq "line"
                    || $subTypes[$dataSet] eq "pline"
                    || $subTypes[$dataSet] eq "area" )
                {
                    if ( $GD::VERSION >= 2.15 ) {
                        $im->setThickness($lineWidth);
                        $im->line( $x1, $y1, $x2, $y2, $color );
                        $im->setThickness(1);
                    }
                    elsif ( $lineWidth > 1 ) {
                        $im->line( $x1, $y1, $x2, $y2, $color );
                        for my $yDiff ( 1 .. ( ( $lineWidth - 1 ) / 2 ) ) {
                            $im->line( $x1, $y1 + $yDiff,
                                $x2, $y2 + $yDiff, $color );
                        }
                        for my $yDiff ( 1 .. ( ($lineWidth) / 2 ) ) {
                            $im->line( $x1, $y1 - $yDiff,
                                $x2, $y2 - $yDiff, $color );
                        }
                    }
                    else {
                        $im->line( $x1, $y1, $x2, $y2, $color );
                    }
                }

                # Draw points.
                if (   $subTypes[$dataSet] eq "point"
                    || $subTypes[$dataSet] eq "pline" )
                {
                    $im->filledRectangle(
                        $x1 - $pointSizeHalf,
                        $y1 - $pointSizeHalf,
                        $x1 + $pointSizeHalf,
                        $y1 + $pointSizeHalf,
                        $color
                    );
                    $im->filledRectangle(
                        $x2 - $pointSizeHalf,
                        $y2 - $pointSizeHalf,
                        $x2 + $pointSizeHalf,
                        $y2 + $pointSizeHalf,
                        $color
                    );
                }
                $dataSetlastValue[$dataSet] = $nextYValue;
            }
        }
    }

    # 5555555555555555555555555555555555555555555555555555555555555555555555
    # Redraw box around entire chart in case it got overwritten by
    # anything.
    $im->rectangle( $xLL, $yLL, $xUR, $yUR, $black );

    # 6666666666666666666666666666666666666666666666666666666666666666666666
    # If requested, draw in labels for the charted values.  This is done
    # last so the labels appear on top of everything else that has been
    # placed on the chart.
    my $numDataLabels = my @dataLabels = $this->getDataLabels();

    # If fewer dataLabel values specified than data sets, then repeat the
    # user specified values.
    if (@dataLabels) {
        my $font       = $this->getFont("data");
        my $fontWidth  = $this->getFontWidth("data");
        my $fontHeight = $this->getFontHeight("data");
        $barNum = 0;
        for my $dataSet ( 0 .. $numDataSets - 1 ) {
            my $dataLabel = $dataLabels[ $dataSet % $numDataLabels ];
            my $row       = $data[$dataSet];
            my @row       = @{ $data[$dataSet] };

            my $color = $allocatedColors[$dataSet];
            for my $xIndex ( 0 .. ( $numDataPoints - 1 ) ) {
                my $currentYValue = $row[$xIndex];
                my $drawText      = $currentYValue;
                if ($scatterChart) {
                    $drawText = $xAxisIndex{$xIndex} . "/" . $currentYValue;
                }
                my $len = length $drawText;

                # If the drawText is non empty, place string/box such
                # that the lower right corner is located at the data value.
                # The only exception is if the box would fall off of the
                # chart either to the left or at the top.
                if ( $currentYValue ne "" ) {
                    my $currentValueY = $this->_scale($currentYValue);
                    my $x1;
                    if ($scatterChart) {
                        $x1 =
                          $xLL +
                          ( ( $xAxisIndex{$xIndex} - $xAxisMin ) *
                              $xPixelsPerValue ) -
                          ( $len * $fontWidth ) - 4;
                    }
                    else {
                        $x1 =
                          $xLL +
                          ( $xDrawInc * $xIndex ) -
                          ( $len * $fontWidth ) - 4;
                    }

                    # If any bars were drawn, then all lines, plines,
                    # points were drawn in the middle of the area in which
                    # the bars were drawn so we need to adjust the data
                    # labels accordingly.  If the data label is for a bar
                    # itself, then perform a slightly different adjustment.
                    if ($numBarDataSets) {
                        if ( $subTypes[$dataSet] eq "bar" ) {
                            $x1 +=
                              $xBarLeadingSpace +
                              ( ( $xBarWidth + ( $xBarSpace + 1 ) ) * $barNum )
                              + $barHalfWidth;
                        }
                        else {
                            $x1 += $xDrawInc / 2;
                        }
                    }
                    my $y1 =
                      $yLL -
                      ( $currentValueY - $scaledYAxisMin ) * $yPixelsPerValue -
                      $fontHeight - 4;
                    $x1 += $len * $fontWidth + 4
                      if ( $x1 < 0 );    # Push back onto left side
                    $y1 += $fontHeight if ( $y1 < 0 );    # Push down into chart
                    if ( $dataLabel eq "box" ) {

                        # In order to put the value into a box, we draw a box,
                        # fill it with white, then draw a black line around the
                        # white box and then draw the value inside the box.
                        $im->filledRectangle(
                            $x1, $y1,
                            $x1 + $len * $fontWidth + 4,
                            $y1 + $fontHeight + 4,
                            $defaultBGcolor
                        );
                        $im->rectangle(
                            $x1, $y1,
                            $x1 + $len * $fontWidth + 4,
                            $y1 + $fontHeight + 4, $black
                        );
                    }
                    if ( $dataLabel ne "off" ) {
                        $im->string( $font, $x1 + 3, $y1 + 2, $drawText,
                            $color );
                    }
                }
            }
            $barNum++ if ( $subTypes[$dataSet] eq "bar" );
        }
    }

    # 7777777777777777777777777777777777777777777777777777777777777777777777
    # Draw the title (if requested)
    if ( defined $this->getTitle() ) {
        my $title = $this->getTitle();
        my $x =
          $xLL +
          $chartWidthInPixels / 2 -
          ( length($title) / 2 * $this->getFontWidth("title") );
        my $y = 0;
        $im->string( $this->getFont("title"),
            $x, $y, $this->getTitle(), $black );
    }

    # Draw the Y label (if specified)
    if ( defined $yLabel ) {
        $im->stringUp(
            $this->getFont("ylabel"),
            $margin,
            $yUR +
              ( $chartHeightInPixels / 2 ) +
              ( length($yLabel) * $this->getFontWidth("ylabel") / 2 ),
            $yLabel,
            $black
        );
    }

    # Draw the X label (if specified)
    if ( defined $xLabel ) {
        my $yPos = $yLL + 5;

        # Adjust depending on if X axis labels are drawn or not and the
        # orientation of the X axis labels.
        if (@xAxis) {
            if ( $xAxisAngle == 0 ) {
                $yPos += $this->getFontHeight("xaxis");
            }
            else {
                $yPos += $xAxisMaxLen * $this->getFontWidth("xaxis");
            }
        }
        $im->string(
            $this->getFont("xlabel"),
            $xLL +
              ( $chartWidthInPixels / 2 ) -
              ( length($xLabel) * $this->getFontWidth("xlabel") / 2 ),
            $yPos,
            $xLabel,
            $black
        );
    }

    # 8888888888888888888888888888888888888888888888888888888888888888888888
    # Draw the legends (if requested).  This requires some extra work since
    # we may need to 'bubble' up/down the legends if they would overlap
    # each other.
    if (@legends) {
        my $legendFont     = $this->getFont("legend");
        my $fontHeight     = $this->getFontHeight("legend");
        my $halfFontHeight = $fontHeight / 2;
        my $fontWidth      = $this->getFontWidth("legend");
        my $x1             = $xUR + 5;

        # 1. determine the ideal Y location of each label
        my @lastValues;
        for my $dataSet ( 0 .. $numDataSets - 1 ) {

            # Use the last point drawn for each line so we know where to
            # draw the legend at the end of the lines.
            my $lastValue = $dataSetlastValue[$dataSet];
            my $y =
              $yLL -
              ( ( $lastValue - $scaledYAxisMin ) * $yPixelsPerValue ) -
              $halfFontHeight;

            # If the y location falls off of the bottom of the chart, then
            # pull up to the bottom of the chart.
            $y = $yLL - $halfFontHeight if ( $y > $yLL );
            $lastValues[$dataSet] = $y;
        }

        # 2. Now adjust the Y locations so no labels overlap.  If any two
        # labels have the same Y location, then the first data set gets that
        # location and all subsequent data sets labels get moved.
        @lastValues = $this->adjustLegendYLocations( $yUR, @lastValues );

        # 3. Now draw the legends at the (possibly) newly computed Y
        # locations.
        for my $dataSet ( 0 .. $numDataSets - 1 ) {
            my $y1 = $lastValues[$dataSet];
            $im->string( $legendFont, $x1, $y1, $legends[$dataSet], $black );
            $im->line(
                $x1,
                $y1 + $fontHeight,
                $x1 + length( $legends[$dataSet] ) * $fontWidth,
                $y1 + $fontHeight,
                $allocatedColors[$dataSet]
            );
            $im->line(
                $x1,
                $y1 + $fontHeight - 1,
                $x1 + length( $legends[$dataSet] ) * $fontWidth,
                $y1 + $fontHeight - 1,
                $allocatedColors[$dataSet]
            );
        }
    }

    ########################################################################
    # OK, the chart is all drawn so all we need to do is write it out to
    # a file.
    my $workfile = Foswiki::Func::getWorkArea('ChartPlugin');
    my $tmpfile  = "$workfile/$$" . time();
    open( IMAGE, ">$tmpfile" );
    binmode(IMAGE);
    if ( $GD::VERSION > 1.19 ) {
        print IMAGE $im->png;
    }
    else {
        print IMAGE $im->gif;
    }
    close IMAGE;

   # And save it as an attachment. Note that there are no access control checks!
    my $topicObject =
      new Foswiki::Meta( $Foswiki::Plugins::SESSION, $this->{WEB},
        $this->{TOPIC} );
    $topicObject->attach(
        name          => $this->{FILE_NAME},
        dontlog       => 1,
        hide          => 1,
        file          => $tmpfile,
        notopicchange => 1
    );
    unlink($tmpfile);
    return undef;
}

# Given an array of Y locations for legends, walk through the array and
# adjust the values such that no legends will overlap.  This is done in two
# passes.  The first pass is to shift locations up if they overlap with
# other labels.  The second pass is to shift down the locations if any were
# shifted off the top of the chart.
sub adjustLegendYLocations {
    my ( $this, $yUR, @yValues ) = @_;
    my $fontHeight     = $this->getFontHeight("legend");
    my $halfFontHeight = $fontHeight / 2;
    my $overLap;
    my $overLappedWith;
    my $yValue;
    my $dataSet;
    my @retYvalues;

    my %newYvalues1;
    my %yValues;
    my $needToShiftBackDown = 0;

    # Put the Y values into a hash since it is easier to deal with a hash.
    for $dataSet ( 0 .. @yValues - 1 ) {
        $yValues{$dataSet} = $yValues[$dataSet];
    }

    # Now sort the Y values from highest value (lowest point on the chart)
    # to lowest value (highest point on the chart) to make it easier to
    # adjust the Y values such that no two values are on top of each other.
    # The process is to start with the lowest (on the chart) legend and
    # then adjust all subsequent legends up if they happen to overlap
    # previously placed legends.

    for $dataSet ( sort { $yValues{$b} <=> $yValues{$a} } keys %yValues ) {
        $yValue  = $yValues{$dataSet};
        $overLap = 0;

        # Check to see if the currently looked at Y value overlaps with any
        # (possibly adjusted) previous Y values.  If so, then adjust it up.
        for my $newDataSet (
            sort { $newYvalues1{$b} <=> $newYvalues1{$a} }
            keys %newYvalues1
          )
        {
            my $new = $newYvalues1{$newDataSet};

            # Check to see if the labels actually overlap.
            if ( ( $yValue + $halfFontHeight ) >= ( $new - $halfFontHeight ) ) {

                # Remember the value of the already placed legend so when
                # we adjust the current value, we adjust based on what we
                # overlapped with.  We keep a flag instead of just using
                # $overLappedWith since $overLappedWith might equal 0 in an
                # overlap condition which would break the logic.
                $overLap        = 1;
                $overLappedWith = $new;
            }
        }
        if ( $overLap != 0 ) {

            # Adjust the current Y value up on the chart by an amount of
            # 1/2 the height of the legend font.  The starting point is the
            # previously placed Y value that the current value overlapped
            # with.
            $yValue = $overLappedWith - $fontHeight;
        }

        # Save the possibly adjusted value into a new hash;
        $newYvalues1{$dataSet} = $yValue;

        # Check to see if the shifting up of labels moved it above the
        # top of the graph.  If so, we will need to then shift things
        # back down (see below).
        $needToShiftBackDown = 1 if ( $yValue < $yUR );
    }

    # If any values got adjusted off of the top of the chart, then we need
    # to re-adjust the legends back down so they are all on the chart.
    if ( $needToShiftBackDown == 1 ) {
        my %newYvalues2;
        my $firstValue = 1;
        my $adjustedTo;

        # Now adjust back down on the graph any legends that got adjusted
        # off the top of the graph.
        for $dataSet (
            sort { $newYvalues1{$a} <=> $newYvalues1{$b} }
            keys %newYvalues1
          )
        {
            $yValue  = $newYvalues1{$dataSet};
            $overLap = 0;

            # If the first value, we don't need to do a lot of work since
            # there are no previous values to compare against.
            if ($firstValue) {

                # Check to see if the 1st value falls off of the top of the
                # chart.  If so, force its value to be at the top of the
                # chart.  This will force all other values to be shifted
                # down as well.
                if ( $yValue < $yUR ) {
                    $overLap    = -1;
                    $adjustedTo = $yUR - $halfFontHeight;
                    $firstValue = 0;
                }
            }
            else {

    # Check to see if the current value overlaps any of the previously looked at
    # legends.  If so, adjust down.
                for my $newDataSet2 (
                    sort { $newYvalues2{$a} <=> $newYvalues2{$b} }
                    keys %newYvalues2
                  )
                {
                    my $new = $newYvalues2{$newDataSet2};
                    if ( ( $yValue - $halfFontHeight ) <=
                        ( $new + $halfFontHeight ) )
                    {
                        $overLap    = 1;
                        $adjustedTo = $new + $fontHeight;
                    }
                    else {

                     # If already in an overlap mode, then take the last legend
                     # value we adjusted as the starting point for adjusting the
                     # current value
                        $adjustedTo = $new + $fontHeight if ($overLap);
                    }
                }
            }
            if ( $overLap == 0 ) {
                $newYvalues2{$dataSet} = $yValue;
            }
            else {
                $newYvalues2{$dataSet} = $adjustedTo;
            }
        }

        # Move the adjusted values into an array that gets returned
        for $dataSet ( keys %newYvalues2 ) {
            $retYvalues[$dataSet] = $newYvalues2{$dataSet};
        }
    }
    else {

        # Move the adjusted values into an array that gets returned
        for $dataSet ( keys %newYvalues1 ) {
            $retYvalues[$dataSet] = $newYvalues1{$dataSet};
        }
    }
    return @retYvalues;
}

# Assuming a linear (base 10) scale, this routine attempts to compute
# easily read/understood min and max values based on the min and max values
# of the actual data plotted rounding things to 1.0eXX, 2.0eXX, or 5.0eXX.
sub computeLinearMinMax {
    my ( $this, $min, $max, $grids ) = @_;

    # Compute the difference between the max and min values.
    my $diff = $max - $min;

    # Deal with the special case where the difference is 0 or the number of
    # grids is 0.  If this is the case, then there is nothing we can do
    # here so we just return.
    return ( $min, $max, $grids, 0 ) if ( $diff == 0 );
    return ( $min, $max, $grids, 0 ) if ( $grids == 0 );

    # Compute the increment between grid lines.
    my $inc = 0.9 * $diff / $grids;

    # Attempt to pick a better increment that is easier for a person to
    # comprehend.

    # Calculate the power of the increment.
    my $power;
    if ( $inc > 1 ) {
        $power = pow( 10.0, ceil( log10($inc) ) - 1 );
    }
    else {
        $power = pow( 10.0, floor( log10($inc) ) );
    }
    my $i = 1.0 / $power * $inc;

    # Now that all of the increments have been normalized to be between
    # 0-10, calculate a better human readable value.
    my $newInc;
    if ( $i <= 1.0 ) {
        $newInc = 1.0;
    }
    elsif ( $i <= 2.0 ) {
        $newInc = 2.0;
    }
    elsif ( $i <= 5.0 ) {
        $newInc = 5.0;
    }
    else {
        $newInc = 10.0;
    }

    # Take the normalized value and convert back to the actual range.
    $newInc *= $power;

    # Now adjust (round down) the min value based on the computed
    # increment.
    my $newMin = floor( $min / $newInc ) * $newInc;

    # Compute the new difference between the original max and the new min.
    my $newDiff = $max - $newMin;

    # Compute the number of actual grids that will be used
    my $numGrids = ceil( $newDiff / $newInc );

    # Now compute the new max based on the new min, the increment, and the
    # new number of grids.
    my $newMax = $newMin + $newInc * $numGrids;

    # Calculate the max number of decimal points needed to display the
    # values so the print routine will use the same formatting when
    # printing out labels.
    my $numDecimalDigits;
    if ( $newInc > 1 ) {
        $numDecimalDigits = 0;
    }
    else {
        $numDecimalDigits = -floor( log10($newInc) );
    }
    return ( $newMin, $newMax, $numGrids - 1, $numDecimalDigits );
}

# Assuming a log10 scale, this routine attempts to compute easily
# read/understood ymin and ymax values based on the real min and max values
# of the actual data plotted rounding things to the nearest log10 line.
sub computeYMinMaxLog {
    my ($this)    = @_;
    my $ymin      = $this->getYminOfData();
    my $ymax      = $this->getYmaxOfData();
    my $yMinLog10 = log10($ymin);
    my $yMaxLog10 = log10($ymax);
    my $newYmin = pow( 10.0, floor($yMinLog10) );
    my $newYmax = pow( 10.0, ceil($yMaxLog10) );

    my $numYGrids = log10($newYmax) - log10($newYmin);

    $this->setYminOfData($newYmin);
    $this->setYmaxOfData($newYmax);
    $this->setNumYGrids($numYGrids);
    $this->setNumYDigits(0);

    # If the user hasn't specified the number of ytics, then set it here.
    my $tics = $this->getNumYTics();
    $this->setNumYTics(8) if ( $tics == -1 || $tics > 8 );
}

# Attempt to compute the number of significant digits in the numbers
# generated based on the user specified min and/or max.
sub computeNumDigits {
    my ( $this, $min, $max, $numGrids ) = @_;

    # Compute the difference between the max and min values.
    my $diff = $max - $min;

    # Compute the increment between grid lines.
    my $inc       = $diff / ( $numGrids + 1 );
    my $value     = $min;
    my $maxDigits = 0;
    my $maxLen    = 0;
    for my $yAxisIndex ( 0 .. $numGrids ) {
        if ( $value =~ /\./ ) {
            $value =~ m/-?\d+\.(\d+)/;
            my $decimalPart = $1;
            $maxLen = length($decimalPart);
            $maxDigits = $maxLen if ( $maxLen > $maxDigits );
        }
        $value += $inc;
    }

    # Limit the number of digits to 4 decimal digits.
    $maxDigits = 4 if ( $maxDigits >= 4 );
    return ($maxDigits);
}

# Convert a color in the form of either #RRGGBB or just RRGGBB (both in hex
# format) to a 3 element array of decimal numbers in the form
# (RED GREEN BLUE).
sub _convert_color {
    my ($hexcolor) = @_;
    my ( $red, $green, $blue );
    $hexcolor =~ /#?(..)(..)(..)/;
    $red   = hex($1);
    $green = hex($2);
    $blue  = hex($3);
    return ( $red, $green, $blue );
}

# This routine takes a floating point number and returns a string in a
# consistent format suitable for printing out and showing the user.  If the
# number is > 999,999 or less than 0.001, then engineering notation is
# used.
sub _printNumber {
    my ( $num, $numDigits ) = @_;
    my $text;
    if ( abs($num) > 999999 ) {
        $text = sprintf( "%2.1e", $num );
    }
    elsif ( abs($num) < 0.001 && $num != 0 ) {
        $text = sprintf( "%2.1e", $num );
    }
    elsif ( $numDigits > 0 ) {
        $text = sprintf( "%.${numDigits}f", $num );
    }
    else {
        $text = $num;
    }
    return $text;
}

# Given a number, return an adjusted version of that number depending on
# the scale the user has specified.  If scale=semilog, then return the
# log10 of the value else just return the original value (assuming linear).
sub _scale {
    my ( $this, $value ) = @_;
    my $scale = $this->getScale();
    return $value if ( $scale ne "semilog" );

    # Assume semilog
    return log10($value);
}

1;
