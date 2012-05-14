# See bottom of file for license and copyright information
package Foswiki::Plugins::LocalCityTimePlugin;

use strict;

our $SHORTDESCRIPTION = 'Shows the local time in a city';

# root dir of zone info files
our $tzDir = '/usr/share/zoneinfo';

# path to date command
our $dateCmd = '/bin/date';

# RFC-822 compliant date format
our $dateParam = "'+\%a, \%d \%b \%Y \%T \%z \%Z'";

# Example: Fri, 14 Nov 2003 23:46:52 -0800 PST

our $VERSION = '$Rev$';
our $RELEASE = '2.0';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    die "tzDir $tzDir does not exist" unless -d $tzDir;
    die "dateCmd $dateCmd not found"  unless -x $dateCmd;

    Foswiki::Func::registerTagHandler( 'LOCALCITYTIME', \&_LOCALCITYTIME );

    return 1;
}

sub _LOCALCITYTIME {
    my ( $session, $attributes, $topic, $web ) = @_;

    my $timeZone = $attributes->{_DEFAULT} || '';
    $timeZone =~ s/[^\w\-\/\_\+]//gos;
    unless ($timeZone) {

        # return help
        return "LocalCityTimePlugin help: Enter a Continent/City "
          . "timezone code, e.g. %<nop>LOCALCITYTIME{\"Europe/Zurich\"}%";
    }

    # try date command and zoneinfo file
    my $tz = $tzDir . "/" . $timeZone;
    unless ( -f $tz ) {
        return
            "LocalCityTimePlugin warning: Invalid Timezone "
          . "'$timeZone'. Use a Continent/City timezone code "
          . " e.g. %<nop>LOCALCITYTIME{\"Europe/Zurich\"}%";
    }
    my $saveTZ = $ENV{TZ};    # save timezone
    $ENV{TZ} = $tz;
    my $text = `$dateCmd $dateParam`;
    chomp($text);
    if ( defined $saveTZ ) {
        $ENV{TZ} = $saveTZ;    # restore TZ environment
    }
    else {
        delete $ENV{TZ};
    }

    return $text . ' (' . $timeZone . ')';
}

1;
__END__
Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
Copyright (C) 2010 Foswiki Contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html

As per the GPL, removal of this notice is prohibited.
