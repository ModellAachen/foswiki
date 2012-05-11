# See bottom of file for license and copyright information

package Foswiki::Plugins::PrefsCachePlugin;

use strict;

our $VERSION          = '$Rev: 5771 $';
our $RELEASE          = '1.1.1';
our $SHORTDESCRIPTION = 'Cache preferences for faster access';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;
    return 0
      unless $Foswiki::cfg{Store}{PrefsBackend} eq
          'Foswiki::Prefs::BerkeleyDBRAM';
    return 1;
}

sub afterSaveHandler {
    my ( $text, $topic, $web, $error, $meta ) = @_;

    require Foswiki::Prefs::BerkeleyDBRAM;
    Foswiki::Prefs::BerkeleyDBRAM::invalidate($meta);
}

1;
__END__

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
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
