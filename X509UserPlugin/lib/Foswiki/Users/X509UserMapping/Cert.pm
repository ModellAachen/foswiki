# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006, 2008 Timothe Litt, litt@acm.org
# and Foswiki Contributors. All Rights Reserved. Foswiki Contributors
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

package Foswiki::Users::X509UserMapping::Cert;

use strict;

sub parseDN($$);
sub element($$);
sub elements($);

#
# Parse the elements of a Distinguished Name into a cert object for easier access
#
# A DN looks like /KEY=data/KEY2=data2 ...
#
sub parseDN($$) {
    my $class = shift;
    my $dn    = shift;

    my $self = {};
    bless $self, $class;

    my @parts;

    # Strip any junk up thru the first slash

    $dn =~ s|^.*?/||;

    # Often externally sourced, untaint.

    $dn =~ m/^(.*)$/;
    $dn = $1;

    @parts = split m|/|, $dn;

    foreach my $p (@parts) {
        my $key;
        my $val = '';

        ( $key, $val ) = split m/=/, $p, 2;
        if ($key) {
            if ( $self->{$key} ) {
                my $i = 1;
                my $k;
                do {
                    $i++;
                    $k = "$key.$i";
                } while ( $self->{$k} );
                $key = $k;
            }
            $self->{$key} = $val;
        }
    }

    return $self;
}

#
# Return named element of a DN
#
sub element($$) {
    my $self    = shift;
    my $element = shift;

    return $self->{$element} || '';
}

#
# Dump a DN
#
sub dumpDN($) {
    my $self = shift;

    my $result;

    foreach my $e ( sort $self->elements ) {
        $result .= sprintf( "%15s = '%s'\n", $e, ( $self->{$e} || '' ) );
    }
    return $result;
}

#
# Return list of element names
#
sub elements($) {
    my $self = shift;

    return keys %$self;
}

1;
