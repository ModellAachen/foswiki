# See bottom of file for license and copyright information
package Foswiki::Contrib::JSTreeContrib;

use strict;

our $VERSION = '$Rev$';    # version of *this file*.
our $RELEASE = '1.0.7';
;                          # keep in synch with jquery.jstree.js
our $SHORTDESCRIPTION = 'The popular jsTree jQuery plugin, packaged for reuse';

=begin TML

Call this from any other extension to include this plugin. For example,
<verbatim>
require Foswiki::Contrib::JSTreeContrib;
Foswiki::Contrib::JSTreeContrib::init();
</verbatim>

=cut

sub init {
    unless (
        Foswiki::Plugins::JQueryPlugin::registerPlugin(
            'JSTree', 'Foswiki::Contrib::JSTreeContrib::JSTREE'
        )
      )
    {
        die 'Failed to register JSTree plugin';
    }
    unless ( Foswiki::Plugins::JQueryPlugin::createPlugin("JSTree") ) {
        die 'Failed to create JSTree plugin';
    }
    return 1;
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2011 Foswiki Contributors. Foswiki Contributors
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
