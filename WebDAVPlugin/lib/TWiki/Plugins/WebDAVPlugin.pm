#
# Copyright (C) 2004 WindRiver Ltd.
# Written by Crawford Currie http://c-dot.co.uk
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
#
# Plugin to cache permission information in a simple cache file that
# can be read by the twiki_dav module. Based on SessionManagerPlugin
# code:
# Copyright (C) 2002 Andrea Sterbini, a.sterbini@flashnet.it
#                    Franco Bagnoli, bagnoli@dma.unifi.it
#
package TWiki::Plugins::WebDAVPlugin;

use strict;

use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE
  $permDB
);

$VERSION = '$Rev$';
$RELEASE = 'TWiki-4';

my $pluginName = 'WebDAVPlugin';

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    my $pdb = $TWiki::cfg{Plugins}{WebDAVPlugin}{DAVLockDB};

    if ($pdb) {
        eval 'use TWiki::Plugins::WebDAVPlugin::Permissions';
        if ($@) {
            TWiki::Func::writeWarning($@);
            print STDERR $@;    # print to webserver log file
        }
        else {
            $permDB = new TWiki::Plugins::WebDAVPlugin::Permissions($pdb);
        }
    }
    else {
        my $mess = "{Plugins}{WebDAVPlugin}{DAVLockDB} is not defined";

        TWiki::Func::writeWarning($mess);
        print STDERR "$mess\n";
        return 0;
    }

    unless ($permDB) {
        my $mess = "$pluginName: failed to initialise";
        TWiki::Func::writeWarning($mess);
        print STDERR "$mess\n";
        return 0;
    }

    return 1;
}

sub beforeSaveHandler {
    my ( $text, $topic, $web ) = @_;

    return unless ($permDB);

    eval { $permDB->processText( $web, $topic, $text ); };

    if ($@) {
        TWiki::Func::writeWarning("$pluginName: $@");
        print STDERR "$pluginName: $@\n";
    }
}

1;
