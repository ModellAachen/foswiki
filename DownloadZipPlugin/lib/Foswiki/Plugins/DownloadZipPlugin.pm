# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::DownloadZipPlugin

=cut

package Foswiki::Plugins::DownloadZipPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

our $VERSION           = '$Rev: 13286 $';
our $RELEASE           = '1.0.0';
our $SHORTDESCRIPTION  = 'Download all attachments at once in a zip archive.';
our $NO_PREFS_IN_TOPIC = 1;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    Foswiki::Func::registerTagHandler( 'DOWNLOADZIP',    \&_DOWNLOADZIP );
    Foswiki::Func::registerTagHandler( 'DOWNLOADWEBZIP', \&_DOWNLOADWEBZIP );
    Foswiki::Func::registerRESTHandler( 'zip',    \&restZip );
    Foswiki::Func::registerRESTHandler( 'webzip', \&restWebZip );

    # Plugin correctly initialized
    return 1;
}

sub _DOWNLOADZIP {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    return Foswiki::Func::getScriptUrl( $pluginName, "zip", "rest",
        topic => $theWeb . '.' . $theTopic );
}

sub _DOWNLOADWEBZIP {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    return Foswiki::Func::getScriptUrl( $pluginName, "webzip", "rest",
        topic => $theWeb . '.WebHome' );

    # SMELL: WebHome hardcoded
}

=pod

---++ restZip($session) -> $text

=cut

sub restZip {
    my ($session) = @_;

    my $filename =
      Foswiki::Sandbox::untaintUnchecked( $session->{'topicName'} . '.zip' );
    my $topicName = $session->{'topicName'};
    my $webName   = Foswiki::Sandbox::untaintUnchecked( $session->{'webName'} );
    my $dotWeb    = $webName;
    $dotWeb =~ s#/#.#g;
    my $slashWeb = $webName;
    $slashWeb =~ s#\.#/#g;

    my $tmpFilename =
      Foswiki::Func::getWorkArea($pluginName) . '/' . $dotWeb . '.' . $filename;
    my $attachDir =
      Foswiki::Sandbox::untaintUnchecked(
        Foswiki::Func::getPubDir() . '/' . $slashWeb . '/' . $topicName . '/' );

    use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
    my $zip = Archive::Zip->new();

    # read attachment filesnames from topic meta-data
    #
    my ( $meta, $text ) = Foswiki::Func::readTopic( $webName, $topicName );
    my @attachments = $meta->find('FILEATTACHMENT');
    foreach my $attachment (@attachments) {
        if ( -f $attachDir . $attachment->{name} ) {
            $zip->addFile( $attachDir . $attachment->{name},
                $attachment->{name} );
        }
    }

    # write back zip file
    #
    unless ( $zip->writeToFileNamed($tmpFilename) == AZ_OK ) {
        return "Cannot create zip file. \n\n";
    }

    # set http headers
    #
    print "Content-type: application/zip\n";
    print "Content-Disposition: attachment; filename=\"$filename\"\n\n";

    # read tmp zip file and transfer to browser
    #
    my $buffer;
    open( ZIP, $tmpFilename );
    print $buffer while ( read( ZIP, $buffer, 16384 ) );
    close(ZIP);
    unlink($tmpFilename);

    return 1;
}

=pod

---++ restWebZip($session) -> $text

=cut

sub restWebZip {
    my ($session) = @_;

    my $topicName = $session->{'topicName'};
    my $webName   = Foswiki::Sandbox::untaintUnchecked( $session->{'webName'} );
    my $dotWeb    = $webName;
    $dotWeb =~ s#/#.#g;
    my $slashWeb = $webName;
    $slashWeb =~ s#\.#/#g;
    my $filename = $dotWeb . '.zip';

    my $tmpFilename =
      Foswiki::Func::getWorkArea($pluginName) . '/' . $dotWeb . '.' . $filename;
    my $webDir = Foswiki::Func::getPubDir() . '/' . $slashWeb . '/';

    use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
    my $zip = Archive::Zip->new();

   # cycle through topiclist and read attachment filesnames from topic meta-data
   #
    my @topicList = Foswiki::Func::getTopicList($webName);
    foreach my $currentTopic (@topicList) {
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( $webName, $currentTopic );
        my @attachments = $meta->find('FILEATTACHMENT');
        foreach my $attachment (@attachments) {
            if ( -f $webDir . $currentTopic . '/' . $attachment->{name} ) {
                $zip->addFile(
                    $webDir . $currentTopic . '/' . $attachment->{name},
                    $currentTopic . '/' . $attachment->{name}
                );
            }
        }
    }

    # write back zip file
    #
    unless ( $zip->writeToFileNamed($tmpFilename) == AZ_OK ) {
        return "Cannot create zip file. \n\n";
    }

    # set http headers
    #
    print "Content-type: application/zip\n";
    print "Content-Disposition: attachment; filename=\"$filename\"\n\n";

    # read tmp zip file and transfer to browser
    #
    my $buffer;
    open( ZIP, $tmpFilename );
    print $buffer while ( read( ZIP, $buffer, 16384 ) );
    close(ZIP);
    unlink($tmpFilename);

    return 1;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: OliverKrueger

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
