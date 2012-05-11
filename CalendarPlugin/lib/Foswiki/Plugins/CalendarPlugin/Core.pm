# See bottom of file for license and copyright information
# $Rev$
package Foswiki::Plugins::CalendarPlugin::Core;

use strict;

use Time::Local               ();
use Date::Calc                ();
use HTML::CalendarMonthSimple ();
use Foswiki::Func             ();
use Assert;

use constant PLUGINNAME => 'CalendarPlugin';

sub TRACE { 0 }

our $defaultsInitialized;

my %months = (
    Jan => 1,
    Feb => 2,
    Mar => 3,
    Apr => 4,
    May => 5,
    Jun => 6,
    Jul => 7,
    Aug => 8,
    Sep => 9,
    Oct => 10,
    Nov => 11,
    Dec => 12
);
my %wdays = (
    Sun => 7,
    Mon => 1,
    Tue => 2,
    Wed => 3,
    Thu => 4,
    Fri => 5,
    Sat => 6
);
my $days_rx   = '[0-9]?[0-9]';
my $years_rx  = '[12][0-9][0-9][0-9]';
my $months_rx = join( '|', keys %months );
my $wdays_rx  = join( '|', keys %wdays );
my $date_rx   = "($days_rx)\\s+($months_rx)";

my $full_date_rx        = "$date_rx\\s+($years_rx)";
my $monthly_rx          = "([1-6L])\\s+($wdays_rx)";
my $anniversary_date_rx = "A\\s+$date_rx\\s+($years_rx)";
my $weekly_rx           = "E\\s+($wdays_rx)";
my $periodic_rx         = "E([0-9]+)\\s+$full_date_rx";
my $numdaymon_rx        = "([0-9L])\\s+($wdays_rx)\\s+($months_rx)";

#TODO: really should replace this naive regex code with a parser that can build up dates using the &dash's as delimiters.
#or, as a slightly lazyer option, remove the need for an 'ordered' processing by using the &dash..
#accepted date and interval definitions

#using our for the CalendarPluginTests
our %parse_definitions = (
    'intervals with year' => {
        pattern => "$full_date_rx\\s+-\\s+$full_date_rx",
        keys    => [qw(name dd1 mm1 yy1   dd2 mm2  yy2 xs  xcstr descr )]
    },
    'intervals without year' => {
        pattern => "$date_rx\\s+-\\s+$date_rx",
        keys    => [qw(name dd1 mm1 dd2 mm2 xs xcstr descr )]
    },
    'weekly repeaters with start and end dates' => {
        pattern => "$weekly_rx\\s+$full_date_rx\\s+-\\s+$full_date_rx",
        keys    => [qw(name dd  dd1 mm1   yy1 dd2 mm2  yy2 xs  xcstr descr )]
    },
    'weekly repeaters with start dates' => {
        pattern => "$weekly_rx\\s+$full_date_rx",
        keys    => [qw(name dd dd1 mm1 yy1 xs xcstr descr )]
    },
    'periodic repeaters with start and end dates' => {
        pattern => "$periodic_rx\\s+-\\s+$full_date_rx",
        keys    => [qw(name p   dd1 mm1   yy1 dd2 mm2  yy2 xs  xcstr descr )]
    },
    'dates with year' => {
        pattern => $full_date_rx,
        keys    => [qw(name dd mm yy xs xcstr descr )]
    },
    'anniversary dates' => {
        pattern => "$anniversary_date_rx",
        keys    => [qw(name dd mm yy xs xcstr descr )]
    },
    'dates without year' => {
        pattern => "$date_rx",
        keys    => [qw(name dd mm xs xcstr descr )]
    },
    'monthly repeaters' => {
        pattern => "$monthly_rx",
        keys    => [qw(name nn dd xs xcstr descr )]
    },
    'weekly repeaters' => {
        pattern => "$weekly_rx",
        keys    => [qw(name dd xs xcstr descr )]
    },
    'num-day-mon repeaters' => {
        pattern => "$numdaymon_rx",
        keys    => [qw(name dd dy mn xs xcstr descr )]
    },
    'periodic repeaters' => {
        pattern => "$periodic_rx",
        keys    => [qw(name p dd mm yy xs xcstr descr )]
    },
    'date monthly repeaters' => {
        pattern => "($days_rx)",
        keys    => [qw(name dd xs xcstr descr )]
    },
);

our $expanding = 0;    # recursion block

# reasonable defaults to produce a small calendar
our %defaults = (

    # normal HTML::CalendarMonthSimple options
    border             => 1,
    width              => 0,
    showdatenumbers    => 0,
    showweekdayheaders => 0,
    weekdayheadersbig  => undef,      # the default is ok
    cellalignment      => 'center',
    vcellalignment     => 'center',
    header             => undef,      # the default is ok
    nowrap             => undef,      # the default is ok
    sharpborders       => 1,
    cellheight         => undef,      # the default is ok

    #CSS
    tableclass       => 'calendar $month $year',
    cellclass        => 'day $day $month $year',
    weekdaycellclass => 'weekday',
    weekendcellclass => 'weekend',
    todaycellclass   => 'today',
    headerclass      => 'calendarHeader',

    # colors
    bgcolor                   => 'white',
    weekdaycolor              => undef,         # the default is ok
    weekendcolor              => 'lightgrey',
    todaycolor                => 'wheat',
    bordercolor               => 'black',
    weekdaybordercolor        => undef,         # the default is ok
    weekendbordercolor        => undef,         # the default is ok
    todaybordercolor          => undef,         # the default is ok
    contentcolor              => undef,         # the default is ok
    weekdaycontentcolor       => undef,         # the default is ok
    weekendcontentcolor       => undef,         # the default is ok
    todaycontentcolor         => undef,         # the default is ok
    headercolor               => 'wheat',
    headercontentcolor        => undef,         # the default is ok
    weekdayheadercolor        => undef,         # the default is ok
    weekdayheadercontentcolor => undef,         # the default is ok
    weekendheadercolor        => undef,         # the default is ok
    weekendheadercontentcolor => undef,         # the default is ok
    weekstartsonmonday        => '0',

    # other options not belonging to HTML::CalendarMonthSimple
    # order is: Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday
    daynames              => undef,
    lang                  => 'English',
    format                => undef,
    datenumberformat      => undef,
    todaydatenumberformat => undef,
    multidayformat        => undef,     # Default: display description unchanged
    eventbgcolor          => undef,
);

