# Copyright (C) 2005-2009 Crawford Currie, http://c-dot.co.uk
# Copyright (C) 2006 Martin Cleaver, http://www.cleaver.org
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
# driver for writing html output to and ftp server, for hosting purposes
# adds sitemap.xml, google site verification file, and alias from
# index.html to WebHome.html (or other user specified default).
# I'd love to use LWP, but it tells me "400 Library does not
# allow method POST for 'ftp:' URLs"
# TODO: clean up ftp site, removing/archiving/backing up old version

package Foswiki::Plugins::PublishPlugin::ftp;

use strict;

# Inherit from file backend; we use the local copy as the cache for
# uploading from
use Foswiki::Plugins::PublishPlugin::file;
our @ISA = ('Foswiki::Plugins::PublishPlugin::file');

use File::Temp qw(:seekable);
use File::Spec;

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);

    $this->{params}->{fastupload} ||= 0;
    if ( $this->{params}->{destinationftpserver} ) {
        if ( $this->{params}->{destinationftppath} =~ /^\/?(.*)$/ ) {
            $this->{params}->{destinationftppath} = $1;
        }
        $this->{logger}->logInfo( '', "fastUpload = $this->{fastupload}" );
    }

    return $this;
}

sub param_schema {
    my $class = shift;
    return {
        destinationftpserver => {
            validator =>
              \&Foswiki::Plugins::PublishPlugin::Publisher::validateNonEmpty
        },
        destinationftppath => {
            validator =>
              \&Foswiki::Plugins::PublishPlugin::Publisher::validateNonEmpty
        },
        destinationftpusername => {
            validator =>
              \&Foswiki::Plugins::PublishPlugin::Publisher::validateNonEmpty
        },
        destinationftppassword => {
            validator =>
              \&Foswiki::Plugins::PublishPlugin::Publisher::validateNonEmpty
        },
        fastupload => { default => 1 },
        %{ $class->SUPER::param_schema() }
    };
}

sub addString {
    my ( $this, $string, $file ) = @_;

    $this->SUPER::addString( $string, $file );
    $this->_upload($file);
}

sub addFile {
    my ( $this, $from, $to ) = @_;
    $this->SUPER::addFile( $from, $to );

    $this->_upload($to);
}

sub _upload {
    my ( $this, $to ) = @_;

    return unless ( $this->{params}->{destinationftpserver} );

    my $localfilePath = "$this->{path}/$to";

    my $attempts = 0;
    my $ftp;
    while ( $attempts < 2 ) {
        eval {
            $ftp = $this->_ftpConnect();
            if ( $to =~ /^\/?(.*\/)([^\/]*)$/ ) {
                $ftp->mkdir( $1, 1 )
                  or die "Cannot create directory ", $ftp->message;
            }

            if ( $this->{params}->{fastupload} ) {

                # Calculate checksum for local file
                my $fh;
                open( $fh, '<', $localfilePath )
                  or die
                  "Failed to open $localfilePath for checksum computation: $!";
                local $/;
                binmode($fh);
                my $data = <$fh>;
                close($fh);
                my $localCS = Digest::MD5::md5($data);

                # Get checksum for remote file
                my $remoteCS = '';
                my $tmpFile =
                  new File::Temp( DIR => File::Spec->tmpdir(), UNLINK => 1 );
                if ( $ftp->get( "$to.md5", $tmpFile ) ) {

                    # SEEK_SET to pos 0
                    $tmpFile->seek( 0, 0 );
                    $remoteCS = <$tmpFile>;
                }

                if ( $localCS eq $remoteCS ) {

                    # Unchanged
                    $this->{logger}->logInfo( '',
"skipped uploading $to to $this->{destinationftpserver} (no changes)"
                    );
                    $attempts = 2;
                    return;
                }
                else {
                    my $fh;
                    open( $fh, '>', "$localfilePath.md5" )
                      or die "Failed to open $localfilePath.md5 for write: $!";
                    binmode($fh);
                    print $fh $localCS;
                    close($fh);

                    $ftp->put( "$localfilePath.md5", "$to.md5" )
                      or die "put failed ", $ftp->message;
                }
            }

            $ftp->put( $localfilePath, $to )
              or die "put failed ", $ftp->message;
            $this->{logger}->logInfo( "FTPed",
                "$to to $this->{params}->{destinationftpserver}" );
            $attempts = 2;
        };

        if ($@) {

            # Got an error; try restarting the session a couple of times
            # before giving up
            $this->{logger}->logError( "FTP ERROR: " . $@ );
            if ( ++$attempts == 2 ) {
                $this->{logger}->logError("Giving up on $to");
                return;
            }
            $this->{logger}->logInfo( '', "...retrying in 30s)" );
            eval { $ftp->quit(); };
            $this->{ftp_interface} = undef;
            sleep(30);
        }
    }
}

sub _ftpConnect {
    my $this = shift;

    if ( !$this->{ftp_interface} ) {
        require Net::FTP;
        my $ftp = Net::FTP->new(
            $this->{params}->{destinationftpserver},
            Debug   => 1,
            Timeout => 30,
            Passive => 1
          )
          or die
          "Cannot connect to $this->{params}->{destinationftpserver}: $@";
        $ftp->login(
            $this->{params}->{destinationftpusername},
            $this->{params}->{destinationftppassword}
        ) or die "Cannot login ", $ftp->message;

        $ftp->binary();

        if ( $this->{params}->{destinationftppath} ne '' ) {
            $ftp->mkdir( $this->{params}->{destinationftppath}, 1 );
            $ftp->cwd( $this->{params}->{destinationftppath} )
              or die "Cannot change working directory ", $ftp->message;
        }
        $this->{ftp_interface} = $ftp;
    }
    return $this->{ftp_interface};
}

sub close {
    my $this = shift;

    my $landed = $this->SUPER::close();

    if ( $this->{params}->{destinationftpserver} ) {
        $landed = $this->{params}->{destinationftpserver};
        $this->{ftp_interface}->quit() if $this->{ftp_interface};
        $this->{ftp_interface} = undef;
    }

    return $landed;
}

1;

