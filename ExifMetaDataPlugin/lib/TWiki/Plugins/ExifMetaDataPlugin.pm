# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Pascal Buchbinder, pascal@joebar.ch
#
# $Id: ExifMetaDataPlugin.pm 8136 2006-01-05 23:09:17Z WillNorris $
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# The code used to parse the EXIF data is based on a script by
# Chris Breeze. The script is free software and available at
# http://www.breezesys.com/downloads/exif.zip
# The description of the EXIF file format by TsuruZoh Tachibanaya
# can be found at http://www.media.mit.edu/pia/Research/deepview/exif.html
#

# =========================
package TWiki::Plugins::ExifMetaDataPlugin;

use strict;

# =========================
# markers are FFXX where XX is one of those below
my %jpeg_markers = (
    SOF  => chr(0xc0),    #
    DHT  => chr(0xc4),    # Define Huffman table
    SOI  => chr(0xd8),    # Start of image
    EOI  => chr(0xd9),    # End of image
    SOS  => chr(0xda),    #
    DQT  => chr(0xdb),    # Define quantisation table
    DRI  => chr(0xdd),    # Define quantisation table
    APP1 => chr(0xe1),    # APP1 - where EXIF data is stored
);

# selected tags
my %tags;
my $intelAlignment;

# default tags
my %defaulttag = (
    0x9003 => "DateTimeOriginal",
    0x829A => "ExposureTime",
    0x829D => "FNumber",
    0x8827 => "ISOSpeedRating",
    0x920A => "FocalLength",
);

# tags supported by this version
my %supported_tags = (
    0x10e  => "string",    # "ImageDescription"
    0x10f  => "string",    # "Make"
    0x110  => "string",    # "Model"
    0x131  => "string",    # "Software"
    0x132  => "string",    # "DateTime"
    0x9003 => "string",    # "DateTimeOriginal"
    0x9004 => "string",    # "DateTimeDigitized"
    0x829A => "num",       # "ExposureTime"
    0x829D => "num",       # "FNumber"
    0x8827 => "num",       # "ISOSpeedRating"
    0x920A => "num",       # "FocalLength"
    0x9286 => "string",    # "UserComment"
);

# some valid EXIF tags
my %tagid = (
    0x10e  => "ImageDescription",
    0x10f  => "Make",
    0x110  => "Model",
    0x112  => "Orientation",
    0x11a  => "XResolution",
    0x11b  => "YResolution",
    0x128  => "ResolutionUnit",
    0x131  => "Software",
    0x132  => "DateTime",
    0x213  => "YCbCrPositioning",
    0x103  => "Compression",
    0x201  => "JPEGInterchangeFormat",
    0x202  => "JPEGInterchangeFormatLength",
    0x829A => "ExposureTime",
    0x829D => "FNumber",
    0x8769 => "EXIFSubIFD",
    0x8822 => "ExposureProgram",
    0x8827 => "ISOSpeedRating",
    0x9000 => "EXIFVersion",
    0x9003 => "DateTimeOriginal",
    0x9004 => "DateTimeDigitized",
    0x9101 => "ComponentsConfiguration",
    0x9102 => "CompressedBitsPerPixel",
    0x9204 => "ExposureBiasValue",
    0x9205 => "MaxApertureValue",
    0x9207 => "MeteringMode",
    0x9208 => "LightSource",
    0x9209 => "Flash",
    0x920A => "FocalLength",
    0x927c => "MakerNote",
    0x9286 => "UserComment",
    0xA000 => "FlashPixVersion",
    0xA001 => "ColorSpace",
    0xA002 => "EXIFImageWidth",
    0xA003 => "EXIFImageLength",
    0xA005 => "InteroperabilityOffset",
    0xA300 => "FileSource",
    0xA301 => "SceneType",
    0xA401 => "CustomRendered",
    0xA402 => "ExposureMode",
    0xA403 => "WhiteBalance",
    0xA404 => "DigitalZoomRatio",
    0xA405 => "FocalLength35",
    0xA406 => "SceneCaptureType",
    0xA407 => "GainControl",
    0xA408 => "Contrast",
    0xA409 => "Saturation",
    0xA40a => "Sharpness",
    0xA40c => "SubjectDistanceRange",
);

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
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
    return 1;
}

