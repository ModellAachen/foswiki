# Plugin for TWiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009 Crawford Currie http://c-dot.co.uk
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
package TWiki::Plugins::MsOfficeAttachmentsAsHTMLPlugin;

use strict;
use TWiki::Sandbox;

our $VERSION = '$Rev$';
our $RELEASE = '3 Feb 2009';

my $pluginName = 'MsOfficeAttachmentsAsHTMLPlugin';
our $afterSaveHandlerSemaphore;

sub initPlugin {

    #my ( $topic, $web, $user, $installWeb ) = @_;
    undef $afterSaveHandlerSemaphore;
    return 1;
}

sub afterAttachmentSaveHandler {
    my ( $attachmentAttr, $topic, $web ) = @_;

    my $attachmentName = $attachmentAttr->{"attachment"};
    return unless ( $attachmentName =~ s/(.doc)$//i );
    my $ext = $1;

    # Convert to HTML

    my $htmlName = "$attachmentName.html";

    my $cmd = $TWiki::cfg{Plugins}{MsOfficeAttachmentsAsHTMLPlugin}{doc2html};

    my ( $data, $exit ) = $TWiki::sandbox->sysCommand(
        $cmd,
        ATTACHDIR => TWiki::Func::getPubDir() . "/$web/$topic",
        SRC  => TWiki::Func::getPubDir() . "/$web/$topic/$attachmentName$ext",
        DEST => "$attachmentName.html"
    );

    die "$cmd failed with exit code $exit: $data" if $exit;

    # Replace the topic text with an include of the attachment

    return unless TWiki::Func::getPreferencesFlag('REPLACE_WITH_ATTACHMENT');

    $afterSaveHandlerSemaphore = $attachmentName;
}

sub afterSaveHandler {
    return unless $afterSaveHandlerSemaphore;

    my ( $text, $topic, $web, $error, $meta ) = @_;

    my $attachmentName = $afterSaveHandlerSemaphore;
    undef $afterSaveHandlerSemaphore;

    $text = TWiki::Func::getPreferencesValue("\U$pluginName\E_REPLACEMENTNOTE")
      || <<'DEFAULT';
This text was automatically generated from the attachment $attachment
%INCLUDE{%ATTACHURL%/$convertedAttachmentPath}%
DEFAULT

    $text =~ s/\$attachment/$attachmentName.doc/;
    $text =~ s/\$convertedAttachmentPath/$attachmentName.html/;

    TWiki::Func::saveTopicText( $web, $topic, $text );

    return;
}

1;
