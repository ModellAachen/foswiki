# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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
package Foswiki::Plugins::MsOfficeAttachmentsAsHTMLPlugin;

use strict;
use Foswiki::Sandbox;

our $VERSION = '$Rev$';
our $RELEASE = '20 Apr 2009';

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
    return unless ( $attachmentName =~ s/(.docx?)$//i );
    my $ext = $1;

    # Convert to HTML

    my $htmlName = "$attachmentName.html";

    my $cmd = $Foswiki::cfg{Plugins}{MsOfficeAttachmentsAsHTMLPlugin}{doc2html};

    my ( $data, $exit ) = Foswiki::Sandbox::sysCommand(
        undef, $cmd,
        ATTACHDIR => Foswiki::Func::getPubDir() . "/$web/$topic",
        SRC  => Foswiki::Func::getPubDir() . "/$web/$topic/$attachmentName$ext",
        DEST => $htmlName
    );

    die "$cmd failed with exit code $exit: $data" if $exit;

    # Process the attachment
    if ( defined $Foswiki::cfg{Plugins}{$pluginName}{filters}
        && scalar( @{ $Foswiki::cfg{Plugins}{$pluginName}{filters} } ) )
    {
        my $text =
          Foswiki::Func::readAttachment( $web, $topic, "$attachmentName.html" );
        foreach my $rule ( @{ $Foswiki::cfg{Plugins}{$pluginName}{filters} } ) {
            $rule = Foswiki::Func::expandCommonVariables( $rule, $topic, $web );
            eval '$text=~' . $rule;
        }
        my $tmp = Foswiki::Func::getWorkArea($pluginName) . '/' . $htmlName;
        my $fh;
        open( $fh, '>', $tmp ) || die $!;
        print $fh $text;
        close($fh);
        Foswiki::Func::saveAttachment( $web, $topic, $htmlName,
            { file => $tmp } );
        unlink($tmp);
    }

    # Replace the topic text with an include of the attachment

    return unless Foswiki::Func::getPreferencesFlag('REPLACE_WITH_ATTACHMENT');

    $afterSaveHandlerSemaphore = $attachmentName;
}

sub afterSaveHandler {
    return unless $afterSaveHandlerSemaphore;

    my ( $text, $topic, $web, $error, $meta ) = @_;

    my $attachmentName = $afterSaveHandlerSemaphore;
    undef $afterSaveHandlerSemaphore;

    $text =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_REPLACEMENTNOTE")
      || <<'DEFAULT';
This text was automatically generated from the attachment $attachment
%INCLUDE{%ATTACHURL%/$convertedAttachmentPath}%
DEFAULT

    $text =~ s/\$attachment/$attachmentName.doc/;
    $text =~ s/\$convertedAttachmentPath/$attachmentName.html/;

    Foswiki::Func::saveTopicText( $web, $topic, $text );

    return;
}

1;