# =========================
sub handleExifMetaData {
    my ($args) = @_;
    %tags = ();

    my $filename = TWiki::Func::extractNameValuePair( $args, "file" );
    return "EXIF-ERROR-01" if ( $filename =~ /^\s*$/ );

    $debug = &TWiki::Func::getPreferencesFlag("EXIFMETADATAPLUGIN_DEBUG");

    my $tags_string = TWiki::Func::extractNameValuePair( $args, "tags" );
    if ( $tags_string eq "" ) {
        foreach my $myKey ( keys %defaulttag ) {
            $tags{$myKey} = "selected";
        }
    }
    else {
        if ( $tags_string eq "all" ) {
            foreach my $mysKey ( keys %supported_tags ) {
                $tags{$mysKey} = "selected";
            }
        }
        else {
            $tags{$+} = "selected"
              while $tags_string =~
                  m{"([^\"\\]*(?:\\.[^\"\\]*)*)",? |  ([^,]+),? | ,}gx;
            $tags{undef} = "end" if substr( $tags_string, -1, 1 ) eq ',';
        }
    }

    my $exif = "";

    my ( $meta, $page ) = &TWiki::Func::readTopic( $web, $topic );
    my @attachments = $meta->find('FILEATTACHMENT');

    foreach my $a (@attachments) {
        $a->{humanReadableSize} = sprintf( "%dk", $a->{size} / 1024 );
        my $afile = &TWiki::Func::getPubDir() . "/$web/$topic/$a->{name}";
        my $f     = substr( $afile, length($afile) - length($filename),
            length($filename) );
        if ( $f eq $filename ) {
            if ($debug) {
                &TWiki::Func::writeDebug(
                    "ExifMetaDataPlugin $VERSION - read $afile");
            }
            open( IN, $afile );
            binmode IN;

            while ( !eof(IN) ) {
                my $ch;
                if ( !read( IN, $ch, 1 ) ) {
                    close IN;
                    return "EXIF-ERROR-02";
                }
                if ( ord($ch) != 0xff ) {
                    close IN;
                    return "EXIF-ERROR-03";
                }

                my $marker = '';
                if ( !read( IN, $marker, 1 ) ) {
                    close IN;
                    return $exif;
                }
                if ( $marker eq $jpeg_markers{SOI} ) {

                    #&TWiki::Func::writeDebug( "SOI" );
                }
                elsif ( $marker eq $jpeg_markers{EOI} ) {

                    #&TWiki::Func::writeDebug( "EOT" );
                }
                else {
                    my ( $msb, $lsb, $data, $size );
                    if ( !read( IN, $msb, 1 ) ) {
                        close IN;
                        return "EXIF-ERROR-07";
                    }
                    if ( !read( IN, $lsb, 1 ) ) {
                        close IN;
                        return "EXIF-ERROR-07";
                    }
                    $size = 256 * ord($msb) + ord($lsb);
                    if ( read( IN, $data, $size - 2 ) != $size - 2 ) {
                        close IN;
                        return "EXIF-ERROR-07";
                    }
                    if ( $marker eq $jpeg_markers{APP1} ) {

                        # APP1 block contains the EXIF data
                        #&TWiki::Func::writeDebug( "APP1" );
                        $exif = $exif . fexif($data);
                        close IN;
                        return $exif;
                    }
                    elsif ( $marker eq $jpeg_markers{DQT} ) {

                        #&TWiki::Func::writeDebug( "DQT" );
                    }
                    elsif ( $marker eq $jpeg_markers{SOF0} ) {

                        #&TWiki::Func::writeDebug( "SOF0" );
                    }
                    elsif ( $marker eq $jpeg_markers{DHT} ) {

                        #&TWiki::Func::writeDebug( "DHT" );
                    }
                    elsif ( $marker eq $jpeg_markers{SOS} ) {

                        #&TWiki::Func::writeDebug( "SOS" );
                        close IN;
                        return $exif;
                    }
                    else {

                        #&TWiki::Func::writeDebug( "unknown marker" );
                    }
                }
            }
            close IN;
        }
    }
    return "EXIF-ERROR-02";
}

