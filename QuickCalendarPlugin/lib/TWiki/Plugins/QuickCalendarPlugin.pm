# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2000-2003 Peter Thoeny, peter@thoeny.com
#
#   Portions derived from :
#    Perl Power Tools - cal
#    http://www.perl.com/language/ppt/src/cal
#    Author: Greg Hewgill greg@hewgill.com 1999-03-01
#    Portions copyright by Greg Hewgill 1999.
#    Portions are free and open software. You may use, copy, modify,
#    distribute and sell those portions (and any modified variants) in any way
#    you wish, provided you do not restrict others to do the same.
#
# Copyright (c) 2003 Jonathan Cline, jcline.at.ieee.org
# Some patches between v1.210 and v1.220 Copyright 2003 Will Norris
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# 3. Neither the name of the software nor the names of its contributors may be
# used to endorse or promote products derived from this software without
# specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# =========================

# =========================
package TWiki::Plugins::QuickCalendarPlugin;
use POSIX qw(ceil floor);

#
# This plugin is meant to comply with
# ISO 8601: Standard for International Date and Time Notation
#
# with the following methods:
#   1.  year numbers are always 4-digit
#   2.  week numbers are always 2-digit
#   3.  month numbers are always 2-digit
#   4.  day numbers are always 2-digit
#   5.  quarter numbers are always single digit
#   6.  year-week format is YYYYwWW as in "2003w51"
#   7.  year-month-day format is YYYYMMDD as in "20030930"
#   8.  day-of-year numbers are 1..366
#   9.  year-quarter format is YYYYqQ as in "2003q4", where Q is 1 to 4:
#      - quarter 1 includes Jan, Feb, Mar
#      - quarter 2 includes Apr, May, Jun
#      - quarter 3 includes Jul, Aug, Sep
#      - quarter 4 includes Oct, Nov, Dec
#
# Especially ambiguous are week numbers.
#  Week numbers range 01 .. 53 and all years have at least week 52.
# Note though that POSIX strftime function has multiple representations
#   of the week number, either:
#      - 00-53 where the first Sunday of the year indicates week 1
#      - 00-53 where the first Monday of the year indicates week 1
#      - 01-53 where week 1 is indicated by the number of days in the first
#      week of the year, i.e. week 1 is indicated by Jan 4th or the first
#      Thursday.
#   This plugin uses 01-53 where week 1 is Jan 1.
# All I can say is, dammit, I just wanted to write a simple plugin.
#
# Reference:
# http://www.cl.cam.ac.uk/~mgk25/iso-time.html
# and "calendar FAQ" (search on google)
# and http://sciastro.astronomy.net/sci.astro.3.FAQ
#       [sci.astro] Time (Astronomy Frequently Asked Questions)

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  @NowStr @DayStr @MonthStr
  %Config %Static
  %This %Next %Last %Prev
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'QuickCalendarPlugin';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    @NowStr = localtime;
    $Static{'wikiname'} = &TWiki::Func::getWikiUserName();

    # strip off web part
    # $Static{'wikiname'} =~ s/(.*)\.(.*)/$2/o;

    @MonthStr = qw( . January February March April May June
      July August September October November December);
    @DayStr = qw(Sun Mon Tue Wed Thu Fri Sat);

    $Static{'thisYear'}  = 1900 + $NowStr[5];                # y2k compliant :-P
    $Static{'thisMonth'} = $NowStr[4] + 1;                   # 1 .. 12
    $Static{'thisDay'}   = $NowStr[3];                       # 1 .. 31
    $Static{'thisQtr'}   = POSIX::ceil( $NowStr[4] / 3 );    # 1 .. 4

    # The Config var is used to set certain defaults

    # 1 = anchor mode, creates #yyyymmdd hrefs for each date
    $Config{'anchor'} = 1;

    # 1 = show doy dates instead of month dates (i.e. 304 = 31st of october)
    $Config{'doy'} = 0;

    # Style Configuration
    $Config{'style'} = <<__STYLE__;
