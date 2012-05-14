# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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

=pod

---+ package Foswiki::Plugins::WikiAppInstallerPlugin


=cut

package Foswiki::Plugins::WikiAppInstallerPlugin;

use strict;
use warnings;

use Assert;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

our $VERSION           = '$Rev: 11239 $';
our $RELEASE           = '1.0.0';
our $SHORTDESCRIPTION  = 'Explore, install, and package wiki applications';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    Foswiki::Func::registerTagHandler( 'WIKIAPP_INSTALLER_TRYME',
        \&_WIKIAPP_INSTALLER_TRYME );
    Foswiki::Func::registerTagHandler( 'WIKIAPP_INSTALLER_PACKAGEME',
        \&_WIKIAPP_INSTALLER_PACKAGEME );

    # Plugin correctly initialized
    return 1;
}

# $session  - a reference to the Foswiki session object
#             (you probably won't need it, but documented in Foswiki.pm)
# $params=  - a reference to a Foswiki::Attrs object containing
#             parameters.
#             This can be used as a simple hash that maps parameter names
#             to values, with _DEFAULT being the name for the default
#             (unnamed) parameter.
# $topic    - name of the topic in the query
# $web      - name of the web in the query
# $topicObject - a reference to a Foswiki::Meta object containing the
#             topic the macro is being rendered in (new for foswiki 1.1.x)
# Return: the result of processing the macro. This will replace the
# macro call in the final text.
sub _WIKIAPP_INSTALLER_TRYME {
    require Foswiki::Plugins::WikiAppInstallerPlugin::Macros;
    ASSERT( !$@ ) if DEBUG;
    Foswiki::Plugins::WikiAppInstallerPlugin::Macros::TRYME(@_);
}

sub _WIKIAPP_INSTALLER_PACKAGEME {
    require Foswiki::Plugins::WikiAppInstallerPlugin::Macros;
    ASSERT( !$@ ) if DEBUG;
    Foswiki::Plugins::WikiAppInstallerPlugin::Macros::PACKAGEME(@_);
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: %$AUTHOR%

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
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