# =========================
# Extract EXIF (APP1)
sub fexif {
    my ($data) = @_;
    my $sda = "";
    my $header = substr( $data, 0, 6 );
    if ( $header ne "Exif\0\0" ) {
        return "EXIF-ERROR-04";
    }
    $data = substr( $data, 6 );
    if ( substr( $data, 0, 2 ) eq 'II' ) {
        $intelAlignment = 1;
    }
    elsif ( substr( $data, 0, 2 ) eq 'MM' ) {
        $intelAlignment = 0;
    }
    else {
        return "EXIF-ERROR-05";
    }
    if ( readShort( $data, 2 ) != 0x002a ) {
        return "EXIF-ERROR-06";
    }
    my $offset = readLong( $data, 4 );
    my $numEntries = readShort( $data, $offset );
    $offset += 2;

    my $i;
    for ( $i = 0 ; $i < $numEntries ; $i++ ) {
        my $entry = substr( $data, $offset + 12 * $i, 12 );
        my $tag    = readShort( $entry, 0 );
        my $format = readShort( $entry, 2 );
        my $components = readLong( $entry, 4 );
        my $offset     = readLong( $entry, 8 );
        my $value =
          readIFDEntry( $data, $format, $components, $offset, $entry );
        if ( $supported_tags{$tag} ) {
            if ( $tags{$tag} ) {
                my $svalue = '';
                if ( $supported_tags{$tag} eq "string" ) {
                    $svalue = $value;
                }
                else {
                    $svalue = getNum( $tag, $value );
                }
                if ( $sda eq "" ) {
                    $sda = $svalue;
                }
                else {
                    $sda = $sda . ", " . $svalue;
                }
            }
        }
        if ($debug) {
            my $ts = sprintf( "TAG=0x%x", $tag );
            &TWiki::Func::writeDebug("$ts $value");
        }

        # continue with sub tags
        if ( $tagid{$tag} eq "EXIFSubIFD" ) {
            my $exsubstr = fexifSUB( $data, $offset );
            if ( $exsubstr ne "" ) {
                if ( $sda eq "" ) {
                    $sda = $exsubstr;
                }
                else {
                    $sda = $sda . ", " . $exsubstr;
                }
            }
        }
    }
    return $sda;
}

# =========================
sub getNum {
    my ( $tag, $value ) = @_;
    if ( $tag == 0x829a ) {
        if ( $value >= 1 ) {
            return $value . " sec";
        }
        return sprintf( "1/%.0f sec", 1 / $value );
    }
    if ( $tag == 0x829D ) {
        return "f" . $value;
    }
    if ( $tag == 0x8827 ) {
        return "ISO" . $value;
    }
    if ( $tag == 0x920A ) {
        return sprintf( "%.0fmm", $value );
    }
    return "";
}

# =========================
sub fexifSUB {
    my ( $data, $offset ) = @_;
    my $sdb = "";
    my $numEntries = readShort( $data, $offset );
    $offset += 2;
    my $i;
    for ( $i = 0 ; $i < $numEntries ; $i++ ) {
        my $entry = substr( $data, $offset + 12 * $i, 12 );
        my $tag    = readShort( $entry, 0 );
        my $format = readShort( $entry, 2 );
        my $components = readLong( $entry, 4 );
        my $offset     = readLong( $entry, 8 );
        my $value      = '';

        if ( $supported_tags{$tag} ) {
            if ( $tag == 0x927c ) {
                makerNote( $data, $offset );
            }
            else {

                # other tags should be standard IFD
                $value =
                  readIFDEntry( $data, $format, $components, $offset, $entry );
            }
            if ( $tags{$tag} ) {
                my $xvalue = '';

                if ( $supported_tags{$tag} eq "string" ) {
                    $xvalue = $value;
                }
                else {
                    $xvalue = getNum( $tag, $value );
                }
                if ( $sdb eq "" ) {
                    $sdb = $xvalue;
                }
                else {
                    $sdb = $sdb . ", " . $xvalue;
                }
            }
        }
        if ($debug) {
            my $ts = sprintf( "TAG=0x%x", $tag );
            &TWiki::Func::writeDebug("$ts $value");
        }
    }
    return $sdb;
}