sub _initDefaults {
    my ( $web, $topic ) = @_;
    my $webColor = Foswiki::Func::getPreferencesValue( 'WEBBGCOLOR', $web );

    if ($webColor) {
        $defaults{todaycolor}  = $webColor;
        $defaults{headercolor} = $webColor;
    }

    # get defaults from CalendarPlugin topic
    my $v;
    foreach my $option ( keys %defaults ) {

        # read defaults from CalendarPlugin topic
        $v = Foswiki::Func::getPreferencesValue("CALENDARPLUGIN_\U$option\E")
          || undef;
        $defaults{$option} = $v if defined($v);
    }

    $defaults{topic} = $topic;
    $defaults{web}   = $web;

    $defaultsInitialized = 1;
}

sub _parseAllDates {
    my ( $patternname, $refBullets, $refDays ) = @_;
    ASSERT( ref($refBullets) eq 'ARRAY' ) if DEBUG;
    ASSERT( ref($refDays)    eq 'ARRAY' ) if DEBUG;

    return unless ( defined( $parse_definitions{$patternname} ) );
    return unless ( defined( $parse_definitions{$patternname}->{pattern} ) );

    my $datepattern = $parse_definitions{$patternname}->{pattern};
    my $pattern = "^\\s*\\*\\s+$datepattern(\\s+X\\s+{(.+)})?\\s+-\\s+(.*)\$";

    my @res = map {
        my %d;
        @d{ @{ $parse_definitions{$patternname}->{keys} } } =
          ( $patternname, map { $_ || '' } m/$pattern/ );
        \%d
      }
      grep { m/$pattern/ } @$refBullets;
    push( @$refDays, @res );

    # Remove the bullets we handled, so that when several patterns
    # match a line, only the first pattern is really honored.
    @{$refBullets} = grep { !m/$pattern/ } @{$refBullets};
}

sub _emptyxmap {
    my ( $y, $m ) = @_;
    my @ret;
    for my $d ( 1 .. Date::Calc::Days_in_Month( $y, $m ) ) {
        $ret[$d] = 1;
    }
    return @ret;
}

sub _fetchxmap {
    my ( $xlist, $y, $m ) = @_;
    my @ret = _emptyxmap( $y, $m );
    my @xcepts = split ',', $xlist;
    for my $xc (@xcepts) {
        if ( my @dparts = $xc =~ m/$full_date_rx\s*-\s*$full_date_rx/ ) {
            my ( $d1, $m1, $y1, $d2, $m2, $y2 ) = @dparts;
            $m1 = $months{$m1};
            $m2 = $months{$m2};
            if ( ( $m1 <= $m && $y1 <= $y ) && ( $m2 >= $m && $y2 >= $y ) ) {
                unless ( $m1 == $m && $y1 == $y ) {
                    $m1 = $m;
                    $y1 = $y;
                    $d1 = 1;
                }
                do {
                    $ret[$d1] = 0;
                    ( $y1, $m1, $d1 ) =
                      Date::Calc::Add_Delta_Days( $y1, $m1, $d1, 1 );
                } until ( $m1 != $m || ( $m1 == $m2 && $d1 > $d2 ) );
            }
        }
        elsif ( @dparts = $xc =~ m/$full_date_rx/ ) {
            my ( $d1, $m1, $y1 ) = @dparts;
            $m1 = $months{$m1};
            if ( $m1 == $m && $y1 == $y ) {
                $ret[$d1] = 0;
            }
        }
    }
    return @ret;
}

