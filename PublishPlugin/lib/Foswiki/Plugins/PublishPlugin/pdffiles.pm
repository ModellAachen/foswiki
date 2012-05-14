# Copyright (C) 2005 Crawford Currie, http://c-dot.co.uk
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
# driver for writing individual pdfs for PublishPlugin

use strict;

package Foswiki::Plugins::PublishPlugin::pdffiles;

use Error qw( :try );
use Foswiki::Plugins::PublishPlugin::file;
use Foswiki::Plugins::PublishPlugin::PDFWriter;
my $debug = 1;
@Foswiki::Plugins::PublishPlugin::pdffiles::ISA = qw(
  Foswiki::Plugins::PublishPlugin::file
  Foswiki::Plugins::PublishPlugin::PDFWriter);

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    return $this;
}

sub addString {
    my ( $this, $string, $file ) = @_;
    $this->SUPER::addString( $string, $file );
    $this->writePdf( "$this->{path}/$file.pdf", $file, $debug )
      if ( $file =~ /\.html$/ );
}

sub addFile {
    my ( $this, $from, $to ) = @_;
    $this->SUPER::addFile( $from, $to );
    $this->writePdf( "$this->{path}/$to.pdf", $to, $debug )
      if ( $to =~ /\.html$/ );
}

sub close {
    my $this = shift;
}

1;

