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

package Foswiki::Contrib::Stringifier::Plugins::Text;
use Foswiki::Contrib::Stringifier::Base ();
our @ISA = qw( Foswiki::Contrib::Stringifier::Base );

# Note: I need not do any register, because I am the default handler for stringification!

use Encode::Guess ();

sub stringForFile {
    my ( $self, $file ) = @_;
    my $in;

    # check it is a text file
    return '' unless ( -e $file );

    open($in, $file) or return "";
    local $/ = undef;    # set to read to EOF
    my $text = <$in>;
    close($in);

    my $decoder = Encode::Guess::guess_encoding($text, "utf-8, iso8859-1");

    if (ref($decoder)) {
      #print STDERR "here1: decodere=".$decoder->name."\n";
      $text = $decoder->decode($text);
    } else {
      #print STDERR "decoder=$decoder\n";
      $text = $self->decode($text, $Foswiki::cfg{StringifierContrib}{CharSet}{text} || 'utf-8');
    }

    $text =~ s/^\?//; # remove bom
    
    return $self->encode($text);
}
1;