sub CALENDAR {
    my ( $session, $attributes, $topic, $web ) = @_;

    return if $expanding;
    local $expanding = 1;

    my $result = '';    # This is used to accumulate the result text

    _initDefaults( $web, $topic ) unless $defaultsInitialized;

    # read options from the %CALENDAR% tag
    my %options = %defaults;
    my $v;
    my $orgtopic = $options{topic};
    my $orgweb   = $options{web};
    foreach my $option ( keys %options ) {
        $v = $attributes->{$option} || undef;
        $options{$option} = $v if defined($v);
    }

    # get GMT offset
    my (
        $currentYear, $currentMonth,  $currentDay,
        $currentHour, $currentMinute, $currentSecond
    ) = Date::Calc::Today_and_Now(1);
    my $gmtoff = $attributes->{gmtoffset};
    if ($gmtoff) {
        $gmtoff += 0;
        (
            $currentYear, $currentMonth,  $currentDay,
            $currentHour, $currentMinute, $currentSecond
          )
          = Date::Calc::Add_Delta_YMDHMS( $currentYear, $currentMonth,
            $currentDay, $currentHour, $currentMinute, $currentSecond, 0, 0, 0,
            $gmtoff, 0, 0 );
    }

    # read fixed months/years
    my $m = $attributes->{month} || 0;
    my $y = $attributes->{year}  || 0;

    # Check syntax of year parameter. It can be blank (meaning the
    # current year), an absolute number, or a relative number (e.g.,
    # "+1", meaning next year).

    if ( !$y || $y =~ /^[-+]?\d+$/ ) {

        # OK
        $y = 0 if $y eq '';    # to avoid warnings in +=
                               # Add current year if year is 0 or relative
        $y += $currentYear if $y =~ /^([-+]\d+|0)$/;    # must come before $m !
    }
    else {
        return <<MESSAGE;

%<nop>CALENDAR{$attributes}% has invalid year specification.

MESSAGE
    }

    # Check syntax of month parameter. It can be blank (meaning the
    # current month), a month abbreviation, an absolute number, or a
    # relative number (e.g., "+1", meaning next month).

    if ( !$m || $m =~ /^[-+]?\d+$/ ) {

        # OK - absolute or relative number
        $m = 0 if $m eq '';    # to avoid warnings in +=
                               # Add current month if month is 0 or relative
        $m += $currentMonth if ( $m =~ /^([-+]\d+|0)$/ );
        ( $m += 12, --$y ) while $m <= 0;
        ( $m -= 12, ++$y ) while $m > 12;
    }
    elsif ( $m =~ /^(\w{3})$/ ) {

        # Could be month abbreviation
        if ( defined $months{$1} ) {

            # OK - month abbreviation
            $m = $months{$1};
        }
        else {
            return <<MESSAGE;

%<nop>CALENDAR{$attributes}% has invalid month specification.

MESSAGE
        }
    }
    else {
        return <<MESSAGE

%<nop>CALENDAR{$attributes}% has invalid month specification.

MESSAGE
    }

    # read and set the desired language
    my $lang = $attributes->{lang};
    $lang = $lang ? $lang : $defaults{lang};
    Date::Calc::Language( Date::Calc::Decode_Language($lang) );

    # Process "aslist" parameter (if set, display the calendar as a
    # list, not as a table)

    my $asList = $attributes->{aslist};

    if ($asList) {

        # If displaying as a list, force showdatenumbers to 1 so that the
        # Plugin can format them later.  This logic seems backwards, but
        # if showdatenumber is 0, the calendar initialization code below
        # will put date numbers into the contents of each day. Then, when
        # displaying the list, every day will be included in the list
        # because the contents are not "empty." This would produce an ugly
        # list. In contrast, if HTML::CalendarSimple is told to put the
        # date numbers on the calendar, this will be done outside of the
        # content. Therefore, we can later display only those days that
        # actually have events, at the cost of formatting the date numbers
        # again.

        $options{showdatenumbers} = 1;
        if ( !$options{format} ) {
            $options{format} = '$old - $description<br />$n';
        }
        if ( !$options{datenumberformat} ) {
            $options{datenumberformat} = '	* $day $mon $year';
        }
    }
    else {
        if ( !$options{format} ) {
            $options{format} = '$old<br /><small> $description </small>';
        }
        if ( !$options{datenumberformat} ) {
            $options{datenumberformat} = '$day';
        }
    }

    # Default todaydatenumberformat to datenumberformat if not otherwise set

    $options{todaydatenumberformat} = $options{datenumberformat}
      if ( !$options{todaydatenumberformat} );

    # Process "days" parameter (goes with aslist=1; specifies the
    # number of days of calendar data to list).  Default is 1.

    my $numDays = $attributes->{days};
    $numDays = 1 if ( !$numDays );

    # Process "months" parameter (goes with aslist=0; specifies the
    # number of months of calendar data to list) Default is 1.

    my $numMonths = $attributes->{months};
    $numMonths = 1 if ( !$numMonths );

    # Figure out last month/year to display. This calculation depends
    # upon whether we are doing a list display or calendar display.

    my $lastMonth    = $m + 0;
    my $lastYear     = $y + 0;
    my $listStartDay = 1;        # Starting day of the month for an event list

    if ($asList) {

        # Add the number of days past our start day. The start day is
        # today if the month being displayed is the current month. If
        # it is *not* the current month, then start with day 1 of the
        # starting month.
        # can be over-ridden using the day= attribute

        if ( ( $y != $currentYear ) && ( $m != $currentMonth ) ) {
            $listStartDay = 1;
        }
        else {
            $listStartDay = $currentDay;
        }
        my $d = $attributes->{day};
        if ( !$d || $d =~ /^(\d+)$/ ) {
            $listStartDay = $1 if ($d);
        }
        else {
            return <<MESSAGE;

%<nop>CALENDAR{$attributes}% has invalid day specification.

MESSAGE
        }
        ( $lastYear, $lastMonth ) =
          Date::Calc::Add_Delta_Days( $y, $m, $listStartDay, $numDays - 1 );
    }
    else {
        ( $lastYear, $lastMonth ) =
          Date::Calc::Add_Delta_YM( $y, $m, 1, 0, $numMonths - 1 );
    }

    # Before this was modified to do multiple months, there was a
    # clause to bail out early if there were no events, simply
    # returning a "blank" calendar. However, since the plugin can now
    # do multiple calendars, the loop to do so needs to be executed
    # even if there are no events to display (so multiple blank
    # calendars can be displayed!). A small optimization is lost, but
    # the number of times people display blank calendars will
    # hopefully be small enough that this won't matter.

    # These two hashes are used to keep track of multi-day events that
    # occur over month boundaries. This is needed for processing the
    # multidayformat. The counter variable is used in the loops for
    # identifying the events by ordinal number of their occurence. The
    # counter will produce the same result each time through the loop
    # since the text is read once (above).

    my %multidayeventswithyear    = ();
    my %multidayeventswithoutyear = ();

    # Read in the event list. Use %INCLUDE to get access control
    # checking right.
    my $text = join( "\n",
        map { '%INCLUDE{"' . $_ . '"}%' }
          split( /, */, $options{topic} ) );
    $text = Foswiki::Func::expandCommonVariables( $text, $topic, $web );

    # Loop, displaying one month at a time for the number of months
    # requested.

    while (( $y < $lastYear )
        || ( ( $y <= $lastYear ) && ( $m <= $lastMonth ) ) )
    {
        my $cal = new HTML::CalendarMonthSimple(
            month       => $m,
            year        => $y,
            today_year  => $currentYear,
            today_month => $currentMonth,
            today_date  => $currentDay
        );

        # set the day names in the desired language
        $cal->saturday( Date::Calc::Day_of_Week_to_Text(6) );
        $cal->sunday( Date::Calc::Day_of_Week_to_Text(7) );
        $cal->weekdays( map { Date::Calc::Day_of_Week_to_Text $_ } ( 1 .. 5 ) );

        $options{tableclass} = (
            _formatDate(
                $cal, $options{tableclass},
                Date::Calc::Date_to_Days( $cal->year(), $cal->month(), 1 ), ''
            )
        );
        $options{headerclass} = (
            _formatDate(
                $cal, $options{headerclass},
                Date::Calc::Date_to_Days( $cal->year(), $cal->month(), 1 ), ''
            )
        );
        $options{weekdaycellclass} = (
            _formatDate(
                $cal,
                $options{weekdaycellclass},
                Date::Calc::Date_to_Days( $cal->year(), $cal->month(), 1 ), ''
            )
        );
        $options{weekendcellclass} = (
            _formatDate(
                $cal,
                $options{weekendcellclass},
                Date::Calc::Date_to_Days( $cal->year(), $cal->month(), 1 ), ''
            )
        );
        $options{todaycellclass} = (
            _formatDate(
                $cal,
                $options{todaycellclass},
                Date::Calc::Date_to_Days( $cal->year(), $cal->month(), 1 ), ''
            )
        );

        my $p = '';
        while ( my ( $k, $v ) = each %options ) {
            $p = "HTML::CalendarMonthSimple::$k";
            $cal->$k($v) if defined(&$p);
        }

        # header color
        my $webColor =
          Foswiki::Func::getPreferencesValue( 'WEBBGCOLOR', $options{web} )
          || 'wheat';

        # Highlight today
        $options{todaycolor}  = $webColor;
        $options{headercolor} = $webColor;

        for (
            my $i = 1 ;
            $i <= Date::Calc::Days_in_Month( $cal->year(), $cal->month() ) ;
            $i++
          )
        {
            if (   ( $cal->month == $cal->today_month() )
                && ( $cal->year == $cal->today_year() )
                && ( $i == $cal->today_date() ) )
            {
                $cal->datecellclass(
                    $i,
                    _formatDate(
                        $cal,
                        $options{todaycellclass} . ' ' . $options{cellclass},
                        Date::Calc::Date_to_Days(
                            $cal->year(), $cal->month(), $i
                        ),
                        ''
                    )
                );
                if ( $cal->showdatenumbers == 0 ) {
                    $cal->setcontent( $i, _formatToday( $cal, $i, %options ) );
                }
            }
            else {
                $cal->datecellclass(
                    $i,
                    _formatDate(
                        $cal,
                        $options{cellclass},
                        Date::Calc::Date_to_Days(
                            $cal->year(), $cal->month(), $i
                        ),
                        ''
                    )
                );
                if ( $cal->showdatenumbers == 0 ) {
                    $cal->setcontent( $i,
                        _formatDateNumber( $cal, $i, %options ) );
                }
            }
        }

        # set names for days of the week
        if ( $options{showweekdayheaders} && defined( $options{daynames} ) ) {
            my @daynames = split( /\|/, $options{daynames} );
            if ( @daynames == 7 ) {
                $cal->weekdays(
                    $daynames[0], $daynames[1], $daynames[2],
                    $daynames[3], $daynames[4]
                );
                $cal->saturday( $daynames[5] );
                $cal->sunday( $daynames[6] );
            }
        }

        # parse events
        my @allDates = dateparse($text);

        #render events
        foreach my $d (@allDates) {
            my @xmap;
            if ( length( $d->{xcstr} ) > 9 ) {
                @xmap = _fetchxmap( $d->{xcstr}, $y, $m );
            }
            else {
                @xmap = _emptyxmap( $y, $m );
            }

            # collect all date intervals with year
            my $multidaycounter = 0;
            if ( $d->{name} eq 'intervals with year' ) {
                $multidaycounter++;    # Identify this event
                eval {
                    my $date1 =
                      Date::Calc::Date_to_Days( $d->{yy1}, $months{ $d->{mm1} },
                        $d->{dd1} );
                    my $date2 =
                      Date::Calc::Date_to_Days( $d->{yy2}, $months{ $d->{mm2} },
                        $d->{dd2} );

                    # Process events starting at the first day to be included in
                    # the list, or the first day of the month, whichever is
                    # appropriate

                    for my $day_loop (
                        ( defined $listStartDay ? $listStartDay : 1 )
                        .. Date::Calc::Days_in_Month( $y, $m ) )
                    {
                        my $date =
                          Date::Calc::Date_to_Days( $y, $m, $day_loop );
                        if (   $date1 <= $date
                            && $date <= $date2
                            && $xmap[$day_loop] )
                        {
                            _highlightMultiDay(
                                $cal,
                                $day_loop,
                                $d->{descr},
                                $date1, $date2, $date,
                                defined(
                                    $multidayeventswithyear{$multidaycounter}
                                ),
                                %options
                            );

                            # Mark this event as having been displayed
                            $multidayeventswithyear{$multidaycounter}++;
                        }
                    }
                };
                Foswiki::Func::writeWarning( PLUGINNAME . ": $@ " )
                  if $@ && (TRACE);
            }

            # then collect all intervals without year
            $multidaycounter = 0;
            if ( $d->{name} eq 'intervals without year' ) {
                $multidaycounter++;    # Identify this event
                eval {
                    my $date1 =
                      Date::Calc::Date_to_Days( $y, $months{ $d->{mm1} },
                        $d->{dd1} );
                    my $date2 =
                      Date::Calc::Date_to_Days( $y, $months{ $d->{mm2} },
                        $d->{dd2} );

                    # Process events starting at the first day to be included in
                    # the list, or the first day of the month, whichever is
                    # appropriate

                    for my $day_loop (
                        ( defined $listStartDay ? $listStartDay : 1 )
                        .. Date::Calc::Days_in_Month( $y, $m ) )
                    {
                        my $date =
                          Date::Calc::Date_to_Days( $y, $m, $day_loop );
                        if (   $date1 <= $date
                            && $date <= $date2
                            && $xmap[$day_loop] )
                        {
                            _highlightMultiDay(
                                $cal,
                                $day_loop,
                                $d->{descr},
                                $date1, $date2, $date,
                                defined(
                                    $multidayeventswithoutyear{$multidaycounter}
                                ),
                                %options
                            );

                            # Mark this event as having been displayed
                            $multidayeventswithoutyear{$multidaycounter}++;
                        }
                    }
                };
                Foswiki::Func::writeWarning( PLUGINNAME . ": $@ " )
                  if $@ && (TRACE);
            }

            # first collect all dates with year
            if ( $d->{name} eq 'dates with year' ) {
                eval {
                    if ( $d->{yy} == $y && $months{ $d->{mm} } == $m )
                    {
                        _highlightDay( $cal, $d->{dd}, $d->{descr}, %options );
                    }
                };
                Foswiki::Func::writeWarning( PLUGINNAME . ": $@ " )
                  if $@ && (TRACE);
            }

            # collect all anniversary dates
            if ( $d->{name} eq 'anniversary dates' ) {
                eval {
                    if ( $d->{yy} <= $y && $months{ $d->{mm} } == $m )
                    {

                        # Annotate anniversaries with the number of years
                        # since the original occurence. Do not annotate
                        # the first occurence (i.e., someone's birth date
                        # looks like "X's Birthday", not "X's Birthday
                        # (0)", but for subsequent years it will look like
                        # "X's Birthday (3)", meaning that they are 3
                        # years old.

                        my $elapsed = $y - $d->{yy};
                        my $elapsed_indicator =
                          ( $elapsed > 0 )
                          ? " ($elapsed)"
                          : '';
                        _highlightDay( $cal, $d->{dd},
                            $d->{descr} . $elapsed_indicator, %options );
                    }
                };
                Foswiki::Func::writeWarning( PLUGINNAME . ": $@ " )
                  if $@ && (TRACE);
            }

            # then collect all dates without year
            if ( $d->{name} eq 'dates without year' ) {
                eval {
                    if ( $months{ $d->{mm} } == $m && $xmap[ $d->{dd} ] )
                    {
                        _highlightDay( $cal, $d->{dd}, $d->{descr}, %options );
                    }
                };
                Foswiki::Func::writeWarning( PLUGINNAME . ": $@ " )
                  if $@ && (TRACE);
            }

            # collect monthly repeaters
            if ( $d->{name} eq 'monthly repeaters' ) {
                eval {
                    my $hd;
                    if ( $d->{nn} eq 'L' ) {
                        $d->{nn} = 6;
                        do {
                            $d->{nn}--;
                            $hd =
                              Date::Calc::Nth_Weekday_of_Month_Year( $y, $m,
                                $wdays{ $d->{dd} },
                                $d->{nn} );
                        } until ($hd);
                    }
                    else {
                        $hd =
                          Date::Calc::Nth_Weekday_of_Month_Year( $y, $m,
                            $wdays{ $d->{dd} },
                            $d->{nn} );
                    }
                    if (   $hd <= Date::Calc::Days_in_Month( $y, $m )
                        && $xmap[$hd] )
                    {
                        _highlightDay( $cal, $hd, $d->{descr}, %options );
                    }
                };
                Foswiki::Func::writeWarning( PLUGINNAME . ": $@ " )
                  if $@ && (TRACE);
            }

            # collect weekly repeaters with start and end dates
            if ( $d->{name} eq 'weekly repeaters with start and end dates' ) {
                eval {

                    my $date1 =
                      Date::Calc::Date_to_Days( $d->{yy1}, $months{ $d->{mm1} },
                        $d->{dd1} );
                    my $date2 =
                      Date::Calc::Date_to_Days( $d->{yy2}, $months{ $d->{mm2} },
                        $d->{dd2} );
                    my ( $ny, $nm );
                    my $hd =
                      Date::Calc::Nth_Weekday_of_Month_Year( $y, $m,
                        $wdays{ $d->{dd} }, 1 );
                    do {
                        my $date = Date::Calc::Date_to_Days( $y, $m, $hd );
                        if ( $xmap[$hd] && $date1 <= $date && $date <= $date2 )
                        {
                            _highlightDay( $cal, $hd, $d->{descr}, %options );
                        }
                        ( $ny, $nm, $hd ) =
                          Date::Calc::Add_Delta_Days( $y, $m, $hd, 7 );
                    } while ( $ny == $y && $nm == $m );
                };
                Foswiki::Func::writeWarning( PLUGINNAME . ": $@ " )
                  if $@ && (TRACE);
            }

            # collect weekly repeaters with start dates
            if ( $d->{name} eq 'weekly repeaters with start dates' ) {
                eval {
                    my $date1 =
                      Date::Calc::Date_to_Days( $d->{yy1}, $months{ $d->{mm1} },
                        $d->{dd1} );
                    my ( $ny, $nm );
                    my $hd =
                      Date::Calc::Nth_Weekday_of_Month_Year( $y, $m,
                        $wdays{ $d->{dd} }, 1 );
                    do {
                        my $date = Date::Calc::Date_to_Days( $y, $m, $hd );
                        if ( $xmap[$hd] && $date1 <= $date ) {
                            _highlightDay( $cal, $hd, $d->{descr}, %options );
                        }
                        ( $ny, $nm, $hd ) =
                          Date::Calc::Add_Delta_Days( $y, $m, $hd, 7 );
                    } while ( $ny == $y && $nm == $m );
                };
                Foswiki::Func::writeWarning( PLUGINNAME . ": $@ " )
                  if $@ && (TRACE);
            }

            # collect weekly repeaters
            if ( $d->{name} eq 'weekly repeaters' ) {
                eval {
                    my ( $ny, $nm );
                    my $hd =
                      Date::Calc::Nth_Weekday_of_Month_Year( $y, $m,
                        $wdays{ $d->{dd} }, 1 );
                    do {
                        if ( $xmap[$hd] ) {
                            _highlightDay( $cal, $hd, $d->{descr}, %options );
                        }
                        ( $ny, $nm, $hd ) =
                          Date::Calc::Add_Delta_Days( $y, $m, $hd, 7 );
                    } while ( $ny == $y && $nm == $m );
                };
                Foswiki::Func::writeWarning( PLUGINNAME . ": $@ " )
                  if $@ && (TRACE);
            }

            # collect num-day-mon repeaters
            if ( $d->{name} eq 'num-day-mon repeaters' ) {
                eval {
                    $d->{mn} = $months{ $d->{mn} };
                    if ( $d->{mn} == $m ) {
                        my $hd;
                        if ( $d->{dd} eq 'L' ) {
                            $d->{dd} = 6;
                            do {
                                $d->{dd}--;
                                $hd =
                                  Date::Calc::Nth_Weekday_of_Month_Year( $y, $m,
                                    $wdays{ $d->{dy} },
                                    $d->{dd} );
                            } until ($hd);
                        }
                        else {
                            $hd =
                              Date::Calc::Nth_Weekday_of_Month_Year( $y, $m,
                                $wdays{ $d->{dy} },
                                $d->{dd} );
                        }
                        if ( $xmap[$hd] ) {
                            _highlightDay( $cal, $hd, $d->{descr}, %options );
                        }
                    }
                };
                Foswiki::Func::writeWarning( PLUGINNAME . ": $@ " )
                  if $@ && (TRACE);
            }

            # collect periodic repeaters with start and end dates
            if ( $d->{name} eq 'periodic repeaters with start and end dates' ) {
                eval {
                    $d->{mm1} = $months{ $d->{mm1} };
                    while ( $d->{yy1} < $y
                        || ( $d->{yy1} == $y && $d->{mm1} < $m ) )
                    {
                        ( $d->{yy1}, $d->{mm1}, $d->{dd1} ) =
                          Date::Calc::Add_Delta_Days( $d->{yy1}, $d->{mm1},
                            $d->{dd1}, $d->{p} );
                    }
                    my $ldate =
                      Date::Calc::Date_to_Days( $d->{yy2}, $months{ $d->{mm2} },
                        $d->{dd2} );
                    while ( ( $d->{yy1} == $y ) && ( $d->{mm1} == $m ) ) {
                        my $date =
                          Date::Calc::Date_to_Days( $d->{yy1}, $d->{mm1},
                            $d->{dd1} );
                        if ( $xmap[ $d->{dd1} ] && ( $date <= $ldate ) ) {
                            _highlightDay( $cal, $d->{dd1}, $d->{descr},
                                %options );
                        }
                        ( $d->{yy1}, $d->{mm1}, $d->{dd1} ) =
                          Date::Calc::Add_Delta_Days( $d->{yy1}, $d->{mm1},
                            $d->{dd1}, $d->{p} );
                    }
                };
                Foswiki::Func::writeWarning( PLUGINNAME . ": $@ " )
                  if $@ && (TRACE);
            }

            # collect periodic repeaters
            if ( $d->{name} eq 'periodic repeaters' ) {
                eval {
                    $d->{mm} = $months{ $d->{mm} };
                    if (   ( $d->{mm} <= $m && $d->{yy} == $y )
                        || ( $d->{yy} < $y ) )
                    {
                        while ( $d->{yy} < $y
                            || ( $d->{yy} == $y && $d->{mm} < $m ) )
                        {
                            ( $d->{yy}, $d->{mm}, $d->{dd} ) =
                              Date::Calc::Add_Delta_Days( $d->{yy}, $d->{mm},
                                $d->{dd}, $d->{p} );
                        }
                        while ( $d->{yy} == $y && $d->{mm} == $m ) {
                            if ( $xmap[ $d->{dd} ] ) {
                                _highlightDay( $cal, $d->{dd}, $d->{descr},
                                    %options );
                            }
                            ( $d->{yy}, $d->{mm}, $d->{dd} ) =
                              Date::Calc::Add_Delta_Days( $d->{yy}, $d->{mm},
                                $d->{dd}, $d->{p} );
                        }
                    }
                };
                Foswiki::Func::writeWarning( PLUGINNAME . ": $@ " )
                  if $@ && (TRACE);
            }

            # collect date monthly repeaters
            if ( $d->{name} eq 'date monthly repeaters' ) {
                eval {
                    if (   $d->{dd} > 0
                        && $d->{dd} <= Date::Calc::Days_in_Month( $y, $m )
                        && $xmap[ $d->{dd} ] )
                    {
                        _highlightDay( $cal, $d->{dd}, $d->{descr}, %options );
                    }
                };
                Foswiki::Func::writeWarning( PLUGINNAME . ": $@ " )
                  if $@ && (TRACE);
            }

        }

        # Format the calendar as either a list or a table

        if ( !$asList ) {
            $result .= $cal->as_HTML . "\n";
        }
        else {
            if ( !$numDays ) {
                $numDays =
                  Date::Calc::Days_in_Month( $cal->year(), $cal->month() ) -
                  $cal->today_date() + 1;
            }
            my $day = $listStartDay;
            while ( $numDays > 0 ) {
                if ( $day >
                    Date::Calc::Days_in_Month( $cal->year(), $cal->month() ) )
                {

                    # End of month reached, reset the starting day
                    # (for the next month) and break out of the loop

                    $listStartDay = 1;
                    last;
                }
                my $content = $cal->getcontent($day);
                if ( $content && ( $content !~ m/^\s*$/ ) ) {

                    # Only display those days with events
                    if (   ( $cal->month == $cal->today_month() )
                        && ( $cal->year == $cal->today_year() )
                        && ( $day == $cal->today_date() ) )
                    {
                        $result .= _formatToday( $cal, $day, %options );
                    }
                    else {
                        $result .= _formatDateNumber( $cal, $day, %options );
                    }
                    $result .= $content;
                }
                $day++;
                $numDays--;
            }
        }

        # Advance to next month in preparation for possibly
        # constructing another calendar

        if ( $m < 12 ) {    # Same year
            $m++;
        }
        else {              # Go to next year
            $y++;
            $m = 1;
        }
    }
    return $result;
}

