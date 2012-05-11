#
# Copyright (C) 2005 Crawford Currie, http://c-dot.co.uk
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
# File writer module for PublishPlugin
#
package Foswiki::Plugins::PublishPlugin::file;

use strict;

use Foswiki::Plugins::PublishPlugin::BackEnd;
our @ISA = ('Foswiki::Plugins::PublishPlugin::BackEnd');

use File::Copy ();
use File::Path ();

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);

    my $oldmask = umask( oct(777) - $Foswiki::cfg{RCS}{dirPermission} );
    $this->{params}->{outfile} ||= 'file';

    if ( -e "$this->{path}/$this->{params}->{outfile}" ) {
        File::Path::rmtree("$this->{path}/$this->{params}->{outfile}");
    }
    eval { File::Path::mkpath( $this->{path} ); };
    umask($oldmask);
    die $@ if $@;

    return $this;
}

sub param_schema {
    my $class = shift;
    return {
        outfile => {
            default => 'file',
            validator =>
              \&Foswiki::Plugins::PublishPlugin::Publisher::validateFilename
        },
        googlefile => {
            default => '',
            validator =>
              \&Foswiki::Plugins::PublishPlugin::Publisher::validateFilenameList
        },
        defaultpage => { default => 'WebHome' },
        %{ $class->SUPER::param_schema }
    };
}

sub addDirectory {
    my ( $this, $name ) = @_;

    my $oldmask = umask( oct(777) - $Foswiki::cfg{RCS}{dirPermission} );
    eval { File::Path::mkpath("$this->{path}$this->{params}->{outfile}/$name") };
    $this->{logger}->logError($@) if $@;
    umask($oldmask);
    push( @{ $this->{dirs} }, $name );
}

sub addString {
    my ( $this, $string, $file ) = @_;

    my $fh;
    my $d = $file;
    if ( $d =~ m#(.*)/[^/]*$# ) {
        File::Path::mkpath("$this->{path}$this->{params}->{outfile}/$1");
    }
    if ( open( $fh, '>', "$this->{path}$this->{params}->{outfile}/$file" ) ) {
        binmode($fh);
        print $fh $string;
        close($fh);
        push( @{ $this->{files} }, $file );
    }
    else {
        $this->{logger}->logError("Cannot write $file: $!");
    }

    if ( $file =~ m#([^/\.]*)\.html?$# ) {
        my $topic = $1;
        push( @{ $this->{urls} }, $file );

        unless ( $topic eq 'default' || $topic eq 'index' ) {

            # write link from index.html to actual topic
            my $link = "<a href='$file'>$file</a><br>";
            $this->_catString( $link, 'default.htm' );
            $this->_catString( $link, 'index.html' );
            $this->{logger}->logInfo( $topic, '(default.htm, index.html)' );
        }
    }
}

sub _catString {
    my ( $this, $string, $file ) = @_;

    my $data;
    my $fh;
    if ( open( $fh, '<', "$this->{path}$this->{params}->{outfile}/$file" ) ) {
        local $/ = undef;
        $data = <$fh> . "\n" . $string;
        close($fh);
    }
    else {
        $data = $string;
    }
    $this->addString( $data, $file );
}

sub addFile {
    my ( $this, $from, $to ) = @_;
    my $dest = "$this->{path}$this->{params}->{outfile}/$to";
    File::Copy::copy( $from, $dest )
      or $this->{logger}->logError("Cannot copy $from to $dest: $!");
    my @stat = stat($from);
    $this->{logger}->logError("Unable to stat $from") unless @stat;
    utime( @stat[ 8, 9 ], $dest );
    push( @{ $this->{files} }, $to );
}

sub close {
    my $this = shift;

    # write sitemap.xml
    my $sitemap = $this->_createSitemap( \@{ $this->{urls} } );
    $this->addString( $sitemap, 'sitemap.xml' );
    $this->{logger}->logInfo( '', 'Published sitemap.xml' );

    # write google verification files (comma seperated list)
    if ( $this->{params}->{googlefile} ) {
        my @files = split( /[,\s]+/, $this->{params}->{googlefile} );
        for my $file (@files) {
            my $simplehtml =
                '<html><title>' 
              . $file
              . '</title><body>just for google</body></html>';
            $this->addString( $simplehtml, $file );
            $this->{logger}->logInfo( '', 'Published googlefile : ' . $file );
        }
    }

    return $this->{params}->{outfile};
}

sub _createSitemap {
    my $this     = shift;
    my $filesRef = shift;       #( \@{$this->{files}} )
    my $map      = << 'HERE';
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.google.com/schemas/sitemap/0.84">
%URLS%
</urlset>
HERE

    my $topicTemplatePre  = "<url>\n<loc>";
    my $topicTemplatePost = "</loc>\n</url>";

    my $urls = join(
        "\n",
        map {
                "$topicTemplatePre$this->{params}->{relativeurl}"
              . "$_$topicTemplatePost\n"
          } @$filesRef
    );

    $map =~ s/%URLS%/$urls/;

    return $map;
}

1;

