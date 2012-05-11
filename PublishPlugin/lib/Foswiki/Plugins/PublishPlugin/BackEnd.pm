#
# Copyright (C) 2009 Crawford Currie, http://c-dot.co.uk
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

=begin TML

Abstract base class of back-end modules for !PublishPlugin.

This class defines the interface that must be implemented by back end
archive generators.

=cut

package Foswiki::Plugins::PublishPlugin::BackEnd;

=begin TML

---++ ClassMethod new($params, $path, $logger)

Construct a new back end.
   * =$params= ref to hash of param vals
   * =$path= - the target path of the publishing process
   * =$logger= - ref to an object that supports logWarn, logInfo and logError
     methods (see Publisher.pm)

=cut

sub new {
    my ( $class, $params, $path, $logger ) = @_;
    $path .= '/' unless $path =~ m#/$#;
    my $this = bless(
        {
            path   => $path,
            params => $params,
            logger => $logger
        },
        $class
    );
    return $this;
}

=begin TML

---++ ClassMethod param_schema -> \%schema
Get schema of query parameters, in the same format as Publisher.pm

=cut

sub param_schema {
    return { relativeurl => { default => '/' }, };
}

=begin TML

---++ ObjectMethod addDirectory($dir)

Add a directory to the archive. If it already exists, should not complain.

Errors should be logged to the logger.

=cut

sub addDirectory {
    my ( $this, $dir ) = @_;
}

=begin TML

---++ ObjectMethod addString($data, $to)

Add a block of $data to the archive by creating file =$to= and
writing the data to it.

Errors should be logged to the logger.

=cut

sub addString {
    my ( $this, $data, $to ) = @_;
}

=begin TML

---++ ObjectMethod addFile($from, $to)

Add =$from= to the archive with the path =$to=. =$from= and =$to= are paths.

Errors should be logged to the logger.

=cut

sub addFile {
    my ( $this, $from, $to ) = @_;
}

=begin TML

---++ ObjectMethod close() -> $landed

Close the archive, and return the path to the completed archive. This is a
path relative to the publish dir.

Errors should be logged to the logger.

=cut

sub close {
    my $this = shift;
    return $this->{path};
}

1;