sub _highlightDay {
    my ( $c, $day, $description, %options ) = @_;
    my $old    = $c->getcontent($day);
    my $format = $options{format};

    $format =
      _formatDate( $c, $format,
        Date::Calc::Date_to_Days( $c->year(), $c->month(), $day ), '' );

    $format =~ s/\$description/$description/g;
    $format =~ s/\$web/$options{web}/g;
    $format =~ s/\$topic/$options{topic}/g;
    $format =~ s/\$day/$day/g;
    $format =~ s/\$old/$old/g if defined $old;
    $format =~ s/\$installWeb/$Foswiki::cfg{SystemWebName}/g;
    $format =~ s/\$n/\n/g;
    $c->datecolor( $day, $options{eventbgcolor} ) if ( $options{eventbgcolor} );
    $c->setcontent( $day, $format );
}

=pod

---++ StaticMethod _formatDate ($cal, $formatString, $date) -> $value
   * =$cal= A reference to the Date::Calc calendar in use.
   * =$formatString= twiki time date format, default =$day $month $year - $hour:$min=
   * =$date= The date (Date::Calc days value) of the date to format.
             At some point we should handle times, too.
=$formatString= supports:
   | $seconds | secs |
   | $minutes | mins |
   | $hours | hours |
   | $day | date |
   | $wday | weekday name |
   | $dow | day number (0 = Sunday) |
   | $week | week number |
   | $month | month name |
   | $mo | month number |
   | $year | 4-digit year |
   | $ye | 2-digit year |
   | $http | full HTTP header format date/time |
   | $email | full email format date/time |
   | $rcs | full RCS format date/time |
   | $epoch | seconds since 1st January 1970 |

