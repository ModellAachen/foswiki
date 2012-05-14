# Contrib for of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Wind River Systems Inc.
# Copyright (C) 1999-2006 TWiki Contributors.
# All Rights Reserved. TWiki Contributors
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

---+++ Package <!-- TWikiCfg --> TWiki::Contrib::CliRunnerContrib::TWikiCfg

This package is intended to be used by TWiki developers.  It contains
methods to manipulate the =$TWiki::cfg= hash for a single run.

No user-serviceable parts inside.

=cut

package TWiki::Contrib::CliRunnerContrib::TWikiCfg;

use strict;

our $VERSION = '$Rev$';

use TWiki::Configure::Load;

# Read the configuration change during the import phase.
sub import {
    my $self = shift;

    my ($config_manip_filename) = @_;

    # Read the configuration *right now*
    TWiki::Configure::Load::readConfig();

    my $done = do $config_manip_filename;
    if ($done) {
        unlink $config_manip_filename;
    }
    else {
        $! and die "Failed to read '$config_manip_filename': '$!'\n";
        $@ and die "Failed to compile '$config_manip_filename':\n$@\n";
        die "'$config_manip_filename' did not return a true value\n";
    }

    # Finally say that we're done to suppress re-reading
    $TWiki::cfg{ConfigurationFinished} = 1;
}

1;

