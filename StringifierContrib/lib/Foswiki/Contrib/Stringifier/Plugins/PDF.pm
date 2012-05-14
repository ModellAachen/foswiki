# Copyright (C) 2009-2011 Foswiki Contributors
#
# For licensing info read LICENSE file in the Foswiki root.
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

package Foswiki::Contrib::Stringifier::Plugins::PDF;
use Foswiki::Contrib::Stringifier::Base ();
our @ISA = qw( Foswiki::Contrib::Stringifier::Base );
use Foswiki::Contrib::Stringifier ();

my $pdftotext = $Foswiki::cfg{StringifierContrib}{pdftotextCmd} || 'pdftotext';

# Only if pdftotext exists, I register myself.
if (__PACKAGE__->_programExists($pdftotext)){
    __PACKAGE__->register_handler("application/pdf", ".pdf");
}

sub stringForFile {
  my ($self, $filename) = @_;

  my $cmd = $pdftotext . ' %FILENAME|F% - -q -nopgbrk -enc Latin1'; # SMELL: not using UTF-8 here as pdftotext does not speak utf-8 fluently
  my ($text, $exit) = Foswiki::Sandbox->sysCommand($cmd, FILENAME => $filename);

  return '' unless ($exit == 0);

  $text = $self->decode($text, $Foswiki::cfg{StringifierContrib}{CharSet}{pdftotext} || 'iso-8859-1');
  $text = $self->encode($text);
  $text =~ s///g; # remove any page break leftover

  return $text;
}

1;