Note that this description (and some of the code) is taken from the
core function formatTime. Ideally, we would be able to use that
function, but that function deals with time in seconds from the epoch
and this plugin uses a different notion of time.

=cut

sub _formatDate {
    my ( $cal, $formatString, $date ) = @_;
    Foswiki::Func::writeDebug("_formatDate: $formatString, $date") if (TRACE);
    my $outputTimeZone = 'gmtime';    # FIXME: Should be configurable
    my $value          = '';          # Return value for the function
    my ( $year, $mon, $day ) = Date::Calc::Add_Delta_Days( 1, 1, 1, $date - 1 );
    my ( $sec, $min, $hour ) =
      ( '00', '00', '00' );           # in the future, we might add times
    my $monthAbbr = sprintf '%0.3s', Date::Calc::Month_to_Text($mon);
    my $monthName = Date::Calc::Month_to_Text($mon);

    # Set a value for seconds since the epoch
    my $epochSeconds =
      Time::Local::timegm( $sec, $min, $hour, $day, $mon - 1, $year );

    # Set format to empty string if undefined to avoid possible warnings
    $formatString ||= '';

    # Unfortunately, there is a disconnect between the core
    # formatTime() function and Date::Calc when it comes to the day of
    # the week. formatTime() numbers from Sun=0 to Sat=6, whereas
    # Date::Calc numbers from Mon=1 to Sun=7. So, the Date::Calc value
    # is mapped to the formatTime() value here in setting up the $wdayName
    # variable.

    my $wday =
      ( 1, 2, 3, 4, 5, 6, 0 )
      [ &Date::Calc::Day_of_Week( $year, $mon, $day ) - 1 ];
    my $wdayAbbr =
      Date::Calc::Day_of_Week_Abbreviation(
        Date::Calc::Day_of_Week( $year, $mon, $day ) );
    my $weekday =
      Date::Calc::Day_of_Week_to_Text(
        Date::Calc::Day_of_Week( $year, $mon, $day ) );
    my $yearday = Date::Calc::Day_of_Year( $year, $mon, $day );

    #standard twiki date time formats

    # RCS format, example: "2001/12/31 23:59:59"
    $formatString =~ s/\$rcs/\$year\/\$mo\/\$day \$hour:\$min:\$sec/gi;

    # HTTP header format, e.g. "Thu, 23 Jul 1998 07:21:56 EST"
    # - based on RFC 2616/1123 and HTTP::Date; also used
    # by Foswiki::Net for Date header in emails.
    $formatString =~
      s/\$(http|email)/\$wday, \$day \$month \$year \$hour:\$min:\$sec \$tz/gi;

    # ISO Format, see spec at http://www.w3.org/TR/NOTE-datetime
    # e.g. "2002-12-31T19:30Z"
    my $tzd = '';
    if ( $outputTimeZone eq 'gmtime' ) {
        $tzd = 'Z';
    }
    else {

        #TODO:            $formatString = $formatString.
        # TZD  = time zone designator (Z or +hh:mm or -hh:mm)
    }
    $formatString =~ s/\$iso/\$year-\$mo-\$dayT\$hour:\$min$tzd/gi;

    # The matching algorithms here are the same as those in
    # Foswiki::Time::formatTime()

    $value = $formatString;
    $value =~ s/\$seco?n?d?s?/sprintf('%.2u',$sec)/gei;
    $value =~ s/\$minu?t?e?s?/sprintf('%.2u',$min)/gei;
    $value =~ s/\$hour?s?/sprintf('%.2u',$hour)/gei;
    $value =~ s/\$day/sprintf('%.2u',$day)/gei;
    $value =~ s/\$wday/$wdayAbbr/gi;
    $value =~ s/\$dow/$wday/gi;
    $value =~ s/\$week/_weekNumber($day,$mon-1,$year,$wday)/egi;
    $value =~ s/\$mont?h?/$monthAbbr/gi;
    $value =~ s/\$mo/sprintf('%.2u',$mon)/gei;
    $value =~ s/\$year?/sprintf('%.4u',$year)/gei;
    $value =~ s/\$ye/sprintf('%.2u',$year%100)/gei;
    $value =~ s/\$epoch/$epochSeconds/gi;

    # SMELL: how do we get the different timezone strings (and when
    # we add usertime, then what?)
    my $tz_str = ( $outputTimeZone eq 'servertime' ) ? 'Local' : 'GMT';
    $value =~ s/\$tz/$tz_str/geoi;

    # We add processing of a newline indicator
    $value =~ s/\$n/\n/g;

    return $value;
}

