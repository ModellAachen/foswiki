#! perl -w
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2003 Martin@Cleaver.org
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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

# NB. requires a modified version of Store.pm and Func.pm to provide this:
#   beforeAttachmentSaveHandler       ( $attachRefHash, $topic, $web ) 1.010?
# also requires Image::Magick Perl libs and imagemagick installed.
use strict;

# =========================
package TWiki::Plugins::MaxImageSizePlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $pluginName
  $debug $geometryString $patternMatch
);

$VERSION    = '1.010';
$pluginName = 'MaxImageSizePlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    # Get plugin preferences, the variable defined by:
    # i.e. http://studio.imagemagick.org/www/Magick++/Geometry.html
    $geometryString = &TWiki::Prefs::getPreferencesValue("RESIZE_GEOMETRY")
      || "x480>";

#$patternMatch = &TWiki::Prefs::getPreferencesValue( "PATTERN_MATCH" ) || "jpg";

    # Plugin correctly initialized
    writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK");
    return 1;
}

# =========================
sub beforeAttachmentSaveHandler {
### my ( $attachmentAttr, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    my $attachmentAttr = $_[0];
    my $topic          = $_[1];
    my $web            = $_[2];

    writeDebug("- ${pluginName}::beforeSaveHandler( $_[2].$_[1])");
    writeDebug("attributes: $attachmentAttr");
    foreach my $attribute ( keys %$attachmentAttr ) {
        writeDebug( "$attribute = " . $attachmentAttr->{$attribute} );
    }

    my $attachmentName = $attachmentAttr->{"attachment"};
    writeDebug("Hmm. Got a $attachmentName");

    unless ( ( $attachmentName =~ m/.jpg$/ )
        || ( $attachmentName =~ m/.JPG$/ ) )
    {
        writeDebug("Not resizing - this does not end in jpg or JPG\n");
        return;
    }

    writeDebug("Resizing $attachmentName");
    eval {
        my $errors =
          resize( $attachmentAttr->{"tmpFilename"}, $geometryString );
        TWiki::Func::writeWarning(
            "$web.$topic " . $attachmentAttr->{"user"} . " " . $errors );
    };
    TWiki::Func::writeWarning("$! $@") if ($@);

    # Now, how do I give the user an error?
    $attachmentAttr->{"comment"} .= "Resized by $pluginName";

# This handler is called by TWiki::Store::saveAttachment just before the save action.

}

sub writeDebug {
    my ($s) = @_;
    TWiki::Func::writeDebug($s) if $debug;
}

sub resize {
    my ( $filename, $geometry ) = @_;
    my $errors = "";
    use Image::Magick;
    my ( $image, $x );
    $image = Image::Magick->new;
    $x     = $image->Read($filename);
    $errors .= $x;
    return $x if ($x);
    $x = $image->Resize( geometry => $geometry );
    return $x if ($x);
    $x = $image->Write($filename);
    return $x if ($x);
    return $errors;
}

# =========================

1;