<style>
    .week   { background:#ccc; }
    .day    { background:#eee; }
    .today  { background:yellow; }
</style>
__STYLE__

    $Config{'tablestyle'} = qq{"width:auto; border:0px;"};

    # iterative state
    %Prev = %This = %Next = ();

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
#
# ======== generateAnchor ========
#
# this renders the anchors which jump to weeks or days
# if these anchors don't exist in the page, they
# won't go anywhere.  User must insert anchors in
# the page on their own.
#
# week style anchors look like this,
#   (example, for last week in the year)
#    <a href="(userHref)2003w52">2003w52</a>
# day style anchors look like this,
#   (example, for last day in the year)
#    <a href="(userHref)20031231">31</a>
# where userHref is the wikiname (default) or user
# specified URL.  If in Anchor Mode then userHref
# will be userHref#CalDateYYYYMMDD
#
# Important:  anchors must be ISO 8601 with
#  the following format:  YYYYMMDD for days, and
#  YYYYwWW for week.
#
# Note if the anchor'd destination wants to include
#  a "go back" button, it can use this:
#  <FORM>
#    <INPUT TYPE="Button" VALUE="Back"
#      onClick="history.go(-1)">
#  </FORM>
#
sub generateAnchor {
    my $type = $_[0];
    my ( $y, $vv, $dd, $d ) = (
        sprintf( "%04d", $_[1] || 0 ),
        sprintf( "%02d", $_[2] || 0 ),
        sprintf( "%02d", $_[3] || 0 ),
        $_[3] || ''
    );
    my $anchor;

    $anchor = '<a TARGET="_blank" href="' . $This{'userHref'} . $y;

    if ( $type eq 'week' ) {

        # continue with "week" style anchor
        $anchor .= 'w' . $vv . '">' . $y . 'w' . $vv;
    }
    else {

        # continue with "day" style anchor
        $anchor .= $vv . $dd . '">' . $d;
    }

    $anchor .= '</a>';
    return $anchor;
}

# =========================

#
# ======== dow ========
#   Perl Power Tools - cal
#   Author: Greg Hewgill greg@hewgill.com 1999-03-01
#   This function is copyright by Greg Hewgill 1999.
#   This function is free and open software. You may use, copy, modify,
#   distribute and sell this function (and any modified variants) in any way
#   you wish, provided you do not restrict others to do the same.
#
#  DOW = ([23m/9] + d + 4 + z + [z/4] - [z/100] + [z/400] - 2 (if m>=3)) mod 7
#
#  y is the year.
#  m is the month.
#  d is the day.
#  z = y - 1 (if m <  3)
#    = y     (if m >= 3)
#  A mod B means take the reminder of A / B.
#
#  The source: Journal on Recreational Mathematics, Vol. 22(4), pages 280-282, 1990.
#  The authors: Michael Keith and Tom Craver.
#
#  The formula can be implemented by the following C function:
#
#  int dayofweek(int y,m,d)
#  {
#    return((23*m/9+d+4+(m<3?y--:y-2)+y/4-y/100+y/400)%7);
#  }

sub dow {
    my ( $y, $m, $d ) = @_;
    $y-- if $m < 3;
    $d += 11 if $y < 1752 || $y == 1752 && $m < 9;
    if ( $y >= 1752 ) {
        return (
            int( 23 * $m / 9 ) +
              $d + 4 +
              ( $m < 3 ? $y + 1 : $y - 2 ) +
              int( $y / 4 ) -
              int( $y / 100 ) +
              int( $y / 400 ) ) % 7;
    }
    else {
        return (
            int( 23 * $m / 9 ) +
              $d + 5 +
              ( $m < 3 ? $y + 1 : $y - 2 ) +
              int( $y / 4 ) ) % 7;
    }
}

# =========================
#  ======== days ========
#   Perl Power Tools - cal
#   Author: Greg Hewgill greg@hewgill.com 1999-03-01
#   This function is copyright by Greg Hewgill 1999.
#   This function is free and open software. You may use, copy, modify,
#   distribute and sell this function (and any modified variants) in any way
#   you wish, provided you do not restrict others to do the same.
#
sub getDaysInMonth {
    my ( $y, $m ) = @_;
    if ( $m != 2 ) {
        return ( 0, 31, 0, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 )[$m];
    }

    # Leap Year calc
    # leap years occur every 4 years except for century years unless they are
    # also divisible by 400.
    if ( $y % 4 != 0 )   { return 28; }
    if ( $y < 1752 )     { return 29; }
    if ( $y % 100 != 0 ) { return 29; }
    if ( $y % 400 != 0 ) { return 28; }
    return 29;
}

# =========================
#
# ======== getDatesInWeek ========
#
# Derived from:
#   Perl Power Tools - cal
#   Author: Greg Hewgill greg@hewgill.com 1999-03-01
#   This function is copyright by Greg Hewgill 1999.
#   This function is free and open software. You may use, copy, modify,
#   distribute and sell this function (and any modified variants) in any way
#   you wish, provided you do not restrict others to do the same.
#
# args: year (19xx), month (1-12), week in month (0-5)
#
# returns date information for a single week in month:
#   ( work week/week in year 1-53, doy offset 0 .. 364,
#       date-in-month for sunday ... date-in-month for saturday
#   )
#  date = 0 if that day is not in the given month.
#  or, if no days in month for given week, returns (0) for every date-in-month
#
#
sub getDatesInWeek {
    my (
        $y,    # 4 digit
        $m,    # 1 .. 12
        $w
      )        # 0 .. 5
      = @_;
    my $day;    # day in month 1 .. 31
    my $doy = 0;    # day in year 0 .. 365
    my $woy = 0;    # week in year 0 .. 53
    my %result;
    local $_;

    $day = 1 - dow( $y, $m, 1 ) + 7 * $w;
    for ( 1 .. $m - 1 ) {
        $doy += getDaysInMonth( $y, $_ );
    }

    $woy = POSIX::ceil( ( $doy + $day ) / 7 ) + 1;    # this is non-iso std

    # could use instead:
    #    $d4 = ((($julianday + $day + 31741 -
    #            (($julianday + $day) % 7)) % 1466097) % 36524) % 1461;
    #    $L = $d4 / 1460;
    #    $d1 = (($d4 - $L) % 365) + $L;
    #    $woy = $d1/7 + 1;
    # got that?  but it doesn't work unless also calculate julian date

    # could use instead:
    #    $woy = POSIX::strftime("%W",
    #            1, 1, 1, $day, $m -1, $y);
    #     gads, that's not supported in perl < v5.6 ?

    if ( $day > getDaysInMonth( $y, $m ) ) {

        # no days left this month
        return ();
    }

    $result{'ww'}    = $woy;
    $result{'doy'}   = $doy;
    $result{'dates'} = "";

    for ( 0 .. 6 ) {
        if ( $day < 1 ) {

            # no date for this day yet
            $result{'dates'} .= "0 ";
        }
        elsif ( $day <= getDaysInMonth( $y, $m ) ) {
            $result{'dates'} .= $day . " ";
        }
        else {

            # no more days in month
            last;
        }

        $day++;
    }
    return %result;
}

# =========================
#
# ======== handleCal ========
# main processing
#  This generates html table from mathematically calculated dates
#
sub handleCal {
    my ( $preSpace, $arg1 ) = @_;
    my %weekdates;
    my $weekInYear;
    my $dayInYear;
    my $mnum;
    my $date;
    local $_;

    my $out =
      $preSpace . "<!-- Calender rendered by TWiki Plugin: Quick Calendar -->";

    $out .= $Config{'style'};

    # same-page iteratation
    %This = %Next;
    %Next = ();

    # set default output
    $This{'displayYear'}  = $Static{'thisYear'};
    $This{'displayMonth'} = $Static{'thisMonth'};
    $This{'displayQtr'}   = $Static{'thisQtr'};
    $This{'doy'}          = $Config{'doy'};

    $This{'userHref'} =
      scalar &TWiki::Func::extractNameValuePair( $arg1, "href" );
    $This{'usermonth'} =
      scalar &TWiki::Func::extractNameValuePair( $arg1, "month" );
    $This{'useryear'} =
      scalar &TWiki::Func::extractNameValuePair( $arg1, "year" );
    $This{'doy'} = scalar &TWiki::Func::extractNameValuePair( $arg1, "doy" );

    if ( $Config{'anchor'} && !$This{'userHref'} ) {

        # anchor mode forces calendar to link within current topic
        # note, pound-anchors require wikiword text in TWiki (not w3 spec)
        $This{'userHref'} = $topic . "#CalDate";
    }

    # Handle href argument
    if ( !$This{'userHref'} ) {

        # default link - change to your special default location here
        $This{'userHref'} = $Static{'wikiname'};
    }

    # Handle Month argument
    if ( $This{'usermonth'} =~ /^\-(\d+)/ ) {

        # month="-2"
        $This{'usermonth'} = $This{'displayMonth'} - $1;
        while ( $This{'usermonth'} < 1 ) {
            $This{'usermonth'} += 12;
            $This{'displayYear'} -= 1;
        }
        $This{'displayMonth'} = $This{'usermonth'};
    }
    elsif ( $This{'usermonth'} =~ /^\+(\d+)/ ) {

        # month="+2"
        $This{'usermonth'} = $This{'displayMonth'} + $1;
        while ( $This{'usermonth'} > 12 ) {
            $This{'usermonth'} -= 12;
            $This{'displayYear'} += 1;
        }
        $This{'displayMonth'} = $This{'usermonth'};
    }
    elsif ( $This{'usermonth'} =~ /^(\d+)/ ) {

        # month="4"
        $This{'displayMonth'} = $1;
    }
    elsif ( $This{'usermonth'} ) {

        # month="january"  or  month="jan"
        for ( 1 .. 12 ) {
            if ( $MonthStr[$_] =~ /$This{'usermonth'}\w*/i ) {
                $This{'displayMonth'} = $_;
                $This{'usermonth'}    = $_;
                last;
            }
        }
    }

    if ($arg1) {

        # year="2002"
        if ( $arg1 =~ s/\s*year\s*=\s*['"]?(\d+)['"]?\s*//i ) {
            $This{'userYear'} = $1;

            # must be 4 digit year.
            # check for 4 digit year here?  Nah. garbage in, garbage out.
            $This{'displayYear'} = $This{'userYear'};
        }

        # year="-2"
        if ( $arg1 =~ s/\s*year\s*=\s*['"]?\-(\d+)['"]?\s*//i ) {
            $This{'displayYear'} = $This{'displayYear'} - $1;
        }

        # year="+2"
        if ( $arg1 =~ s/\s*year\s*=\s*['"]?\+(\d+)['"]?\s*//i ) {
            $This{'displayYear'} = $This{'displayYear'} + $1;
        }
    }

    $out .=
        qq{<table style=$Config{'tablestyle'}>\n}
      . qq{<tr> <th colspan=8> }
      . qq{$MonthStr[$This{'displayMonth'}] $This{'displayYear'} }
      . qq{($This{'displayMonth'}/$This{'displayYear'})}
      . qq{ </th> </tr>\n}
      . qq{<tr> <th>Week</th> };
    for (@DayStr) {
        $out .= qq{<th> $_ </th> };
    }
    $out .= qq{</tr>\n};

    for ( 0 .. 5 ) {

        # get a week of dates in the month
        if ( %weekdates =
            getDatesInWeek( $This{'displayYear'}, $This{'displayMonth'}, $_ ) )
        {
            $weekInYear = $weekdates{'ww'};
            $dayInYear  = $weekdates{'doy'};
            $out .=
                '<tr><td class="week">'
              . generateAnchor( 'week', $This{'displayYear'}, $weekInYear )
              . "</td>\n";
            for $date ( split( ' ', $weekdates{'dates'} ) ) {
                if ($date) {
                    my $day_class =
                      (      $Static{'thisYear'} == $This{'displayYear'}
                          && $Static{'thisMonth'} == $This{'displayMonth'}
                          && $Static{'thisDay'} == $date
                          && 'today' )
                      || 'day';
                    if ( $This{'doy'} ) {
                        $date += $dayInYear;
                    }
                    $out .= qq{<td class="$day_class">}
                      . generateAnchor( 'day', $This{'displayYear'},
                        $This{'displayMonth'}, $date )
                      . "</td>\n";
                }
                else {
                    $out .= "<td> </td>\n";
                }
            }
            $out .= '</tr>';
        }
        else {
            last;    # should only get here at 5 anyway?
        }
    }
    $out .= '</table>';

    return $out;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1])")
      if $debug;

    return unless $_[0] =~ /%CAL.*%/s;

    my $theWeb   = $_[2];
    my $theTopic = $_[1];

    $_[0] =~ s/(\s*)%CAL{(.*)}%/&handleCal($1, $2)/geo;
    $_[0] =~ s/(\s*)%CAL%/&handleCal()/geo;

}

# =========================

1;