sub _weekNumber {
    my ( $day, $mon, $year, $wday ) = @_;

    # calculate the calendar week (ISO 8601)
    my $nextThursday =
      timegm( 0, 0, 0, $day, $mon, $year ) +
      ( 3 - ( $wday + 6 ) % 7 ) * 24 * 60 * 60;    # nearest thursday
    my $firstFourth = timegm( 0, 0, 0, 4, 0, $year );    # january, 4th
    return
      sprintf( '%.0f', ( $nextThursday - $firstFourth ) / ( 7 * 86400 ) ) + 1;
}

sub _formatDateNumber {
    my ( $cal, $day, %options ) = @_;
    my $format = $options{datenumberformat};
    if ( Date::Calc::check_date( $cal->year(), $cal->month(), $day ) ) {
        return _formatDate( $cal, $format,
            Date::Calc::Date_to_Days( $cal->year(), $cal->month(), $day ) );
    }
    else {
        return "";
    }
}

sub _formatToday {
    my ( $cal, $day, %options ) = @_;
    my $format = $options{todaydatenumberformat};
    return _formatDate( $cal, $format,
        Date::Calc::Date_to_Days( $cal->year(), $cal->month(), $day ) );
}

=pod

---++ StaticMethod _highlightMultiDay ($cal, $d, $description, $first, $last, $today, $seen, %options) -> $value
   * =$cal= is the current calendar
   * =$d= is the day (within the calendar/month) to highlight
   * =$description= is the description of the event
   * =$first= is the Date::Calc day value of the first day of the event
   * =$last= is the Date::Calc day value of the last day of the event
   * =$today= is the Date::Calc day value of the day being highlighted
   * =$seen= is non-zero (true) if this event has been already been indicated in this calendar
   * =%options= is a set of plugin options

