# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
# Copyright (C) Vito Miliano, ZacharyHamm, JohannesMartin, DiabJerius
# Copyright (C) 2004 Martin Cleaver, Martin.Cleaver@BCS.org.uk
# Copyright (C) 2009 - 2011 Andrew Jones, http://andrew-jones.com
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

package Foswiki::Plugins::BatchUploadPlugin;

require Foswiki::Func;
require Foswiki::Plugins;

use strict;
use Archive::Zip qw(:ERROR_CODES :CONSTANTS :PKZIP_CONSTANTS);
use IO::File ();
use warnings;
use diagnostics;

use vars qw(
  $debug $pluginEnabled $stack $stackDepth $MAX_STACK_DEPTH
  $importFileComments $fileCommentFlags
);

our $VERSION = '$Rev$';
our $RELEASE = '1.3';
our $SHORTDESCRIPTION =
  'Attach multiple files at once by uploading a zip archive';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName        = 'BatchUploadPlugin';

BEGIN {

    # keep track of depth level of nested zips
    $stack = ();

    $stackDepth = 0;

    # maximum level of recursion of zips in zips
    $MAX_STACK_DEPTH = 30;
}

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # Get plugin debug flag
    $debug = $Foswiki::cfg{Plugins}{$pluginName}{Debug} || 0;

    $pluginEnabled = Foswiki::Func::getPluginPreferencesValue("ENABLED") || 0;

    $importFileComments =
      Foswiki::Func::getPluginPreferencesFlag("IMPORTFILECOMMENTS") || 1;
    $fileCommentFlags =
      Foswiki::Func::getPluginPreferencesFlag("FILECOMMENTFLAGS") || 1;

    # Plugin correctly initialized
    Foswiki::Func::writeDebug(
        "- ${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

=pod

Store callback called before the attachment is further processed.
Preliminary attempt to tackle nested zips - does not actually work yet. Each time we fall through beforeUploadHandler to the actual attaching, other
attachments get lost.

=cut

sub beforeUploadHandler {
    my ( $attrHashRef, $meta ) = @_;
    my $topic = $meta->topic();
    my $web   = $meta->web();

    Foswiki::Func::writeDebug(
"- ${pluginName}::beforeAttachmentSaveHandler( $_[2].$_[1] - attachment: $attrHashRef->{attachment})"
    ) if $debug;

    my $cgiQuery = Foswiki::Func::getCgiQuery();
    return if ( !$pluginEnabled );

    my $batchupload = $cgiQuery->param('batchupload') || '';

    return
      if ( ( $Foswiki::cfg{Plugins}{$pluginName}{usercontrol} )
        && ( $batchupload ne 'on' ) );

    my $attachmentName = $attrHashRef->{attachment};

    return if ( !isZip($attachmentName) );

    return if ( $stackDepth > $MAX_STACK_DEPTH );

    $stack->{$attachmentName} = $stackDepth;
    Foswiki::Func::writeDebug(
        "$pluginName - $attachmentName has stack depth $stackDepth")
      if $debug;
    $stackDepth++;

    my $result = updateAttachment(
        $web,
        $topic,
        $attachmentName,
        $attrHashRef->{"stream"},
        $attrHashRef->{"comment"},
        $cgiQuery->param('hidefile')   || '',
        $cgiQuery->param('createlink') || ''
    );

    if ($result) {
        if ( $stack->{$attachmentName} == 0 ) {
            Foswiki::Func::writeDebug(
                "$pluginName - Result stack: " . $stack->{$attachmentName} )
              if $debug;
            my $url = Foswiki::Func::getViewUrl( $web, $topic );

            Foswiki::Func::redirectCgiQuery( undef, $url );

# SMELL: bit of a hack?
# user won't see this, but if left out the zip file will be attached, overwriting the unzipped files
#exit 0; this just returns a blank page to the user, not very good...
            throw Error::Simple('Do not save zip file!')
              ; # this seems to work fine, the user gets returned to their viewed page and the unzipped files do not get overwritten. Presumably it is caught somewhere higher up.
        }
    }

}

=pod

Checks if a file is a zip file.
Returns true if the file has a zip extension, false if not.

=cut

sub isZip {
    my ($fileName) = @_;
    return $fileName =~ m/.zip$/;
}

=pod

Return: 1 if successful, 0 if not successful.

=cut

sub updateAttachment {

    my (
        $webName,
        $topic,
        $originalZipName,
        $zipArchive,    # stream
        $fileComment,
        $hideFlag,
        $linkFlag
    ) = @_;

    my ( $zip, %processedFiles, $tempDir );

    $zip =
      openZipSanityCheck( $zipArchive, $webName, $topic, $originalZipName );
    unless ( ref $zip ) {
        die "Problem with " . $zip;
    }

    # Create temp directory to unzip files into
    # the unzipped files will be attached afterwards
    my $workArea = Foswiki::Func::getWorkArea($pluginName);

    # Temp file in workarea
    $tempDir = $workArea . '/' . int( rand(1000000000) );

    mkdir($tempDir);

    # Change to the new directory: on some systems with some versions of
    # Archive::Zip extractMemberWithoutPaths() ignores the path given to it and
    # tries to just write the file to the current directory.
    chdir($tempDir);

    Foswiki::Func::writeDebug("$pluginName - Created temp dir $tempDir")
      if $debug;

    %processedFiles = doUnzip( $tempDir, $zip );

    # Loop through processed files.
    foreach my $fileNameKey ( sort keys %processedFiles ) {
        my $fileName    = $processedFiles{$fileNameKey}->{name};
        my $tmpFilename = $fileNameKey;

        my ( $fileSize, $fileUser, $fileDate, $fileVersion ) = "";

        # get file size
        my @stats = stat $tmpFilename;
        $fileSize = $stats[7];

        # use current time for upload
        $fileDate = time();

# use the upload form values only if these settings have not been specified in the zip file comment
        my $hideFile = $processedFiles{$fileNameKey}->{hide}       || $hideFlag;
        my $linkFile = $processedFiles{$fileNameKey}->{createlink} || $linkFlag;

# attachment inherits the zip file comment; if none given, the the upload form comment is used
# (last resort is a hardcoded, non-localized comment)
        my $tmpFileComment = $processedFiles{$fileNameKey}->{comment};
        $tmpFileComment = $fileComment unless $tmpFileComment;
        $tmpFileComment = "Extracted from $originalZipName"
          unless $tmpFileComment;

        Foswiki::Func::writeDebug(
"$pluginName - Trying to attach: fileName=$fileName, fileSize=$fileSize, fileDate=$fileDate, fileComment=$tmpFileComment, tmpFilename=$tmpFilename"
        ) if $debug;

        Foswiki::Func::saveAttachment(
            $webName, $topic,
            my $result = $fileName,
            {
                file       => $fileName,
                filepath   => $tmpFilename,
                hide       => $hideFile,
                createlink => $linkFile,
                filesize   => $fileSize,
                filedate   => $fileDate,
                comment    => $tmpFileComment
            }
        );

        if ( $result eq $fileName ) {
            Foswiki::Func::writeDebug(
                "$pluginName - Attaching $fileName went OK")
              if $debug;
        }
        else {
            Foswiki::Func::writeDebug(
                "$pluginName - An error occurred while attaching $fileName")
              if $debug;
            die "An error occurred while attaching $fileName";
        }

        # remove temp file
        unlink($tmpFilename);
    }

    # remove temp dir
    rmdir($tempDir);

    return 1;
}

=pod

changed to work around a race condition where a symlink could be made in the 
temp directory pointing to a file writable by the CGI and then a zip uploaded 
with that filename, also solves the problem if two people are uploading zips 
with some identical filenames.
=cut

sub doUnzip {

    my ( $tempDir, $zip ) = @_;

    my (
        @memberNames, $fileName, $fileComment, $hideFile, $linkFile,
        $member,      $buffer,   %good,        $zipRet
    );

    @memberNames = $zip->memberNames();

    foreach $fileName ( sort @memberNames ) {
        $member = $zip->memberNamed($fileName);
        next if $member->isDirectory();
        $member->unixFileAttributes(0600);

        $fileName =~ /\/?(.*\/)?(.+)/;
        $fileName = $2;

        # Make filename safe:
        my $origFileName;
        ( $fileName, $origFileName ) =
          Foswiki::Sandbox::sanitizeAttachmentName($fileName);

        $hideFile = undef;
        $linkFile = undef;
        if ( $importFileComments || $fileCommentFlags ) {

# determine file comment
# search comment for prefixes "-/+L", "-/+H" ((don't) insert link/hide attachment)
# NB we don't allow whitespace between flags, only last setting of each flag type counts
            $fileComment = $member->fileComment();
            if ( $fileCommentFlags
                && ( $fileComment =~ /^\s*([+-][hl])+(\s.+|$)/i ) )
            {
                $fileComment =~ s/^\s+//;
                while ( $fileComment =~ /^([+-][hl])(.*)$/i ) {
                    my $options = $1;
                    $fileComment = $2;

                    my $opval = substr( $options, 0, 1 );
                    $opval =~ tr/+-/10/;

                    my $opkey = uc( substr( $options, 1, 1 ) );
                    if ( $opkey eq "H" ) {
                        $hideFile = $opval;
                    }
                    else {
                        $linkFile = $opval;
                    }
                }
                $fileComment =~ s/^\s+//;
            }
            if ( !$importFileComments ) {
                $fileComment = undef;
            }

        }

        if ( $debug && ( $fileName ne $origFileName ) ) {
            Foswiki::Func::writeDebug(
                "$pluginName - Renamed file $origFileName to $fileName");
        }

        $zipRet =
          $zip->extractMemberWithoutPaths( $member, "$tempDir/$fileName" );
        if ( $zipRet == AZ_OK ) {
            $good{"$tempDir/$fileName"} = {
                name       => $fileName,
                comment    => $fileComment,
                hide       => $hideFile,
                createlink => $linkFile
            };
        }
        else {

            # FIXME: oops here
            Foswiki::Func::writeDebug(
"$pluginName - Something went wrong with uploading of zip file $fileName: $zipRet"
            ) if $debug;
        }
    }

    return %good;
}

=pod

Open a zip and perform a sanity check on it.
Returns the opened zip object (to be passed to doUnzip) on success,
a string saying the reason for failure.

=cut

sub openZipSanityCheck {

    my ( $archive, $webName, $topic, $realname ) = @_;
    my ( $lowerCase, $noSpaces, $noredirect ) = ( 0, 0, 0 );
    bless $archive, 'IO::File';   # needs to be seekable, so bless into IO::File
    my $zip = Archive::Zip->new();
    my ( @memberNames, $fileName, $member, %dupCheck, $sizeLimit );

    if ( $zip->readFromFileHandle($archive) != AZ_OK ) {
        return "Zip read error or not a zip file. " . $archive;
    }

    # Scan for duplicates
    @memberNames = $zip->memberNames();

    foreach $fileName (@memberNames) {
        $member = $zip->memberNamed($fileName);
        next if $member->isDirectory();

        $fileName =~ /\/?(.*\/)?(.+)/;
        $fileName = $2;

        if ($lowerCase) { $fileName = lc($fileName); }
        unless ($noSpaces) { $fileName =~ s/\s/_/g; }

        $fileName =~ s/$Foswiki::cfg{UploadFilter}/$1\.txt/gi;

        if ( defined $dupCheck{"$fileName"} ) {
            return "Duplicate file in archive " . $fileName . " in archive";
        }
        else {
            $dupCheck{"$fileName"} = $fileName;
        }
    }
    return $zip;
}

1;
