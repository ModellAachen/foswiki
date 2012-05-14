# Copyright (C) 2011 Foswiki Contributors
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


package Foswiki::Contrib::Stringifier::Plugins::ODT;
use Foswiki::Contrib::Stringifier::Base ();
our @ISA = qw( Foswiki::Contrib::Stringifier::Base );

my $odt2text = $Foswiki::cfg{StringifierContrib}{odt2txt} || 'odt2txt';

__PACKAGE__->register_handler("application/vnd.oasis.opendocument.text", ".odt");
__PACKAGE__->register_handler("application/vnd.oasis.opendocument.text-template", "ott");
__PACKAGE__->register_handler("application/vnd.oasis.opendocument.presentation", "odp");
__PACKAGE__->register_handler("application/vnd.oasis.opendocument.presentation-template", "otp");
__PACKAGE__->register_handler("application/vnd.oasis.opendocument.spreadsheet", "ods");
__PACKAGE__->register_handler("application/vnd.oasis.opendocument.spreadsheet-template", "ots");
__PACKAGE__->register_handler("application/vnd.sun.xml.writer", "sxw");
__PACKAGE__->register_handler("application/vnd.sun.xml.writer.template", "stw");
__PACKAGE__->register_handler("application/vnd.sun.xml.calc", "sxc");
__PACKAGE__->register_handler("application/vnd.sun.xml.calc.template", "stc");
__PACKAGE__->register_handler("application/vnd.sun.xml.impress", "sxi");
__PACKAGE__->register_handler("application/vnd.sun.xml.impress.template", "sti");

sub stringForFile {
    my ($self, $filename) = @_;
    
    my $cmd = $odt2text . ' --encoding=UTF-8 %FILENAME|F%';
    my ($text, $exit) = Foswiki::Sandbox->sysCommand($cmd, FILENAME => $filename);

    $text = $self->decode($text, $Foswiki::cfg{StringifierContrib}{CharSet}{odt2txt} || 'utf-8');
    return $self->encode($text);
}

1;