The multidayformat option allows the description of each day of a
multiday event to be displayed differently.  This could be used to
visually or textually annotate the description to indicate
continuance from or to other days.

The option consists of a comma separated list of formats for each
type of day in a multiday event:

first, middle, last, middle-unseen, last-unseen

Where:

   * _first_ is the format used when the first day of the event is
    displayed
   * _middle_ is the format used when the day being displayed is not the
    first or last day
   * _last_ is the format used when the last day of the event is
    displayed
   * _middle-unseen_ is the format used when the day being displayed is
    not the first or last day of the event, but the preceding days of
    the event have not been displayed. For example, if an event runs
    from 29 Apr to 2 May and a May calendar is being displayed, then
    this format would be used for 1 May.
   * _last-unseen_ is the format used when the day being displayed is the
    last day of the event, but the preceding days of the event have not
    been displayed. For example, if an event runs from 29 Apr to 1 May
    and a May calendar is being displayed, then this format would be
    used for 1 May. Note that in the previous example (event from 29 Apr
    to 2 May), this format would *not* be used for a May calendar
    because the event was "seen" on 1 May; so, the _last_ format would
    be used for 2 May.

Missing formats will be filled in as follows:

   * _middle_ will be set to _first_
   * _last_ will be set to _middle_
   * _middle-unseen_ will be set to _middle_
   * _last-unseen_ will be set to _last_

