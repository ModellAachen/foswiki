# See bottom of file for default license and copyright information

=begin TML

---+ package TinyMCECleanStickyBitsPlugin

=cut

package Foswiki::Plugins::TinyMCECleanStickyBitsPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

our $VERSION = '$Rev$';
our $RELEASE = '11 Jul 2010';
our $SHORTDESCRIPTION =
'Toolbar button to clean a selection of sticky attributes that would prevent a clean conversion to WikiText';
our $NO_PREFS_IN_TOPIC = 1;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;
    my $init = 1;

    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        $init =
            __PACKAGE__
          . ' requires Foswiki::Plugins API >= 2.0, but '
          . $Foswiki::Plugins::VERSION
          . ' was detected';
    }
    elsif ( not $Foswiki::cfg{Plugins}{TinyMCEPlugin}{Enabled} ) {
        $init = __PACKAGE__ . ' depends on TinyMCEPlugin, which is not enabled';
    }
    elsif ( not $Foswiki::cfg{Plugins}{JQueryPlugin}{Enabled} ) {
        $init = __PACKAGE__ . ' depends on JQueryPlugin, which is not enabled';
    }
    elsif (
        Foswiki::Func::getContext()->{'edit'}
        and not(
            Foswiki::Func::getPreferencesFlag(
                'TINYMCEFOSWIKITOOLSPLUGIN_NO_AUTOTOOLBAR')
            and Foswiki::Func::getPreferencesFlag(
                'TINYMCEFOSWIKITOOLSPLUGIN_NO_AUTOLOAD')
        )
      )
    {

        # Lazy-load to help CGI compile times
        require Foswiki::Plugins::TinyMCECleanStickyBitsPlugin::Core;
        Foswiki::Plugins::TinyMCECleanStickyBitsPlugin::Core::setup();
    }

    return $init;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Paul.W.Harvey@csiro.au, http://trin.org.au

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
