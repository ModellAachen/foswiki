# See bottom of file for license and copyright information

package Foswiki::Plugins::CalendarPlugin;

use strict;
use warnings;

# See plugin topic for complete release history
our $VERSION           = '$Rev$';
our $RELEASE           = '2.001';
our $SHORTDESCRIPTION  = 'Show a monthly calendar with highlighted events';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    Foswiki::Func::registerTagHandler(
        'CALENDAR',
        sub {
            require Foswiki::Plugins::CalendarPlugin::Core;
            return Foswiki::Plugins::CalendarPlugin::Core::CALENDAR(@_);
        }
    );
    return 1;
}

1;
__END__
Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2001 Andrea Sterbini, a.sterbini@flashnet.it
Christian Schultze: debugging, relative month/year, highlight today
Akim Demaille <akim@freefriends.org>: handle date intervals.
Copyright (C) 2002-2006 Peter Thoeny, peter@thoeny.org
Copyright (C) 2008-2011 Foswiki Contributors