Missing formats are different from empty formats. For example,

multidayformat="$description (until $last($day $month)),,"

specifies an empty format for _middle_ and _last_. The result of this
is that only the first day will be shown. Note that since an
unspecified _middle-unseen_ is set from the (empty) _middle_ format,
an event that begins prior to the calendar being displayed but ending
in the current calendar will not be displayed. In contrast,
multidayformat="$description" will simply display the description for
each day of the event; all days (within the scope of the calendar)
will be displayed.

The default format is to simply display the description of the event.

=cut

sub _highlightMultiDay {
    my ( $cal, $d, $description, $first, $last, $today, $seen, %options ) = @_;
    my $format = '$description';
    my $fmt    = $options{multidayformat};
    my @fmts;

    if ( !$fmt || ( $fmt =~ m/^\s*$/ ) ) {

       # If no special format set, just use the default format (the description)
        $fmts[0] = $fmts[1] = $fmts[2] = $fmts[3] = $fmts[4] = $format;
    }
    else {
        @fmts = split /,\s*/, $fmt, 5;    # Get the individual format variants
        for ( my $i = 0 ; $i < $#fmts ; $i++ ) {
            $fmts[$i] =~ s/\$comma/,/g;
            $fmts[$i] =~ s/\$percnt/%/g;
        }

        #
        # fill in the missing formats:
        #
        if ( $#fmts < 1 ) {
            $fmts[1] = $fmts[0];          # Set middle from first
        }
        if ( $#fmts < 2 ) {
            $fmts[2] = $fmts[1];          # Set last from middle
        }
        if ( $#fmts < 3 ) {
            $fmts[3] = $fmts[1];          # Set middle-unseen from middle
        }
        if ( $#fmts < 4 ) {
            $fmts[4] = $fmts[2];          # Set last-unseen from last
        }
    }

    # Annotate the description for a multiday event. An interval that
    # is only one day (i.e., $date1 and $date2 are equal) is not
    # marked as a multiday event. For an actual multiday event, the
    # description is modified according to the formats supplied for a
    # first, middle, or last day of the event.

    if ( $first == $last ) {

        # Skip annotation, not really a multi-day event.
    }
    elsif ( $today == $first ) {

        # This is the first day of the event
        $format = $fmts[0];
    }
    elsif ( $today == $last ) {
        if ( !$seen ) {
            $format = $fmts[4];
        }
        else {
            $format = $fmts[2];
        }
    }
    else {

        # This is a day in the middle of the event
        if ( !$seen ) {
            $format = $fmts[3];
        }
        else {
            $format = $fmts[1];
        }
    }

    # Substitute date/time information for the first and last dates,
    # if specified in the format.

    $format =~ s/\$first\(([^)]*)\)/_formatDate($cal, $1, $first)/gei;
    $format =~ s/\$last\(([^)]*)\)/_formatDate($cal, $1, $last)/gei;

    # Finally, plug in the event description

    $format =~ s/\$description/$description/;

    # If the format ends up non-blank, highlight the day.

    if ( $format && ( $format !~ m/^\s*$/ ) ) {
        _highlightDay( $cal, $d, $format, %options );
    }
}

#this is hopefully temporary, so we can refactor the actual code so that its testable.
#atm, it'll do something really naf :)
sub dateparse {
    my $text = shift;
    my @bullets = grep { /^\s+\*/ } split( /[\n\r]+/, $text );
    my @allDates;

    foreach my $name (
        'intervals with year',
        'intervals without year',
        'dates with year',
        'anniversary dates',
        'dates without year',
        'monthly repeaters',
        'weekly repeaters with start and end dates',
        'weekly repeaters with start dates',
        'weekly repeaters',
        'num-day-mon repeaters',
        'periodic repeaters with start and end dates',
        'periodic repeaters',
        'date monthly repeaters'
      )
    {
        _parseAllDates( $name, \@bullets, \@allDates );
    }

    print STDERR "no? " . join( "\n", @bullets ) . "\n" if TRACE;
    return @allDates;
}

1;
__END__
Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2001 Andrea Sterbini, a.sterbini@flashnet.it
Christian Schultze: debugging, relative month/year, highlight today
Akim Demaille <akim@freefriends.org>: handle date intervals.
Copyright (C) 2002-2006 Peter Thoeny, peter@thoeny.org
Copyright (C) 2008-2011 Foswiki Contributors
