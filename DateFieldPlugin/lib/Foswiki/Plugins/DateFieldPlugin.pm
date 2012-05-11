#
# Date field entry plugin
#
# Copyright (C) Deutsche Bank AG http://www.db.com
# Author Crawford Currie http://c-dot.co,uk
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
# Copyright (C) 2008 Foswiki Contributors

package Foswiki::Plugins::DateFieldPlugin;

use strict;
use POSIX qw(strftime);

use Foswiki::Func;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC );

$VERSION           = '$Rev: 15317 $';
$RELEASE           = 'Dakar';
$SHORTDESCRIPTION  = 'Adds a =date= type for use in forms';
$NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # make sure JSCalendar is there
    eval 'use Foswiki::Contrib::JSCalendarContrib';
    if ($@) {
        my $mess = "WARNING: JSCalendar not installed: $@";
        print STDERR "$mess\n";
        Foswiki::Func::writeWarning($mess);
        return 0;
    }

    return 1;
}

sub beforeEditHandler {

    # Load the 'Foswiki' calendar setup
    Foswiki::Contrib::JSCalendarContrib::addHEAD('foswiki');
}

sub renderFormFieldForEditHandler {
    my ( $name, $type, $size, $value, $attributes, $possibleValues ) = @_;
    return undef unless $type eq 'date';

    my $calendarOutputFormat =
         Foswiki::Func::getPreferencesValue('DATEFORMAT')
      || Foswiki::Func::getPreferencesValue('DATEFIELDPLUGIN_DATEFORMAT')
      || $Foswiki::cfg{JSCalendarContrib}{format}
      || '%d %b %Y';

    # Default to local today if preference set
    if ( Foswiki::Func::getPreferencesValue('DATEFIELDPLUGIN_DEFAULTTOTODAY') )
    {
        $value ||=
          POSIX::strftime( $calendarOutputFormat, localtime( time() ) );
    }

    my $content = CGI::image_button(
        -name    => 'calendar',
        -onclick => "return showCalendar('date_$name','$calendarOutputFormat')",
        -src     => Foswiki::Func::getPubUrlPath() . '/'
          . Foswiki::Func::getTwikiWebname()
          . '/JSCalendarContrib/img.gif',
        -alt   => 'Calendar',
        -align => 'middle'
    );
    return CGI::textfield(
        {
            name  => $name,
            value => $value,
            size  => 30,
            id    => 'date_' . $name
        }
    ) . $content;
}

1;