# =========================
# read formatted IFD entry
sub readIFDEntry {
    my ( $data, $format, $components, $offset, $entry ) = @_;
    if ( $format == 2 ) {
        if ( length($data) < $offset ) {
            &TWiki::Func::writeDebug("# oops, non standard IFD entry");
            return "";
        }

        # ASCII string
        my $value = substr( $data, $offset, $components );
        $value =~ s/\0+$//;    # remove trailing NULL chars
        return $value;
    }
    elsif ( $format == 3 ) {
        if ( $components == 2 ) {

            # two components and a short int - probably a pair of values
            my $v1 = readShort( $entry, 8,  2 );
            my $v2 = readShort( $entry, 10, 2 );
            return "$v1,$v2";
        }

        # Unsigned short
        if ( !$intelAlignment ) {
            $offset = 0xffff & ( $offset >> 16 );
        }
        return $offset;
    }
    elsif ( $format == 4 ) {

        # Unsigned long
        return $offset;
    }
    elsif ( $format == 5 ) {

        # Unsigned rational
        my $numerator   = readLong( $data, $offset );
        my $denominator = readLong( $data, $offset + 4 );
        if ($denominator) {

            # return "$numerator/$denominator";
            return $numerator / $denominator;
        }
    }
    elsif ( $format == 10 ) {

        # Signed rational
        my $numerator = readLong( $data, $offset );
        $numerator -= 2**32 if ( $numerator > 2**31 );
        my $denominator = readLong( $data, $offset + 4 );
        if ($denominator) {

            # return "$numerator/$denominator";
            return $numerator / $denominator;
        }
    }
    elsif ( $format == 7 ) {
        if ( $components == 4 ) {
            my @v = unpack( "c*", substr( $entry, 8, 4 ) );
            return join( ",", @v );
        }
        if ( length($data) < $offset ) {
            &TWiki::Func::writeDebug("# oops, non standard IFD entry");
            return "";
        }
        if ( substr( $data, $offset, 5 ) eq "ASCII" ) {
            my $value = substr( $data, $offset + 8, $components - 8 );
            $value =~ s/\0+$//;
            return $value;
        }

        # return $offset;
        return "";
    }
    elsif ( $format == 8 ) {

        # signed short
        return $offset;
    }
    else {
        return 0;
    }
}

# =========================
sub makerNote {
    my ( $data, $offset ) = @_;
    my $numEntries = readShort( $data, $offset );
    $offset += 2;
    my $i;
    for ( $i = 0 ; $i < $numEntries ; $i++ ) {

    }
}

# =========================
# read 2-byte short, byte aligned according to $intelAlignment
sub readShort {
    my ( $data, $offset ) = @_;
    return "readShort: end of string reached" if length($data) < $offset + 2;
    my $ch1 = ord( substr( $data, $offset++, 1 ) );
    my $ch2 = ord( substr( $data, $offset++, 1 ) );
    if ($intelAlignment) {
        return $ch1 + 256 * $ch2;
    }
    return $ch2 + 256 * $ch1;
}

# =========================
# read 4-byte long, byte aligned according to $intelAlignment
sub readLong {
    my ( $data, $offset ) = @_;
    return "readLong: end of string reached" if length($data) < $offset + 4;
    my $ch1 = ord( substr( $data, $offset++, 1 ) );
    my $ch2 = ord( substr( $data, $offset++, 1 ) );
    my $ch3 = ord( substr( $data, $offset++, 1 ) );
    my $ch4 = ord( substr( $data, $offset++, 1 ) );
    if ($intelAlignment) {
        return ( ( ( ( $ch4 * 256 ) + $ch3 ) * 256 ) + $ch2 ) * 256 + $ch1;
    }
    return ( ( ( ( $ch1 * 256 ) + $ch2 ) * 256 ) + $ch3 ) * 256 + $ch4;
}

# =========================
sub commonTagsHandler {
    $_[0] =~ s/%EXIFMETADATA%/&handleExifMetaData()/geo;
    $_[0] =~ s/%EXIFMETADATA{(.*?)}%/&handleExifMetaData($1)/geo;
}

# =========================

1;
