# See bottom of file for license and copyright details
# This packages subclasses Foswiki::Form::FieldDefinition to implement
# the =date= type

package Foswiki::Form::Rating;
use Foswiki::Form::FieldDefinition;
our @ISA = qw( Foswiki::Form::FieldDefinition );

use strict;

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    my $size  = $this->{size} || '';
    $size =~ s/[^\d]//g;
    $size = 5 if ( !$size || $size < 1 );
    $this->{size} = $size;

    return $this;
}

# Render line of stars
sub renderForEdit {
    my ( $this, $web, $topic, $value ) = @_;

    my $useSmall = ( $this->{type} =~ /\+small/ );
    require Foswiki::Contrib::RatingContrib;
    return (
        '',
        Foswiki::Contrib::RatingContrib::renderRating(
            $this->{name}, $this->{size}, $useSmall, $value, {}
        )
    );
}

# Render the lines of stars for display only
sub renderForDisplay {
    my ( $this, $format, $value, $attrs ) = @_;

    my $useSmall = ( $this->{type} =~ /\+small/ );
    require Foswiki::Contrib::RatingContrib;
    $value =
      Foswiki::Contrib::RatingContrib::renderRating( $this->{name},
        $this->{size}, $useSmall, $value, undef );
    $value  =~ s/\n//g;
    $format =~ s/\$title/$this->{title}/g;
    $format =~ s/\$value/$value/g;

    return $format;
}

1;
__DATA__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2001-2009 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

Additional copyrights apply to some of the code in this file as follows:
Copyright (C) 2001-2007 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

