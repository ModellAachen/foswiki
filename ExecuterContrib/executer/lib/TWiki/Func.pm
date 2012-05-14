# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::Func

<!-- STARTINCLUDE required for huge CompleteDocumentation topic -->
%STARTINCLUDE%

_Official list of stable TWiki functions for Plugin developers_

This module defines official functions that [[%SYSTEMWEB%.Plugins][Plugins]]
can use to interact with the TWiki engine and content.

Refer to %SYSTEMWEB%.EmptyPlugin and lib/TWiki/Plugins/EmptyPlugin.pm for a template Plugin and documentation on how to write a Plugin.

Plugins should *only* use functions published in this module. If you use
functions in other TWiki libraries you might create a security hole and
you will probably need to change your Plugin when you upgrade TWiki.

Deprecated functions will still work in older code, though they should
_not_ be called in new Plugins and should be replaced in older Plugins
as soon as possible.

The version of the TWiki::Func module is defined by the VERSION number of the
TWiki::Plugins module, currently %PLUGINVERSION%. This can be shown
by the =%<nop>PLUGINVERSION%= variable. The 'Since' field in the function
documentation refers to the VERSION number and the date that the function
was addded.

__Note:__ Beware! These methods should only ever be called
from the context of a TWiki Plugin. They require a Plugins SESSION context to be
established before they are called, and will not work if simply called from
another TWiki module. For example,
<verbatim>
use TWiki;
print TWiki::Func::getSkin(),"\n";
</verbatim>
will fail with =Can't call method "getSkin" on an undefined value at TWiki/Func.pm line 83=.

If you want to call the methods outside the context of a plugin, you can create a Plugins SESSION object. For example,
the script:
<verbatim>
use TWiki:
$TWiki::Plugins::SESSION = new TWiki();
print TWiki::Func::getSkin(),"\n";
</verbatim>
will work happily.

=cut

package TWiki::Func;

use strict;
use warnings;

#use Error qw( :try );
#use Assert;

#use TWiki::Time;
#use TWiki::Plugins;
use TWiki::Attrs;

sub extractParameters {
    my ($attr) = @_;
    my $params = new TWiki::Attrs($attr);

    # take out _RAW and _ERROR (compatibility)
    delete $params->{_RAW};
    delete $params->{_ERROR};
    return %$params;
}

1;

