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

---+++ Package <!-- HideModule --> TWiki::Contrib::CliRunnerContrib::HideModule

This package is intended to be used by TWiki developers.  It contains
methods to hide CPAN modules by pretending that they don't return a
true value.

No user-serviceable parts inside.

=cut

package TWiki::Contrib::CliRunnerContrib::HideModule;

use strict;

our $VERSION = '$Rev$';

use Carp;
use File::Path;
use File::Spec;
use File::Temp;

my @dirs_created  = ();
my @files_created = ();

sub import {
    my $self = shift;
    my $tempdir = File::Temp::tempdir( CLEANUP => 1 );
    eval "use lib '$tempdir'";
    for my $module (@_) {
        my @split = split /::/, $module;
        my $path = File::Spec->catfile( $tempdir, @split ) . '.pm';
        pop @split;
        File::Path::mkpath( File::Spec->catdir( $tempdir, @split ) );
        if ( open FAKE, ">", $path ) {
            print FAKE qq(die "Can't locate $module in \\\@FAKE");
            close FAKE;
        }
        else {
            Carp::croak(
"Can't create fake module '$module' in '$path': '$!'.\nTerminating."
            );
        }
    }
}

1;
