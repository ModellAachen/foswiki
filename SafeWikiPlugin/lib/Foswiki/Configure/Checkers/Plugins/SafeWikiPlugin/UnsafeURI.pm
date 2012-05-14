# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Plugins::SafeWikiPlugin::UnsafeURI;
use warnings;
use strict;

use Foswiki::Configure::Checker;

use Foswiki::Configure::Checker;
our @ISA = qw( Foswiki::Configure::Checker );

sub check {
    my $this = shift;
    my $warnings;
    my $unsafeURIs = $Foswiki::cfg{Plugins}{SafeWikiPlugin}{UnsafeURI};
    my @goodURIs =
      Foswiki::Configure::Checkers::Plugins::SafeWikiPlugin::SafeURI::getGoodURIs(
      );

    if ( $Foswiki::cfg{Plugins}{SafeWikiPlugin}{Enabled} ) {
        foreach my $goodURI (@goodURIs) {
            foreach my $unsafeURI ( @{$unsafeURIs} ) {
                my $expandedUnsafeURI =
                  Foswiki::Configure::Checkers::Plugins::SafeWikiPlugin::SafeURI::expandVars(
                    $unsafeURI);
                if ( $goodURI =~ /$expandedUnsafeURI/ ) {
                    $warnings .= $this->WARN(<<"HERE");
Regexp: "<code style="color:#009900;">$unsafeURI</code>" filters the good URI: 
"<code style="color:#009900;">$goodURI</code>", which may prevent your wiki from
working correctly.
HERE
                }
            }
        }
    }

    return $warnings;
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
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
