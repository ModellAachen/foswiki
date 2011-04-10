# See bottom of file for copyright and license information
package Foswiki::Plugins::EditRowPlugin::Editor::text;

# The functionality of this type is by default the base class functionality. However
# it is not the base class, because it may be overridden selectively with different
# functionality by installing a new text.pm, and we don't want to break the base
# class when we override.

use strict;
use Assert;

use Foswiki::Plugins::EditRowPlugin::Editor;

our @ISA = ( 'Foswiki::Plugins::EditRowPlugin::Editor' );

sub new {
    my $class = shift;
    return $class->SUPER::new('text');
}

sub jQueryMetadata {
    my $this = shift;
    my ( $cell, $colDef, $text ) = @_;
    my $data = $this->SUPER::jQueryMetadata(@_);

    $data->{data} = $text;
    $this->_addSaveButton($data);
    return $data;
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (c) 2011 Foswiki Contributors
All Rights Reserved. Foswiki Contributors are listed in the
AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Do not remove this notice.