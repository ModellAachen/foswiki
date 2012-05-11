# See bottom of file for default license and copyright information

=begin TML

---+ package TinyMCEImgMapPlugin

=cut

package Foswiki::Plugins::TinyMCEImgMapPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package. This should always be in the format
# $Rev: 7196 $ so that Foswiki can determine the checked-in status of the
# extension.
our $VERSION = '$Rev: 7196 $';

# $RELEASE is used in the "Find More Extensions" automation in configure.
# It is a manually maintained string used to identify functionality steps.
# You can use any of the following formats:
# tuple   - a sequence of integers separated by . e.g. 1.2.3. The numbers
#           usually refer to major.minor.patch release or similar. You can
#           use as many numbers as you like e.g. '1' or '1.2.3.4.5'.
# isodate - a date in ISO8601 format e.g. 2009-08-07
# date    - a date in 1 Jun 2009 format. Three letter English month names only.
# Note: it's important that this string is exactly the same in the extension
# topic - if you use %$RELEASE% with BuildContrib this is done automatically.
our $RELEASE = '2010-04-21';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
'Foswiki integration (including TinyMCE plugin) of the http://code.google.com/p/imgmap project';
our $NO_PREFS_IN_TOPIC = 1;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

*REQUIRED*

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using =Foswiki::Func::writeWarning= and return 0. In this case
%<nop>FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

__Note:__ Please align macro names with the Plugin name, e.g. if
your Plugin is called !FooBarPlugin, name macros FOOBAR and/or
FOOBARSOMETHING. This avoids namespace issues.

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Plugin correctly initialized
    return 1;
}

1;
__END__
This plugin for Foswiki packages mcegooglemap plugin, a GPL Sourceforge 
project found at http://mcegooglemap.sourceforge.net/
The original copyright notice reads as follows:

   Copyright: Cees Rijken, Christian Ladewig, Jeroen van der Stijl
   License: GPL
   (c)2009 All rights reserved.

The remainder of this information applies to the TinyMCEImgMapPlugin:

Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

TinyMCEImgMapPlugin is Copyright (C) 2009-2010 Foswiki Contributors.
 
Foswiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code as follows:
Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved.

This license applies to TinyMCEImgMapPlugin and to any derivatives.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

For licensing info read LICENSE file in the root of this distribution.
