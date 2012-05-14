# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2006-2009 Daniel ROhde
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
# For licensing info read LICENSE file in the Foswiki root.

package Foswiki::Plugins::TimeTablePlugin::TimeTable;

use strict;
###use warnings;

use CGI;
use Date::Calc qw(:all);
use POSIX qw(ceil);

use vars qw( $session $theTopic $theWeb $topic $web $attributes $text $refText
  $defaultsInitialized %defaults %options @renderedOptions @flagOptions %months %daysofweek
  @processedTopics @unknownParams %topicDefaults
  $months_rx $date_rx $daterange_rx $bullet_rx $bulletdate_rx $bulletdaterange_rx $dow_rx $day_rx
  $year_rx $monthyear_rx $monthyearrange_rx
  $hour_rx $minute_rx $am_rx $pm_rx $ampm_rx $time_rx $timerange_rx $timerangestrict_rx $duration_rx
  $dowrange_rx
  $cgi $pluginName
  $ttid
  %TIMEZONES
);

$pluginName = "TimeTablePlugin";

%TIMEZONES = (
    'A'    => +1,
    'ACDT' => +10.30,
    'ACST' => +9.30,
    'ADT'  => -3,
    'AEDT' => +11,
    'AEST' => +10,
    'AKDT' => -8,
    'AKST' => -9,
    'AST'  => -4,
    'AWST' => +8,
    'B'    => +2,
    'BST'  => +1,
    'C'    => +3,
    'CDT'  => -5,
    'CEDT' => +2,
    'CEST' => +2,
    'CET'  => +1,
    'CST'  => +10.30,
    'CST'  => +9.30,
    'CST'  => -6,
    'CXT'  => +7,
    'D'    => +4,
    'E'    => +5,
    'EDT'  => -4,
    'EEDT' => +3,
    'EEST' => +3,
    'EET'  => +2,
    'EST'  => +11,
    'EST'  => +10,
    'EST'  => -5,
    'F'    => +6,
    'G'    => +7,
    'GMT'  => 0,
    'H'    => +8,
    'HAA'  => -3,
    'HAC'  => -5,
    'HADT' => -9,
    'HAE'  => -4,
    'HAP'  => -7,
    'HAR'  => -6,
    'HAST' => -10,
    'HAT'  => -2.30,
    'HAY'  => -8,
    'HNA'  => -4,
    'HNC'  => -6,
    'HNE'  => -5,
    'HNP'  => -8,
    'HNR'  => -7,
    'HNT'  => -3.30,
    'HNY'  => -9,
    'I'    => +9,
    'IST'  => +1,
    'K'    => +10,
    'L'    => +11,
    'M'    => +12,
    'MDT'  => -6,
    'MESZ' => +2,
    'MEZ'  => +1,
    'MST'  => -7,
    'N'    => -1,
    'NDT'  => -2.30,
    'NFT'  => +11.30,
    'NST'  => -3.30,
    'O'    => -2,
    'P'    => -3,
    'PDT'  => -7,
    'PST'  => -8,
    'Q'    => -4,
    'R'    => -5,
    'S'    => -6,
    'T'    => -7,
    'U'    => -8,
    'UTC'  => 0,
    'V'    => -9,
    'W'    => -10,
    'WEDT' => +1,
    'WEST' => +1,
    'WET'  => 0,
    'WST'  => +8,
    'X'    => -11,
    'Y'    => -12,
    'Z'    => 0,

);

# =========================
sub initPlugin {
    $defaultsInitialized = 0;
}

# =========================
sub expand {
    ( $attributes, $text, $topic, $web ) = @_;
    $refText  = $text;
    $theWeb   = $web;
    $theTopic = $topic;

    &_initDefaults() unless $defaultsInitialized;

    $ttid++;

    return &_createUnknownParamsMessage() unless &_initOptions($attributes);

    &_initRegexs();

    return &_render( &_fetch( &_getTopicText() ) );

}

# =========================
sub inflate {
    my ( $attributes, $text, $topic, $web ) = @_;

    &_initDefaults() unless $defaultsInitialized;

    return &_createUnknownParamsMessage() unless &_initOptions($attributes);

    &_initRegexs();

    $cgi = &Foswiki::Func::getCgiQuery();

    my ( $starttime, $endtime, $duration, $fgcolor, $bgcolor ) =
      &_getTTCMValues($attributes);

    my $title =
        &_renderTime( $starttime, "12pm" )
      . ( defined $duration ? ' ' : '-' )
      . &_renderTime( ( defined $duration ? $duration : $endtime ), "12pm" )
      . ' / '
      . &_renderTime( $starttime, 24 )
      . ( defined $duration ? ' ' : '-' )
      . &_renderTime( ( defined $duration ? $duration : $endtime ), 24 );

    $fgcolor = '' unless defined $fgcolor;
    $bgcolor = '' unless defined $bgcolor;

    return $options{hidettcm} ? "" : $cgi->span(
        {
            -style => ( ( $fgcolor ne '' ) ? "color:$fgcolor;" : '' )
              . ( ( $bgcolor ne '' ) ? "background-color:$bgcolor" : '' ),
            -title => $title
        },
        &_renderTime($starttime)
          . ( defined $duration ? ' ' : '-' )
          . &_renderTime( ( defined $duration ? $duration : $endtime ) )
    );
}

# =========================
sub _getTTCMValues {
    my ($attributes) = @_;
    my $textattr = &Foswiki::Func::extractNameValuePair($attributes);

    my $duration = undef;
    my ( $timerange, $fgcolor, $bgcolor ) = split /\s*\,\s*/, $textattr;
    if ( !$bgcolor ) {
        $bgcolor = $fgcolor;
        $fgcolor = undef;
    }
    $timerange = "0-24" unless defined $timerange && $timerange ne "";
    my ( $starttime, $endtime ) = split /-/, $timerange;
    $starttime = &_getTime($starttime);
    if ( $endtime =~ m/($duration_rx)$/i ) {
        $duration = $endtime;
        $endtime  = undef;
    }
    else {
        $endtime  = &_getTime($endtime);
        $duration = undef;
    }

    return ( $starttime, $endtime, $duration, $fgcolor, $bgcolor );

}

# =========================
sub _initDefaults {
    my $webbgcolor = &Foswiki::Func::getPreferencesValue( "WEBBGCOLOR", $web )
      || '#33CC66';
    %defaults = (
        tablecaption => "Timetable",      # table caption
        lang         => 'English',        # default language
        topic        => "$web.$topic",    # topic with dates
        startdate    => undef,            # a start date
        starttime    => '7:00',           # a start time
        endtime      => '20:00',          # a end time
        timeinterval => '30',             # time interval in minutes
        month        => undef,
        year         => undef,
        daynames     => undef,
        monthnames   => undef,
        headerformat => '<font title="%A - %d %B %Y" size="-2">%a</font>',
        showweekend      => 1,              # show weekend
        descrlimit       => 7,              # per line description text limit
        showtimeline     => 'both',         #
        tableheadercolor => $webbgcolor,    #
        eventbgcolor     => '#AAAAAA',      #
        eventfgcolor     => 'black',        #
        name             => '&nbsp;',       # content of the first cell
        weekendbgcolor   => $webbgcolor,    #
        weekendfgcolor   => 'black',        #
        tablebgcolor     => 'white',        # table background color
        timeformat       => '24',           # timeformat 12 or 24
        unknownparamsmsg =>
'%RED% Sorry, some parameters are unknown: %UNKNOWNPARAMSLIST% %ENDCOLOR% <br/> Allowed parameters are (see %SYSTEMWEB%.'
          . $pluginName
          . ' topic for more details): %KNOWNPARAMSLIST%',
        displaytime      => 0,              # display time in description
        workingstarttime => '9:00',         #
        workingendtime   => '17:00',
        workingbgcolor   => 'white',
        workingfgcolor   => 'black',
        compatmode       => 0,              # compatibility mode
        cmheaderformat =>
          '<font title="%A - %d %B %y" size="-2">%a<br/>%e</font>'
        ,                                   # format of the header
        todaybgcolor =>
          undef
        ,   # background color for today cells (usefull for a defined startdate)
        todayfgcolor =>
          undef
        ,   # foreground color for today cells (usefull for a dark todaybgcolor)
        days               => 7,                      # XXX for later use
        nowfgcolor         => undef,
        nowbgcolor         => undef,
        forcestartdate     => 0,
        navprev            => '&lt;&lt;',
        navnext            => '&gt;&gt;',
        navprevtitle       => 'Previous %n day(s)',
        navnexttitle       => 'Next %n day(s)',
        wholetimerow       => 0,
        wholetimerowtext   => '24h',
        wholetimerowtitle  => 'whole-time events',
        wholetimerowpos    => 'top',
        cuttext            => '...',
        timezone           => 0,
        timezoneabbr       => undef,
        tablecolumnwidth   => undef,
        tabledatacellwidth => undef,
        tooltipformat      => '%DATE%<br/>%TIMERANGE%<br/> %DESCRIPTION% ',
        tooltipfixleft     => -163,
        tooltipfixtop      => 0,
        tooltipdateformat  => '%d %B %Y',
        fontsize           => 'xx-small',
        showmonthheader    => undef,
        monthheaderformat  => '%B',
        monthheaderbgcolor => undef,
        monthheaderfgcolor => 'black',
        clicktooltip       => 0,
        clicktooltiptext   => 'Click me for more information',
        _DEFAULT           => undef,
        tablewidth         => undef,
        tableborder        => undef,
        tablecellpadding   => 0,
        tablecellspacing   => 1,
        textwrapper        => 'browser',
        rotatetable        => 0,
        hidettcm           => 0,
    );

    @renderedOptions =
      ( 'tablecaption', 'name', 'navprev', 'navnext', 'wholetimerowtext' );
    @flagOptions = (
        'compatmode',   'showweekend',     'displaytime',  'forcestartdate',
        'wholetimerow', 'showmonthheader', 'clicktooltip', 'rotatetable',
        'hidettcm'
    );

    %months = (
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

    %daysofweek =
      ( Mon => 1, Tue => 2, Wed => 3, Thu => 4, Fri => 5, Sat => 6, Sun => 7 );

    $ttid = 0;

    %topicDefaults = ();

    $defaultsInitialized = 1;

}

# =========================
sub _initRegexs {

    # some regular expressions:
    $months_rx = join( '|', map( quotemeta($_), keys(%months) ) );
    $dow_rx    = join( '|', map( quotemeta($_), keys(%daysofweek) ) );
    $year_rx   = "[12][0-9]{3}";
    $monthyear_rx       = "($months_rx)\\s+$year_rx";
    $monthyearrange_rx  = "$monthyear_rx\\s+\\-\\s+$monthyear_rx";
    $day_rx             = "[0-3]?[0-9](\.|th)?";
    $date_rx            = "$day_rx\\s+($months_rx)\\s+$year_rx";
    $daterange_rx       = "$date_rx\\s*-\\s*$date_rx";
    $bullet_rx          = "^\\s+\\*\\s*";
    $bulletdate_rx      = "$bullet_rx$date_rx\\s*-";
    $bulletdaterange_rx = "$bulletdate_rx\\s*$date_rx\\s*-";

    $hour_rx   = "((2[0-4])|([01]?[0-9]))";
    $minute_rx = "[0-5]?[0-9]";
    $am_rx     = "[aA]\\.?[mM]\\.?";
    $pm_rx     = "[pP]\\.?[mM]\\.?";
    $ampm_rx   = "($am_rx|$pm_rx)";

    $duration_rx  = "\\d+([\\.:dhmDHM]\\d*)*[dhmDHM]";
    $time_rx      = "$hour_rx([\\.:]$minute_rx)?$ampm_rx?";
    $timerange_rx = "$time_rx\\s*-\\s*(($duration_rx)|($time_rx))";

    $timerangestrict_rx = "$time_rx-(($duration_rx)|($time_rx))";

    $dowrange_rx = "($dow_rx)\\s*-\\s*($dow_rx)";
}

# =========================
sub _initOptions {
    my ($attributes) = @_;

    my %params = &Foswiki::Func::extractParameters($attributes);

    my @allOptions = keys %defaults;

    # Check attributes:
    @unknownParams = ();
    foreach my $option ( keys %params ) {
        push( @unknownParams, $option )
          unless grep( /^\Q$option\E$/, @allOptions );
    }
    return 0 if $#unknownParams != -1;

    $cgi = &Foswiki::Func::getCgiQuery();

    # Setup options (attributes>plugin preferences>defaults):
    %options = ();
    foreach my $option (@allOptions) {
        my $v = $cgi->param("ttp_${option}");
        $v = $params{$option} unless defined $v;
        if ( defined $v ) {
            if ( grep /^\Q$option\E$/, @flagOptions ) {
                $options{$option} = ( $v !~ /(false|no|off|0|disable)/i );
            }
            else {
                $options{$option} = $v;
            }
        }
        else {
            if ( grep /^\Q$option\E$/, @flagOptions ) {
                $v = (
                    &Foswiki::Func::getPreferencesFlag(
                        "\U${pluginName}_$option\E")
                      || undef
                );
            }
            else {
                $v = &Foswiki::Func::getPreferencesValue(
                    "\U${pluginName}_$option\E");
            }
            $v = undef if ( defined $v ) && ( $v eq "" );
            $options{$option} = ( defined $v ) ? $v : $defaults{$option};
        }

    }

    # Render some options:
    foreach my $option (@renderedOptions) {
        if ( $options{$option} !~ /^(\s|\&nbsp\;)*$/ ) {
            $options{$option} =
              &Foswiki::Func::renderText( $options{$option}, $web );
        }
    }

    Date::Calc::Language( Date::Calc::Decode_Language( $options{lang} ) );

    # Setup language specific month and day names:
    for ( my $i = 1 ; $i < 13 ; $i++ ) {
        if ( $i < 8 ) {
            my $dt = Day_of_Week_to_Text($i);
            $daysofweek{$dt} = $i;
            $daysofweek{ Day_of_Week_Abbreviation($i) } = $i;
            $daysofweek{ substr( $dt, 0, 2 ) } = $i;
        }
        my $mt = Month_to_Text($i);
        $months{$mt} = $i;
        $months{ substr( $mt, 0, 3 ) } = $i;
    }

    # Setup user defined daynames:
    if (   ( defined $options{daynames} )
        && ( defined $defaults{daynames} )
        && ( $options{daynames} ne $defaults{daynames} ) )
    {
        my @dn = split /\s*\|\s*/, $options{daynames};
        if ( $#dn == 6 ) {
            for ( my $i = 1 ; $i < 8 ; $i++ ) {
                $daysofweek{ $dn[ $i - 1 ] } = $i;
            }
        }
    }

    # Setup user defined monthnames:
    if (   ( defined $options{monthnames} )
        && ( defined $defaults{monthnames} )
        && ( $options{monthnames} ne $defaults{monthnames} ) )
    {
        my @mn = split /\s*\|\s*/, $options{monthnames};
        if ( $#mn == 11 ) {
            for ( my $i = 1 ; $i < 13 ; $i++ ) {
                $months{ $mn[ $i - 1 ] } = $i;
            }
        }
    }

    # setup user defined time zone abbreviations:
    if ( defined $options{'timezoneabbr'} ) {
        my @abbrtz = split /\s*[\|,\;]\s*/, $options{'timezoneabbr'};
        foreach my $at (@abbrtz) {
            my ( $abbr, $tz ) = split /\s*:\s*/, $at, 2;
            $TIMEZONES{$abbr} = $tz if ( defined $abbr ) && ( defined $tz );
        }
    }

    @processedTopics = ();

    return 1;
}

# =========================
sub _getTime {
    my ($strtime) = @_;

    return undef unless defined $strtime;

    $strtime =~ s/^(\d+)(:(\d+))?//;
    my ( $hh, $mm ) = ( $1, $3 );
    $hh = 0 unless $hh;
    $mm = 0 unless $mm;

    $hh += 12
      if ( ( $hh < 12 ) && ( $strtime =~ m/$pm_rx/ ) )
      || ( ( $hh == 12 ) && ( $mm == 0 ) && ( $strtime =~ m/$am_rx/ ) );
    $hh = 0 if ( ( $hh == 12 ) && ( $mm > 0 ) && ( $strtime =~ m/$am_rx/ ) );

    return $hh * 60 + $mm;
}

# =========================
sub _fetch {

    my ($text) = @_;
    my %entries = ();

    my ( $dd, $mm, $yy ) = &_getStartDate();
    my ( $eyy, $emm, $edd ) = Add_Delta_Days( $yy, $mm, $dd, $options{'days'} );

    my $startDays = Date_to_Days( $yy,  $mm,  $dd );
    my $endDays   = Date_to_Days( $eyy, $emm, $edd );

    my $STARTTIME    = &_getTime( $options{'starttime'} );
    my $TIMEINTERVAL = $options{'timeinterval'};

    foreach my $line ( grep( /$bullet_rx/, split( /\r?\n/, $text ) ) ) {
        my $setup = undef;

        $line =~ s/$bullet_rx//g;

        my ( $defaultFgColor, $defaultBgColor ) = ( undef, undef );
        if ( $line =~ s/%TTSETUP{\"(.*?)\"}%//g ) {
            $setup = $1;
            my $defaultsRef = $topicDefaults{$setup};
            $defaultFgColor = $$defaultsRef{'eventfgcolor'}
              if defined $defaultsRef;
            $defaultBgColor = $$defaultsRef{'eventbgcolor'}
              if defined $defaultsRef;
        }

        my $excref = &_fetchExceptions( $line, $startDays, $endDays );

        my ( $fgcolor, $bgcolor ) = ( $defaultFgColor, $defaultBgColor );

        my ($duration);

        if ( $line =~ m/^($dowrange_rx)\s+\-\s+($timerange_rx)/ ) {
            ### DOW - DOW - hh:mm - hh:mm
            my ( $startdow, $enddow, $starttime, $endtime, $descr, $color ) =
              split /\s+\-\s+/, $line, 6;
            if ($color) {
                ( $fgcolor, $bgcolor ) = split( /\s*\,\s*/, $color );
                if ( ($fgcolor) && ( !$bgcolor ) ) {
                    $bgcolor = $fgcolor;
                    $fgcolor = $defaultFgColor;
                }
            }

            $startdow  = $daysofweek{$startdow};
            $enddow    = $daysofweek{$enddow};
            $starttime = &_getTime($starttime);
            if ( $endtime =~ m/$duration_rx/i ) {
                $duration = $endtime;
                $endtime  = undef;
            }
            else {
                $endtime  = &_getTime($endtime);
                $duration = undef;
            }
            for ( my $day = 0 ; $day < $options{'days'} ; $day++ ) {
                my ( $yy1, $mm1, $dd1 ) = Add_Delta_Days( $yy, $mm, $dd, $day );
                my $dow = Day_of_Week( $yy1, $mm1, $dd1 );
                if ( ( $dow >= $startdow ) && ( $dow <= $enddow ) ) {
                    push @{ $entries{ $day + 1 } },
                      {
                        'starttime' => $starttime,
                        'endtime'   => $endtime,
                        'nstarttime' =>
                          &_normalize( $starttime, $STARTTIME, $TIMEINTERVAL ),
                        'nendtime' =>
                          &_normalize( $endtime, $STARTTIME, $TIMEINTERVAL, 1 ),
                        'descr'     => $descr,
                        'fgcolor'   => $fgcolor,
                        'bgcolor'   => $bgcolor,
                        'setup'     => $setup,
                        'duration'  => $duration,
                        'longdescr' => $line
                      };
                    &_fixEntryTime( \%entries,
                        $entries{ $day + 1 }[ $#{ $entries{ $day + 1 } } ],
                        $day );
                }
            }

        }
        elsif ( $line =~ m/^($dow_rx)[^\-]+\-\s+($timerange_rx)/ ) {
            ### DOW[, DOW]* - hh:mm - hh:mm
            my ( $dowlist, $starttime, $endtime, $descr, $color ) =
              split /\s+\-\s+/, $line, 5;
            $starttime = &_getTime($starttime);
            if ( $endtime =~ m/$duration_rx/i ) {
                $duration = $endtime;
                $endtime  = undef;
            }
            else {
                $endtime  = &_getTime($endtime);
                $duration = undef;
            }
            if ($color) {
                ( $fgcolor, $bgcolor ) = split( /\s*\,\s*/, $color );
                if ( !defined $bgcolor ) {
                    $bgcolor = $fgcolor;
                    $fgcolor = $defaultFgColor;
                }
            }
            my @dowlistarr = split /[\s\,]+/, $dowlist;
            my ($cdow) = Day_of_Week( $yy, $mm, $dd );
            foreach my $dowtext (@dowlistarr) {
                my $dow = $daysofweek{$dowtext};
                next unless defined $dow;
                for (
                    my $day = $dow - $cdow ;
                    $day < $options{'days'} ;
                    $day += 7
                  )
                {

                    if ( $day >= 0 ) {
                        push @{ $entries{ $day + 1 } },
                          {
                            'starttime'  => $starttime,
                            'endtime'    => $endtime,
                            'nstarttime' => &_normalize(
                                $starttime, $STARTTIME, $TIMEINTERVAL
                            ),
                            'nendtime' => &_normalize(
                                $endtime, $STARTTIME, $TIMEINTERVAL, 1
                            ),
                            'descr'     => $descr,
                            'fgcolor'   => $fgcolor,
                            'bgcolor'   => $bgcolor,
                            'setup'     => $setup,
                            'duration'  => $duration,
                            'longdescr' => $line
                          };
                        &_fixEntryTime(
                            \%entries,
                            $entries{ $day + 1 }[ $#{ $entries{ $day + 1 } } ],
                            $day
                        );
                    }
                }
            }
        }
        elsif ( $options{'compatmode'} ) {

            &_fetchCompat( $line, \%entries, $excref, $setup );

        }

    }

    return \%entries;
}

# =========================
sub _setParams {
    $_[2]{ $_[1] } = $options{ $_[0] }
      if defined $options{ $_[0] } && $options{ $_[0] } !~ /^\s*$/;
}

# =========================
sub _getMouseAndTitleData {
    my ( $day, $min, $counter ) = @_;
    my ( $onmouseover, $onmouseout, $onclick, $title ) = ( "", "", "", "" );
    $onmouseover =
"ttpTooltipShow('TTP_DIV_${ttid}_${day}_${min}_${counter}', 'TTP_TD_${ttid}_${day}_${min}_${counter}',$options{'tooltipfixleft'},$options{'tooltipfixtop'},true);";
    $onmouseout = "ttpTooltipHide('TTP_DIV_${ttid}_${day}_${min}_${counter}');";
    if ( $options{'clicktooltip'} ) {
        $title       = $options{'clicktooltiptext'};
        $onclick     = $onmouseover;
        $onmouseover = "";
        $onmouseout  = "";
    }
    else {
        $title   = undef;
        $onclick = "";
    }
    return ( $onmouseover, $onmouseout, $onclick, $title );
}

# =========================
sub _renderEntry {
    my ( $mentry_ref, $day, $min, $counter, $rs ) = @_;
    my $text = "";
    my ( $onmouseover, $onmouseout, $onclick, $title ) =
      _getMouseAndTitleData( $day, $min, $counter );
    $text = $cgi->td(
        {
            -title   => $title,
            -colspan => $rs,
            -bgcolor => $$mentry_ref{'bgcolor'}
            ? $$mentry_ref{'bgcolor'}
            : $options{eventbgcolor},
            -id          => "TTP_TD_${ttid}_${day}_${min}_${counter}",
            -onclick     => $onclick,
            -onmouseover => $onmouseover,
            -onmouseout  => $onmouseout,
        },
        '&nbsp;'
    );

    return $text;
}

# =========================
sub _renderEntryWithTimeTitle {
    my ( $min, $entry ) = @_;
    return $cgi->div(
        {
                -title => &_renderTime( $min, '12am' ) . ' / '
              . &_renderTime( $min, 24 )
              . (
                ( defined $options{'timezone'} )
                  && ( $options{'timezone'} ne '0' )
                ? ' ' . $options{'timezone'}
                : ''
              )
        },
        $entry
    );
}

# =========================
sub _renderRotatedTable {
    my ($entries_ref) = @_;

    my ( $dd,  $mm,  $yy )  = &_getStartDate();
    my ( $tyy, $tmm, $tdd ) = Today();
    my $startDateDays = Date_to_Days( $yy,  $mm,  $dd );
    my $todayDays     = Date_to_Days( $tyy, $tmm, $tdd );

    my ( $starttime, $endtime ) =
      ( &_getTime( $options{'starttime'} ), &_getTime( $options{'endtime'} ) );
    my $tooltips = "";

    my $text = "";

    my ( $tr, $td );
    $text .= $cgi->a( { -name => "ttpa$ttid" }, "" );

    my $tableparms =
      { class => 'timeTablePluginTable', id => 'timeTablePluginTable' . $ttid };
    &_setParams( 'tablebgcolor',     'bgcolor',     $tableparms );
    &_setParams( 'tablewidth',       'width',       $tableparms );
    &_setParams( 'tableborder',      'border',      $tableparms );
    &_setParams( 'tablecellpadding', 'cellpadding', $tableparms );
    &_setParams( 'tablecellspacing', 'cellspacing', $tableparms );

    $text .= $cgi->start_table($tableparms);              # surrounding table
    $text .= $cgi->caption( $options{'tablecaption'} );

    my $namecell = $cgi->td(
        { -rowspan => 2, -align => 'right' },
        ( defined $options{'name'} ? $options{'name'} : "" ) . '<br/>'
          . _renderNav(0)
          . '&nbsp;'
          . _renderNav(1)
    );
    ## render day header
    $tr = "";
    my $htr = "";
    my $colspan = 1 + ( ( $endtime - $starttime ) / $options{'timeinterval'} );

    my %entryKeys;
    my %entryRows;
    for ( my $day = 0 ; $day < $options{'days'} ; $day++ ) {

        my $dowentries_ref = $$entries_ref{ $day + 1 };

        my ( $yy1, $mm1, $dd1 ) = Add_Delta_Days( $yy, $mm, $dd, $day );
        my $dow = Day_of_Week( $yy1, $mm1, $dd1 );
        my $days = Date_to_Days( $yy1, $mm1, $dd1 );
        my ( $bgcolor, $fgcolor ) = _getDayColors($day);

        $tr .= $cgi->th(
            {
                -colspan => $colspan,
                -style   => "color:$fgcolor;background-color:$bgcolor;"
            },
            _mystrftime( $yy1, $mm1, $dd1 )
        );
        if ( ( !$options{'showweekend'} ) && ( $dow > 5 ) ) {
            $htr .= $cgi->th(
                {
                    -colspan => $colspan,
                    -style   => "background-color:$bgcolor;color:$fgcolor;"
                },
                '&nbsp;'
            );
            next;
        }
        ## render hour header
        for (
            my $min = $starttime ;
            $min <= $endtime ;
            $min += $options{'timeinterval'}
          )
        {
            ( $bgcolor, $fgcolor ) =
              _getTimeColors( $min, $days == $todayDays );
            $htr .= $cgi->th(
                { style => "background-color:$bgcolor;color:$fgcolor;" },
                _renderEntryWithTimeTitle( $min, _renderTime($min) )
            );

            ## collect entries and initialize rows:
            my $mentries =
              &_getMatchingEntries( $dowentries_ref, $min,
                $options{'timeinterval'}, $starttime );
            foreach my $mentry_ref ( @{$mentries} ) {
                $entryKeys{ $$mentry_ref{'descr'} } = 1;
                $entryRows{ $$mentry_ref{'descr'} } = "";
            }
        }

    }
    my $timelinetop    = $cgi->Tr( $namecell . $tr ) . $cgi->Tr($htr);
    my $timelinebottom = $cgi->Tr( $namecell . $htr ) . $cgi->Tr($tr);

    $text .= $timelinetop if $options{'showtimeline'} =~ m/(left|top|both)/i;

    my %ignore;
    my $counter = 0;
    my %conflictitems;
    my %ignoreconflictitem;
    for ( my $day = 0 ; $day < $options{'days'} ; $day++ ) {
        my ( $yy1, $mm1, $dd1 ) = Add_Delta_Days( $yy, $mm, $dd, $day );
        my $dow = Day_of_Week( $yy1, $mm1, $dd1 );
        my $dowentries_ref = $$entries_ref{ $day + 1 };
        my ( $bgcolor, $fgcolor ) = _getDayColors($day);

        if ( ( $dow > 5 ) && ( !$options{'showweekend'} ) ) {
            foreach my $entry ( keys %entryKeys ) {
                $entryRows{$entry} .= $cgi->td(
                    {
                        -colspan => $colspan,
                        -style   => "background-color:$bgcolor;color:$fgcolor"
                    },
                    '&nbsp;'
                );
                for ( my $i = 0 ; $i <= $#{ $conflictitems{$entry} } ; $i++ ) {
                    $conflictitems{$entry}[$i] .= $cgi->td(
                        {
                            -colspan => $colspan,
                            -style => "background-color:$bgcolor;color:$fgcolor"
                        },
                        '&nbsp;'
                    );
                }
            }

            next;
        }
        for (
            my $min = $starttime ;
            $min <= $endtime ;
            $min += $options{'timeinterval'}
          )
        {
            my $mentries =
              &_getMatchingEntries( $dowentries_ref, $min,
                $options{'timeinterval'}, $starttime );
            my @visitedEntries;
            foreach my $mentry_ref ( @{$mentries} ) {
                my $descr = $$mentry_ref{'descr'};
                ## collect and render conflict entries:
                if ( defined $ignore{$descr}{$day}{$min} ) {
                    my $crow = "";

                    ## search next free slot:
                    my $ci = 0;
                    while ( $ignoreconflictitem{$descr}[$ci]{$day}{$min} ) {
                        $ci++;
                    }

                    $counter++;
                    ## get colspan (cs):
                    my $cs =
                      &_getEntryRows( $mentry_ref, $min, $starttime, $endtime,
                        $options{'timeinterval'} );

                    ## fill up if new row:
                    if ( $ci > $#{ $conflictitems{$descr} } ) {
                        ## fill up day(s) before current day:
                        for ( my $d = 0 ; $d < $day ; $d++ ) {
                            my ( $bg, $fg ) = _getDayColors($d);
                            my ( $yy2, $mm2, $dd2 ) =
                              Add_Delta_Days( $yy, $mm, $dd, $d );
                            my $fdow = Day_of_Week( $yy2, $mm2, $dd2 );
                            if ( !$options{'showweekend'} && ( $fdow > 5 ) ) {
                                $crow .= $cgi->td(
                                    {
                                        -colspan => $colspan,
                                        -style =>
                                          "background-color:$bg;color:$fg;"
                                    },
                                    '&nbsp;'
                                );

                            }
                            else {
                                for (
                                    my $m = $starttime ;
                                    $m <= $endtime ;
                                    $m += $options{'timeinterval'}
                                  )
                                {
                                    $crow .= $cgi->td(
                                        _renderEntryWithTimeTitle(
                                            $m, '&nbsp;'
                                        )
                                    );
                                }
                            }
                        }
                        ## fill up time before current time for the current day:
                        for (
                            my $m = $starttime ;
                            $m < $min ;
                            $m += $options{'timeinterval'}
                          )
                        {
                            my ( $bg, $fg ) = _getTimeColors($m);
                            $crow .= $cgi->td(
                                {"background-color:$bg;color:$fg;"},
                                _renderEntryWithTimeTitle( $m, '&nbsp;' )
                            );
                        }
                    }

                    ## render entry:
                    $crow .=
                      _renderEntry( $mentry_ref, $day, $min, $counter, $cs );

                    ## add new entry or extend existing entry:
                    if ( $ci > $#{ $conflictitems{$descr} } ) {
                        push( @{ $conflictitems{$descr} }, $crow );
                        $ci = $#{ $conflictitems{$descr} };
                    }
                    else {
                        $conflictitems{$descr}[$ci] .= $crow;
                    }
                    for ( my $i = 0 ; $i < $cs ; $i++ ) {
                        $ignoreconflictitem{$descr}[$ci]{$day}
                          { $min + ( $i * $options{'timeinterval'} ) } = 1;
                    }
                    $tooltips .=
                      &_renderTooltip( $mentry_ref, $day, $min, $counter, $yy1,
                        $mm1, $dd1 );
                }

                next if ( defined $ignore{$descr}{$day}{$min} );

                $counter++;

                my $rs =
                  &_getEntryRows( $mentry_ref, $min, $starttime, $endtime,
                    $options{'timeinterval'} );
                for ( my $i = 0 ; $i < $rs ; $i++ ) {
                    $ignore{$descr}{$day}
                      { $min + ( $i * $options{'timeinterval'} ) } = 1;
                }
                $entryRows{ $$mentry_ref{'descr'} } .=
                  _renderEntry( $mentry_ref, $day, $min, $counter, $rs );
                push @visitedEntries, $descr
                  unless grep /\Q$descr\E/, @visitedEntries;
                $tooltips .=
                  &_renderTooltip( $mentry_ref, $day, $min, $counter, $yy1,
                    $mm1, $dd1 );
            }
            foreach my $entry ( keys %entryKeys ) {
                ## fill up entries:
                $entryRows{$entry} .=
                  $cgi->td( _renderEntryWithTimeTitle( $min, '&nbsp;' ) )
                  unless ( defined $ignore{$entry}{$day}{$min} )
                  || grep /\@$entry\E/, @visitedEntries
                  || ( $options{'showweekend'} && $dow > 5 );
                ## fill up conflict items:
                for ( my $i = 0 ; $i <= $#{ $conflictitems{$entry} } ; $i++ ) {
                    $conflictitems{$entry}[$i] .=
                      $cgi->td( _renderEntryWithTimeTitle( $min, '&nbsp;' ) )
                      unless $ignoreconflictitem{$entry}[$i]{$day}{$min}
                          || ( $options{'showweekend'} && $dow > 5 );
                }
            }
        }
    }
    foreach my $entry ( sort keys %entryKeys ) {
        $text .= $cgi->Tr(
            $cgi->th(
                {
                    -align   => 'left',
                    -valign  => 'top',
                    -style   => 'white-space:nowrap;text-wrap:none;',
                    -rowspan => $#{ $conflictitems{$entry} } + 2
                },
                $entry
              )
              . $entryRows{$entry}
        );
        for ( my $i = 0 ; $i <= $#{ $conflictitems{$entry} } ; $i++ ) {
            $text .= $cgi->Tr( $conflictitems{$entry}[$i] );
        }
    }

    $text .= $timelinebottom
      if $options{'showtimeline'} =~ m/(right|bottom|both)/i;

    $text .= $cgi->end_table();
    $text .= $tooltips;

    $text =
      $cgi->div( { -class => 'timeTablePluginDiv', -style => 'overflow:auto;' },
        $text );
    return $text;

}

# =========================
sub _getDayColors {
    my ($day) = @_;

    my ( $dd, $mm, $yy ) = _getStartDate();
    my $startDateDays = Date_to_Days( $yy, $mm, $dd );
    my ( $tyy, $tmm, $tdd ) = Today();
    my $todayDays = Date_to_Days( $tyy, $tmm, $tdd );
    my ( $yy1, $mm1, $dd1 ) = Add_Delta_Days( $yy, $mm, $dd, $day );
    my $dow = Day_of_Week( $yy1, $mm1, $dd1 );

    my $colbgcolor =
      $options{ ( ( $dow > 5 ) ? 'weekendbgcolor' : 'tableheadercolor' ) };
    $colbgcolor = $options{'todaybgcolor'}
      if ( $options{'todaybgcolor'} )
      && ( $todayDays == $startDateDays + $day );
    $colbgcolor = '' unless defined $colbgcolor;
    my $colfgcolor = $options{ ( ( $dow > 5 ) ? 'weekendfgcolor' : 'black' ) };
    $colfgcolor = $options{'todayfgcolor'}
      if ( $options{'todayfgcolor'} )
      && ( $todayDays == $startDateDays + $day );
    $colfgcolor = '' unless defined $colfgcolor;
    return ( $colbgcolor, $colfgcolor );
}

# =========================
sub _render {
    my ($entries_ref) = @_;

    return _renderRotatedTable(@_) if ( $options{rotatetable} );

    my ( $dd,  $mm,  $yy )  = &_getStartDate();
    my ( $tyy, $tmm, $tdd ) = Today();
    my $startDateDays = Date_to_Days( $yy,  $mm,  $dd );
    my $todayDays     = Date_to_Days( $tyy, $tmm, $tdd );

    my ( $starttime, $endtime ) =
      ( &_getTime( $options{'starttime'} ), &_getTime( $options{'endtime'} ) );
    my $tooltips = "";

    my $text = "";

    my ( $tr, $td );
    $text .= $cgi->a( { -name => "ttpa$ttid" }, "" );

    my $tableparms =
      { class => 'timeTablePluginTable', id => 'timeTablePluginTable' . $ttid };
    &_setParams( 'tablebgcolor',     'bgcolor',     $tableparms );
    &_setParams( 'tablewidth',       'width',       $tableparms );
    &_setParams( 'tableborder',      'border',      $tableparms );
    &_setParams( 'tablecellpadding', 'cellpadding', $tableparms );
    &_setParams( 'tablecellspacing', 'cellspacing', $tableparms );

    $text .= $cgi->start_table($tableparms);              # surrounding table
    $text .= $cgi->caption( $options{'tablecaption'} );

    ### render weekday header:
    my $showmonthheader =
      (      ( !defined $options{'showmonthheader'} && $options{'compatmode'} )
          || ( $options{'showmonthheader'} ) );
    $tr = $cgi->td( { -rowspan => $showmonthheader ? 2 : 1, -align => 'right' },
        $options{'name'} . " " . &_renderNav(0) );
    if ($showmonthheader) {
        my $restdays = $options{days};
        my ( $yy1, $mm1, $dd1 ) = ( $yy, $mm, $dd );
        my $bgcolor =
          ( defined $options{'monthheaderbgcolor'} )
          ? $options{'monthheaderbgcolor'}
          : $options{'tableheadercolor'};
        my $fgcolor = $options{'monthheaderfgcolor'};
        while ( $restdays > 0 ) {
            my $daysdiff = Days_in_Month( $yy1, $mm1 ) - $dd1 + 1;
            $daysdiff = $restdays if ( $restdays - $daysdiff < 0 );
            my $weekenddays = 0;
            if ( !$options{'showweekend'} ) {
                for ( my $i = 0 ; $i < $daysdiff ; $i++ ) {
                    my ( $yy2, $mm2, $dd2 ) =
                      Add_Delta_Days( $yy1, $mm1, $dd1, $i );
                    my $dow = Day_of_Week( $yy2, $mm2, $dd2 );
                    if ( $dow > 5 ) {
                        $weekenddays++;
                        $i += 5 if $dow == 7;
                    }
                }
            }
            $tr .= $cgi->th(
                {
                    -colspan => $daysdiff - $weekenddays,
                    -title   => Month_to_Text($mm1) . ' ' . $yy1,
                    -style =>
"text-align:center;background-color: $bgcolor; color: $fgcolor"
                },
                &_mystrftime( $yy1, $mm1, $dd1, $options{'monthheaderformat'} )
            ) if $daysdiff - $weekenddays > 0;
            ( $yy1, $mm1, $dd1 ) =
              Add_Delta_Days( $yy1, $mm1, $dd1, $daysdiff );
            $restdays -= $daysdiff;
        }
        $tr .= $cgi->td( { rowspan => 2 }, &_renderNav(1) );
        $text .= $cgi->Tr($tr);
        $tr = "";
    }
    for ( my $day = 0 ; $day < $options{'days'} ; $day++ ) {
        my ( $yy1, $mm1, $dd1 ) = Add_Delta_Days( $yy, $mm, $dd, $day );
        my $dow = Day_of_Week( $yy1, $mm1, $dd1 );
        next if ( !$options{'showweekend'} ) && ( $dow > 5 );

        my ( $colbgcolor, $colfgcolor ) = _getDayColors($day);

        ###$tr .= $cgi->td({-style=>(($colfgcolor ne '')?"color:$colfgcolor":''), -bgcolor=>$colbgcolor,-valign=>"top", -align=>"center", -title=>&_mystrftime($yy1,$mm1,$dd1,$options{'tooltipdateformat'}), -width=>$options{'tablecolumnwidth'}?$options{'tablecolumnwidth'}:(90/$options{'days'}).'%'},&_mystrftime($yy1,$mm1,$dd1));
        $tr .= $cgi->td(
            {
                -style => ( ( $colfgcolor ne '' ) ? "color:$colfgcolor" : '' ),
                -bgcolor => $colbgcolor,
                -valign  => "top",
                -align   => "center",
                -title   => &_mystrftime(
                    $yy1, $mm1, $dd1, $options{'tooltipdateformat'}
                ),
                -width => $options{'tablecolumnwidth'}
                ? $options{'tablecolumnwidth'}
                : ''
            },
            &_mystrftime( $yy1, $mm1, $dd1 )
        );
    }
    $tr .= $cgi->td( &_renderNav(1) ) unless $showmonthheader;
    $text .= $cgi->Tr($tr);
    $text .= "\n";

    ### render time line:
    $tr = "";
    $tr .= $cgi->td(
        { -valign => "top", -align => 'right' },
        (
              $options{'showtimeline'} =~ m/(left|both)/i
            ? &_renderTimeline()
            : "&nbsp;"
        )
    );

    my $wtrow = "";

    ### render timetable:
    for ( my $day = 0 ; $day < $options{'days'} ; $day++ ) {
        my ( $yy1, $mm1, $dd1 ) = Add_Delta_Days( $yy, $mm, $dd, $day );
        my $dow = Day_of_Week( $yy1, $mm1, $dd1 );
        next if ( !$options{'showweekend'} ) && ( $dow > 5 );
        my $dowentries_ref = $$entries_ref{ $day + 1 };

        my $colbgcolor =
          $options{ ( ( $dow > 5 ) ? 'weekendbgcolor' : 'tablebgcolor' ) };
        $colbgcolor = $options{'todaybgcolor'}
          if ( $options{'todaybgcolor'} )
          && ( $todayDays == $startDateDays + $day );
        my $colfgcolor =
          $options{ ( ( $dow > 5 ) ? 'weekendfgcolor' : 'black' ) };
        $colfgcolor = $options{'todayfgcolor'}
          if ( $options{'todayfgcolor'} )
          && ( $todayDays == $startDateDays + $day );

        my ( $itr, $itd );

        if ( $options{'wholetimerow'} ) {
            $itr = "";
            my $wtentries = &_getWholeTimeEntries($dowentries_ref);
            if ( $#$wtentries > -1 ) {
                $itr = $cgi->start_table(
                    {
                        -bgcolor     => $colbgcolor,
                        -cellpadding => '0',
                        -cellspacing => '1',
                        -height      => "100%"
                    }
                );
                my $counter = 0;
                foreach my $wtentry_ref ( @{$wtentries} ) {
                    $counter++;
                    my ( $text, $title ) = &_renderText( $wtentry_ref, 1, 0 );
                    my ( $onmouseover, $onmouseout, $onclick );
                    $onmouseover =
"ttpTooltipShow('TTP_DIV_${ttid}_${day}_W_${counter}', 'TTP_TD_${ttid}_${day}_W_${counter}',"
                      . int( $options{'tooltipfixleft'} ) . ","
                      . int( $options{'tooltipfixtop'} )
                      . ",true);";
                    $onmouseout =
                      "ttpTooltipHide('TTP_DIV_${ttid}_${day}_W_${counter}');";
                    if ( $options{'clicktooltip'} ) {
                        $title       = $options{'clicktooltiptext'};
                        $onclick     = $onmouseover;
                        $onmouseover = "";
                        $onmouseout  = "";
                    }
                    else {
                        $title   = undef;
                        $onclick = "";
                    }
                    $tooltips .=
                      &_renderTooltip( $wtentry_ref, $day, 'W', $counter, $yy1,
                        $mm1, $dd1 );
                    $tooltips .=
                      &_renderTooltip( $wtentry_ref, $day, 'W2', $counter, $yy1,
                        $mm1, $dd1 )
                      if $options{'wholetimerow'}
                          && ( $options{'wholetimerowpos'} =~
                              m/^(bottom|both)$/i );
                    my $style =
                      $options{'textwrapper'} =~ /^plugin$/i
                      ? 'white-space: nowrap;'
                      : '';
                    $itr .= $cgi->Tr(
                        $cgi->td(
                            {
                                -style   => $style,
                                -valign  => "top",
                                -bgcolor => $$wtentry_ref{'bgcolor'}
                                ? $$wtentry_ref{'bgcolor'}
                                : $options{eventbgcolor},
                                -title => $title,
                                -id    => "TTP_TD_${ttid}_${day}_W_${counter}",
                                -onclick     => $onclick,
                                -onmouseover => $onmouseover,
                                -onmouseout  => $onmouseout,
                            },
                            $text
                        )
                    );
                }
                $itr .= $cgi->end_table();
            }
            else {
                $itr = '&nbsp;';
            }
            $wtrow .= $cgi->td( { -bgcolor => $colbgcolor }, $itr );
        }

        if ( !defined $dowentries_ref ) {
            $tr .= $cgi->td( { -bgcolor => $colbgcolor }, '&nbsp;' );
            next;
        }
        ###$td = $cgi->start_table({-rules=>"rows", -border=>"1",-cellpadding=>'0',-cellspacing=>'0', -height=>"100%"});
        ###$td = $cgi->start_table({-bgcolor=>"#fafafa", -cellpadding=>'0',-cellspacing=>'1', -height=>"100%"});
        $td = $cgi->start_table(
            {
                -width       => '100%',
                -bgcolor     => $colbgcolor,
                -cellpadding => '0',
                -cellspacing => '1',
                -height      => "100%"
            }
        );    # XXXX data table

        for (
            my $min = $starttime ;
            $min <= $endtime ;
            $min += $options{'timeinterval'}
          )
        {
            my $mentries =
              &_getMatchingEntries( $dowentries_ref, $min,
                $options{'timeinterval'}, $starttime );
            $itr = "";
            if ( $#$mentries > -1 ) {
                my $rs;
                my $counter = 0;
                foreach my $mentry_ref ( @{$mentries} ) {
                    $counter++;
                    my $fillRows = &_countConflicts(
                        $mentry_ref, $dowentries_ref,
                        $starttime,  $options{'timeinterval'}
                    );

                    $rs =
                      &_getEntryRows( $mentry_ref, $min, $starttime, $endtime,
                        $options{'timeinterval'} );

                    my ( $text, $title ) =
                      &_renderText( $mentry_ref, $rs, $fillRows );
                    $tooltips .=
                      &_renderTooltip( $mentry_ref, $day, $min, $counter, $yy1,
                        $mm1, $dd1 );
                    my ( $onmouseover, $onmouseout, $onclick );
                    ( $onmouseover, $onmouseout, $onclick, $title ) =
                      _getMouseAndTitleData( $day, $min, $counter );
                    my $style =
                      $options{'textwrapper'} =~ /^plugin$/i
                      ? 'white-space: nowrap;'
                      : '';
                    $itr .= $cgi->td(
                        {
                            -style   => $style,
                            -valign  => "top",
                            -bgcolor => $$mentry_ref{'bgcolor'}
                            ? $$mentry_ref{'bgcolor'}
                            : $options{eventbgcolor},
                            -rowspan => $rs + $fillRows,
                            -title   => $title,
                            -width   => $options{'tabledatacellwidth'}
                            ? $options{'tabledatacellwidth'}
                            : "",
                            -id => "TTP_TD_${ttid}_${day}_${min}_${counter}",
                            -onclick     => $onclick,
                            -onmouseover => $onmouseover,
                            -onmouseout  => $onmouseout,
                        },
                        $text
                    );
                }
                $td .= $cgi->Tr($itr) . "\n";
                $itr = $cgi->td( { -title => &_renderTime($min) }, '&nbsp;' );
                ##$itr=$cgi->td({-valign=>'bottom', -align=>'left'}, '<font size="-4">'.&_renderTime($min).'</font>&nbsp;'); ## DEBUG
                ##$itr=$cgi->td('X'); ## DEBUG
                $td .= $cgi->Tr($itr) . "\n";
            }
            else {
                $itr =
                  $cgi->td( { -title => &_renderTime($min), -style => '' },
                    '&nbsp;' );
                ##$itr=$cgi->td({-valign=>'bottom', -align=>'left'}, '<font size="-4">'.&_renderTime($min).'</font>&nbsp;'); ## DEBUG
                $td .= $cgi->Tr($itr) . "\n";
            }
        }

        $td .= $cgi->end_table();
        $tr .= $cgi->td( { -valign => "top" }, $td );

    }
    $tr .= $cgi->td( { -valign => "top" }, &_renderTimeline() )
      if ( $options{'showtimeline'} =~ m/(both|right)/i );

    if ( $options{'wholetimerow'} ) {
        if ( $options{'showtimeline'} =~ m/(both|left)/i ) {
            $wtrow = $cgi->td(
                {
                    -align   => 'right',
                    -valign  => "top",
                    -bgcolor => $options{'tableheadercolor'}
                },
                $cgi->div(
                    { -title => $options{'wholetimerowtitle'} },
                    $options{'wholetimerowtext'}
                )
            ) . $wtrow;
        }
        else {
            $wtrow = $cgi->td() . $wtrow;    ## nav
        }
        $wtrow .= $cgi->td(
            {
                -align   => 'left',
                -valign  => "top",
                -bgcolor => $options{'tableheadercolor'}
            },
            $cgi->div(
                { -title => $options{'wholetimerowtitle'} },
                $options{'wholetimerowtext'}
            )
        ) if ( $options{'showtimeline'} =~ m/(both|right)/i );

    }
    $text .= $cgi->Tr( { -valign => 'top' }, $wtrow )
      if $options{'wholetimerow'}
          && ( $options{'wholetimerowpos'} =~ m/^(top|both)$/i );
    $text .= $cgi->Tr($tr);
    if ( $options{'wholetimerow'}
        && ( $options{'wholetimerowpos'} =~ m/^(bottom|both)$/i ) )
    {
        $wtrow =~ s/_W_/_W2_/sg;
        $text .= $cgi->Tr( { -valign => 'top' }, $wtrow );
    }

    $text .= $cgi->end_table();
    $text .= $tooltips;
    $text = $cgi->div(
        {
            -class => 'timeTablePluginTable',
            -style => "font-size:$options{'fontsize'};overflow:auto;"
        },
        $text
    );

    return $text;
}

# =========================
sub _renderNav {
    my ($next) = @_;
    my $nav = "";
    return "" if !$options{'compatmode'};
    my $query = &Foswiki::Func::getCgiQuery();

    my $ttppage =
        $query->param( 'ttppage' . $ttid )
      ? &_parseInt( $query->param( 'ttppage' . $ttid ) )
      : 0;

    $ttppage += ( $next ? +1 : -1 );

    my $newcgi = new CGI($cgi);

    if ( $ttppage == 0 ) {
        $newcgi->delete( 'ttppage' . $ttid );
    }
    else {
        $newcgi->param( -name => 'ttppage' . $ttid, -value => $ttppage );
    }

    $newcgi->delete('contenttype');

    my $href = $newcgi->self_url();
    $href =~ s/\#.*$//;
    $href .= "#ttpa$ttid";

    my $title = $options{ ( $next ? 'navnexttitle' : 'navprevtitle' ) };
    $title =~ s/\%n/$options{'days'}/g;

    if ($next) {
        $nav .=
          "&nbsp;"
          . $cgi->a( { -href => $href, -title => $title },
            $options{'navnext'} );
    }
    else {
        $nav .=
          "&nbsp;"
          . $cgi->a( { -href => $href, -title => $title },
            $options{'navprev'} );
    }
    return $nav;
}

# =========================
sub _parseInt {
    my ($val) = @_;
    return $val unless defined $val;
    if ( $val =~ m/^([\+\-]?\d+)$/ ) {
        $val = $1;
    }
    else {
        $val = undef;
    }
    return $val;
}

# =========================
sub _renderTimeRange {
    my ($mentry_ref) = @_;
    my ( $mst, $met, $md ) = (
        $$mentry_ref{'starttime'},
        $$mentry_ref{'endtime'}, $$mentry_ref{'duration'}
    );
    my $setup         = $$mentry_ref{'setup'};
    my $topicSetupRef = $topicDefaults{$setup} if defined $setup;
    my $timezone      = $$topicSetupRef{'timezone'} if defined $topicSetupRef;
    $timezone = 0 unless defined $timezone;
    my $tz = "";
    if ( defined $TIMEZONES{$timezone} ) {
        $tz = " $timezone";
    }
    else {
        my $otz =
          ( defined $TIMEZONES{ $options{'timezone'} } )
          ? $TIMEZONES{ $options{'timezone'} }
          : $options{'timezone'};
        $tz =
             ( $timezone - $otz != 0 )
          && ( abs($timezone) < 12 )
          ? sprintf( " DTZ%+.1f", $timezone - $otz )
          : '';
    }
    return
        &_renderTime($mst)
      . ( defined $met ? '-' : ' ' )
      . &_renderTime( ( defined $met ? $met : $md ) )
      . $tz;

}

# =========================
sub _renderText {
    my ( $mentry_ref, $rs, $fillRows ) = @_;
    my $tddata = "";

    my $setup = $$mentry_ref{'setup'};
    my $topicSetupRef = $topicDefaults{$setup} if defined $setup;

    my $trange = ' (' . &_renderTimeRange($mentry_ref) . ')';

    my $title = (
          $$mentry_ref{'longdescr'}
        ? $$mentry_ref{'longdescr'}
        : $$mentry_ref{'descr'}
    );
    $title .= $trange;

    $title = Foswiki::Func::renderText( $title, $web );
    $title =~ s/<\/?\w[^>]*>//g;

    ### $title.=" (rows=$rs, fillRows=$fillRows)"; ## DEBUG

    my $text = $$mentry_ref{'descr'};

    $text =~ s/<\/?\w[^>]*>//g;

    $text .= $trange if $options{'displaytime'};

    my $style = 'color:'
      . (
          $$mentry_ref{'fgcolor'}
        ? $$mentry_ref{'fgcolor'}
        : $options{'eventfgcolor'}
      );
    my $descrlimit = $options{'descrlimit'};
    if ( $options{'textwrapper'} =~ /^plugin$/i ) {
        my $nt = "";
        for ( my $l = 0 ; $l < $rs ; $l++ ) {
            my $sub;
            my $offset = $l * $descrlimit;
            last if $offset > length($text);
            $sub = substr( $text, $offset, $descrlimit );
            last if ( length($sub) < 1 );
            $nt .=
              (      ( $l == ( $rs - 1 ) )
                  && ( length( substr( $text, $offset ) ) > $descrlimit ) )
              ? substr( $sub, 0, $descrlimit - length( $options{'cuttext'} ) )
              . $options{'cuttext'}
              : $sub;
            $nt .= '<br/>' unless $l == $rs - 1;
        }
        $text = '<noautolink>' . $nt . '</noautolink>';
    }
    else {
        my $height = &_calcDivHeight($rs);
        my $width =
          ( defined $descrlimit && $descrlimit !~ /^\s*$/ )
          ? $descrlimit . 'em'
          : '';
        $style .=
          ';width:' . $width . ';height:' . $height . ';overflow:hidden';
    }
    $tddata .= $cgi->div( { -style => $style }, " $text " );

    return ( $tddata, $title );
}

# =========================
sub _calcDivHeight {
    my ($rows) = @_;
    my $hf     = 1.4;
    my $unit   = 'em';
    my $size   = 0;
    if ( $options{'fontsize'} =~ /^([\d\.]+)(\w+)$/i ) {
        ( $size, $unit ) = ( $1, $2 );
    }
    if ( $unit =~ /^em$/i ) {
        $hf -= $size;
    }
    elsif ( $options{'fontsize'} =~ /(large|medium)/i ) {
        $hf = 0;
    }
    else {    # pt, px, cm,mm,inch,...
        $hf = $size;
    }
    my $height = $rows * $hf;
    if ( $height < 1.4 ) {
        $height = 1.4;
        $unit   = 'em';
    }
    return "$height$unit";

}

# =========================
sub _renderTooltip {
    my ( $mentry_ref, $day, $min, $c, $yy, $mm, $dd ) = @_;
    my $tooltip = "";
    my ( $bgcolor, $fgcolor ) =
      ( $$mentry_ref{'bgcolor'}, $$mentry_ref{'fgcolor'} );

    $bgcolor = $options{'eventbgcolor'} unless defined $bgcolor;
    $fgcolor = $options{'eventfgcolor'} unless defined $fgcolor;

    my $text = $options{'tooltipformat'};
    $text =~ s/\%DESCRIPTION\%/$$mentry_ref{'descr'}/sg;
    $text =~ s/\%LONGDESCRIPTION\%/$$mentry_ref{'longdescr'}/sg;
    $text =~ s/\%TIMERANGE\%/&_renderTimeRange($mentry_ref)/esg;
    $text =~
      s/\%DATE\%/&_mystrftime($yy,$mm,$dd,$options{'tooltipdateformat'})/esg;

    my ( $onmouseover, $onmouseout, $onclick );
    $onmouseover =
"ttpTooltipShow('TTP_DIV_${ttid}_${day}_${min}_${c}', 'TTP_TD_${ttid}_${day}_${min}_${c}',$options{'tooltipfixleft'},$options{'tooltipfixtop'},true);";
    $onmouseout = "ttpTooltipHide('TTP_DIV_${ttid}_${day}_${min}_${c}');";
    $onclick    = "";
    if ( $options{'clicktooltip'} ) {
        $onclick    = $onmouseout;
        $onmouseout = "";
    }

    $tooltip .= $cgi->div(
        {
            -id    => "TTP_DIV_${ttid}_${day}_${min}_${c}",
            -class => "timeTablePluginToolTips",
            -style =>
"visibility:hidden;position:absolute;top:0;left:0;z-index:2;padding: 3px; border: solid 1px; color: $fgcolor; background-color: $bgcolor;",
            -onclick     => $onclick,
            -onmouseover => $onmouseover,
            -onmouseout  => $onmouseout,
        },
        $text
    );

    return $tooltip;
}

# =========================
sub _getTimeColors {
    my ( $min, $enableNowColors ) = @_;
    my ( $wst, $wet )             = (
        &_getTime( $options{'workingstarttime'} ),
        &_getTime( $options{'workingendtime'} )
    );
    my ( $bla, $minutes, $hours ) = localtime();
    my ($now) = $minutes + ( 60 * $hours );
    my $bgcolor =
      ( ( $min >= $wst ) && ( $min <= $wet ) )
      ? $options{'workingbgcolor'}
      : $options{'tableheadercolor'};
    my $fgcolor = $options{'workingfgcolor'};
    if (   $enableNowColors
        && ( $now >= $min )
        && ( $now <= $min + $options{'timeinterval'} ) )
    {
        $bgcolor = $options{'nowbgcolor'} if defined $options{'nowbgcolor'};
        $fgcolor = $options{'nowfgcolor'} if defined $options{'nowfgcolor'};
    }
    return ( $bgcolor, $fgcolor );
}

# =========================
sub _renderTimeline {
    ###my $td = $cgi->start_table({-rules=>"rows",-border=>'1',-cellpadding=>'0',-cellspacing=>'0'});
    my $td = $cgi->start_table(
        { -bgcolor => "#fafafa", -cellpadding => '0', -cellspacing => '1' } )
      ;    # XXXX time line table
    my $interval = $options{'timeinterval'};
    my ( $starttime, $endtime ) =
      ( &_getTime( $options{'starttime'} ), &_getTime( $options{'endtime'} ) );
    my ( $wst, $wet ) = (
        &_getTime( $options{'workingstarttime'} ),
        &_getTime( $options{'workingendtime'} )
    );
    my ( $bla, $minutes, $hours ) = localtime();
    my ($now) = $minutes + ( 60 * $hours );

    for ( my $min = $starttime ; $min <= $endtime ; $min += $interval ) {
        my ( $bgcolor, $fgcolor ) = _getTimeColors( $min, 1 );
        $td .= $cgi->Tr(
            $cgi->td(
                {
                    -bgcolor => $bgcolor,
                    -align   => "right"
                },
                $cgi->div(
                    {
                        -style => 'color:' . $fgcolor,
                        -title => &_renderTime( $min, '12am' ) . ' / '
                          . &_renderTime( $min, 24 )
                          . (
                            ( defined $options{'timezone'} )
                              && ( $options{'timezone'} ne '0' )
                            ? ' ' . $options{'timezone'}
                            : ''
                          )
                    },
                    &_renderTime($min)
                )
            )
        );
        $td .= "\n";
    }
    $td .= $cgi->end_table();
    return $td;
}

# =========================
sub _normalize {
    my ( $time, $starttime, $interval, $up ) = @_;
    if (   ( !defined $time )
        || ( !defined $starttime )
        || ( !defined $interval ) )
    {
        $time = undef;
    }
    else {
        $time =
          int( ( $time + ( $starttime % $interval ) ) / $interval ) * $interval
          if !$up;
        $time =
          ceil( ( $time + ( $starttime % $interval ) ) / $interval ) * $interval
          if $up;
        ##$time=$starttime if $time<$starttime ; ### XXX BUG: endtime < starttime
    }

    return $time;
}

# =========================
sub _countConflicts {
    my ( $entry_ref, $entries_ref, $starttime, $interval ) = @_;
    my $c = 1;
    my ( $sd1, $ed1 ) = ( $$entry_ref{'nstarttime'}, $$entry_ref{'nendtime'} );
    my (%visitedstartdates);
    foreach my $e ( @{$entries_ref} ) {
        my ( $sd2, $ed2 ) = ( $$e{'nstarttime'}, $$e{'nendtime'} );

        # go to the next if the same entry:
        next if $e == $entry_ref;

        # ignore whole-time  events:
        next if $options{'wholetimerow'} && ( $sd2 == 0 ) && ( $ed2 == 1440 );

        # count only one conflict for events with same start time:
        next if defined $visitedstartdates{$sd2};
        $visitedstartdates{$sd2} = $ed2;

# increase if the other start time is in my time range or my end time is in the time range of the other:
        $c++
          if ( ( $sd2 > $sd1 ) && ( $sd2 < $ed1 ) )
          || ( ( $ed1 > $sd2 ) && ( $ed1 < $ed2 ) );

# decrease if my start time and end time is completly in a time range or the other:
        $c--
          if ( $sd1 >= $sd2 )
          && ( $sd1 < $ed2 )
          && ( $ed1 > $sd2 )
          && ( $ed1 < $ed2 );
    }
    return $c;
}

# =========================
sub _getEntryRows {
    my ( $entry_ref, $time, $mintime, $maxtime, $interval ) = @_;
    my ($rows) = 1;
    my ( $starttime, $endtime ) =
      ( $$entry_ref{'nstarttime'}, $$entry_ref{'nendtime'} );

    $starttime = $time if $starttime < $mintime;
    $endtime = $maxtime + $interval if $endtime > $maxtime;

    $endtime += $interval if ( $starttime == $endtime );

    $rows = sprintf( "%d", ( abs( $endtime - $starttime + 1 ) / $interval ) );

    return $rows >= 1 ? $rows : 1;
}

# =========================
sub _getWholeTimeEntries {
    my ($entries_arrref) = @_;
    my (@matches);
    foreach my $entryref ( @{$entries_arrref} ) {
        my $stime = $$entryref{'starttime'};
        my $etime = $$entryref{'endtime'};
        push( @matches, $entryref ) if ( $stime == 0 ) && ( $etime >= 1439 );
    }
    return \@matches;

}

# =========================
sub _getMatchingEntries {
    my ( $entries_arrref, $time, $interval, $starttime ) = @_;
    my (@matches);
    foreach my $entryref ( @{$entries_arrref} ) {
        my $stime = $$entryref{'nstarttime'};
        my $etime = $$entryref{'nendtime'};

        # ignore whole-time events:
        next
          if $options{'wholetimerow'}
              && ( $$entryref{'starttime'} == 0 )
              && ( $$entryref{'endtime'} == 1440 );

        push( @matches, $entryref )
          if ( ( $stime >= $time ) && ( $stime < $time + $interval ) )
          || ( ( $time == $starttime )
            && ( $stime < $time )
            && ( $etime > $starttime ) );
    }
    ### XXX setup a sort order for conflict entries (default: no sort)XXX
    ### @matches = sort { $$b{'endtime'} <=> $$a{'endtime'} } @matches;
    ### @matches = sort { $$a{'descr'} <=> $$b{'descr'} } @matches;
    return \@matches;
}

# =========================
sub _renderTime {
    return undef unless defined $_[0];
    my $time = "";
    my ( $days, $hours, $minutes );
    if ( $_[0] =~ m/$duration_rx/i ) {
        if ( $_[0] =~ m/d/i ) {
            ( $days, $hours, $minutes ) = split /[\.\:dhmDHM]/, $_[0];
        }
        elsif ( $_[0] =~ m/h/i ) {
            ( $hours, $minutes ) = split /[\.:hm]/i, $_[0];
        }
        elsif ( $_[0] =~ m/m/i ) {
            ($minutes) = split /[\.:m]/i, $_[0];
        }

        $time .= $days . 'd'
          if ( defined $days ) && ( $days ne "" ) && ( int($days) != 0 );
        $time .= $hours . 'h'
          if ( defined $hours ) && ( $hours ne "" ) && ( int($hours) != 0 );
        $time .= $minutes . 'm'
          if ( defined $minutes )
          && ( $minutes ne "" )
          && ( int($minutes) != 0 );

    }
    else {
        ( $hours, $minutes ) = ( int( $_[0] / 60 ), ( $_[0] % 60 ) );
        my ($timeformat) = ( $_[1] ? $_[1] : $options{'timeformat'} );
        if ( $timeformat =~ m/^12/ ) {
            $hours -= 12 if ( $hours > 12 );
            $hours = 12 if ( $hours == 0 );
        }
        $time = sprintf( "%02d", $hours ) . ':' . sprintf( "%02d", $minutes );
        my $rh = int( $_[0] / 60 );
        $time .= ( ( $rh > 11 ) && ( $rh < 24 ) ) ? "p$1m$2" : "a$1m$2"
          if ( $timeformat =~ m/[ap](\.?)m(\.?)$/ );
        $time .= ( ( $rh > 11 ) && ( $rh < 24 ) ) ? "P$1M$2" : "A$1M$2"
          if ( $timeformat =~ m/[AP](\.?)M(\.?)$/ );
    }

    return $time;
}

# =========================
sub _getStartDate() {
    my ( $yy, $mm, $dd ) = Today();

    # handle startdate (absolute or offset)
    if ( defined $options{'startdate'} ) {
        my $sd = $options{'startdate'};
        $sd =~ s/^\s*(.*?)\s*$/$1/;    # cut whitespaces
        if ( $sd =~ /^$date_rx$/ ) {
            my ( $d, $m, $y );
            ( $d, $m, $y ) = split( /\s+/, $sd );
            ( $dd, $mm, $yy ) = ( $d, $months{$m}, $y )
              if check_date( $y, $months{$m}, $d );
        }
        elsif ( $sd =~ /^([\+\-]?\d+)$/ ) {
            ( $yy, $mm, $dd ) = Add_Delta_Days( $yy, $mm, $dd, $1 );
        }
    }

    # handle year (absolute or offset)
    if ( defined $options{'year'} ) {
        my $year = $options{'year'};
        if ( $year =~ /^(\d{4})$/ ) {
            $yy = $year;
        }
        elsif ( $year =~ /^([\+\-]?\d+)$/ ) {
            ( $yy, $mm, $dd ) = Add_Delta_YM( $yy, $mm, $dd, $1, 0 );
        }
    }

    # handle month (absolute or offset)
    if ( defined $options{'month'} ) {
        my $month   = $options{'month'};
        my $matched = 1;
        if ( $month =~ /^($months_rx)$/ ) {
            $mm = $months{$1};
        }
        elsif ( $month =~ /^([\+\-]\d+)$/ ) {
            ( $yy, $mm, $dd ) = Add_Delta_YM( $yy, $mm, $dd, 0, $1 );
        }
        elsif ( ( $month =~ /^\d?\d$/ ) && ( $month > 0 ) && ( $month < 13 ) ) {
            $mm = $month;
        }
        else {
            $matched = 0;
        }
        if ($matched) {
            $dd = 1;
            $options{days} = Days_in_Month( $yy, $mm );
        }
    }

    if ( ( !$options{'compatmode'} ) || ( !$options{'forcestartdate'} ) ) {
        my $dow = Day_of_Week( $yy, $mm, $dd );
        ( $yy, $mm, $dd ) = Add_Delta_Days( $yy, $mm, $dd, 1 - $dow );
    }
    if ( $options{'compatmode'} ) {
        my $qpttppage = &_parseInt( $cgi->param( 'ttppage' . $ttid ) );
        ( $yy, $mm, $dd ) =
          Add_Delta_Days( $yy, $mm, $dd, $qpttppage * $options{'days'} )
          if defined $qpttppage;
    }

    return ( $dd, $mm, $yy );
}

# =========================
sub _mystrftime {
    my ( $yy, $mm, $dd, $format ) = @_;
    my $text =
      $format ? $format
      : (
          $options{'compatmode'} ? $options{'cmheaderformat'}
        : $options{'headerformat'}
      );

    my $dow = Day_of_Week( $yy, $mm, $dd );
    my $t_dow = undef;
    if ( defined $options{daynames} ) {
        my @dn = split /\|/, $options{daynames};
        $t_dow = $dn[ $dow - 1 ] if $#dn == 6;
    }
    $t_dow = Day_of_Week_to_Text($dow) unless defined $t_dow;

    my $t_mm = undef;
    if ( defined $options{monthnames} ) {
        my @mn = split /\|/, $options{monthnames};
        $t_mm = $mn[ $mm - 1 ] if $#mn == 11;
    }
    $t_mm = Month_to_Text($mm) unless defined $t_mm;

    my $doy = Day_of_Year( $yy, $mm, $dd );
    my $wn = Week_Number( $yy, $mm, $dd );
    my $t_wn = $wn < 10 ? "0$wn" : $wn;

    my $y = substr( "$yy", -2, 2 );

    my %tmap = (
        '%a' => substr( $t_dow,         0,   2 ),
        '%A' => $t_dow,
        '%b' => substr( $t_mm,          0,   3 ),
        '%B' => $t_mm,
        '%c' => Date_to_Text_Long( $yy, $mm, $dd ),
        '%C' => This_Year(),
        '%d' => $dd < 10 ? "0$dd" : $dd,
        '%D' => "$mm/$dd/$yy",
        '%e' => $dd,
        '%F' => "$yy-$mm-$dd",
        '%g' => $y,
        '%G' => $yy,
        '%h' => substr( $t_mm, 0, 3 ),
        '%j' => ( $doy < 100 ) ? ( ( $doy < 10 ) ? "00$doy" : "0$doy" ) : $doy,
        '%m' => ( $mm < 10 ) ? "0$mm" : $mm,
        '%n' => '<br/>',
        '%t' => "<code>\t</code>",
        '%u' => $dow,
        '%U' => $t_wn,
        '%V' => $t_wn,
        '%w' => $dow - 1,
        '%W' => $t_wn,
        '%x' => Date_to_Text( $yy, $mm, $dd ),
        '%y' => $y,
        '%Y' => $yy,
        '%%' => '%'
    );

    # replace all known conversion specifiers:
    $text =~ s/(%[a-z\%\+]?)/(defined $tmap{$1})?$tmap{$1}:$1/ieg;

    return $text;
}

# =========================
sub _handleTopicSetup {
    my ( $attributes, $web, $topic, $timezone ) = @_;
    my %params = &Foswiki::Func::extractParameters($attributes);

    $topicDefaults{"$web.$topic"} = \%params;
    ${ $topicDefaults{"$web.$topic"} }{'timezone'} = $timezone
      if defined $timezone;

    return "";
}

# =========================
sub _processTopicSetup {
    ### my ($text, $web, $topic) = @_;
    my $web      = $_[1];
    my $topic    = $_[2];
    my $timezone = $_[3];

    $topicDefaults{"$web.$topic"} = { 'timezone' => $timezone }
      if ( defined $timezone );

    if (
        (
            $_[0] =~
s /%TTTOPICSETUP{(.*?)}%/&_handleTopicSetup($1, $web, $topic, $timezone)/esg
        )
        || ( defined $timezone )
      )
    {
        $_[0] =~ s/^(\s+\*.+)$/$1 \%TTSETUP{"$web.$topic"}\%/mg;
    }

    return $_[0];
}

### dro: following code is derived from Foswiki:Extensions.CalendarPlugin:
# =========================
sub _getTopicText() {

    my ( $web, $topic, $timezone );

    my $topics = $options{topic};
    my @topics = split /,\s*/, $topics;

    my $text = "";
    foreach my $topicpair (@topics) {

        ( $web, $topic ) = split /\./, $topicpair, 2;
        if ( !defined $topic ) {
            $topic = $web;
            $web   = $theWeb;
        }
        if ( $topic =~ s/:(.*)$// ) {
            $timezone = $1;
        }

        # ignore processed topics;
        grep( /^\Q$web.$topic\E$/, @processedTopics ) && next;

        push( @processedTopics, "$web.$topic" );

        if ( ( $topic eq $theTopic ) && ( $web eq $theWeb ) ) {

            # use current text so that preview can show unsaved events
            $text .= &_processTopicSetup( $refText, $web, $topic, $timezone );
        }
        else {
            my $nt = &_readTopicText( $web, $topic );
            $text .= &_processTopicSetup( $nt, $web, $topic, $timezone );
        }
    }

    $text =~
      s/%INCLUDE{(.*?)}%/&_expandIncludedEvents($1, \@processedTopics)/geo;

    return $text;

}

# =========================
sub _readTopicText {
    my ( $theWeb, $theTopic ) = @_;
    my $text = '';
    if ( $Foswiki::Plugins::VERSION >= 1.010 ) {
        $text = &Foswiki::Func::readTopicText( $theWeb, $theTopic, '', 1 );
    }
    else {
        $text = &Foswiki::Func::readTopic( $theWeb, $theTopic );
    }

    # return raw topic text, including meta data
    return $text;
}

# =========================
sub _expandIncludedEvents {
    my ( $theAttributes, $theProcessedTopicsRef ) = @_;

    my ( $theWeb, $theTopic ) = ( $web, $topic );

    my $webTopic = &Foswiki::Func::extractNameValuePair($theAttributes);
    if ( $webTopic =~ /^([^\.]+)[\.\/](.*)$/ ) {
        $theWeb   = $1;
        $theTopic = $2;
    }
    else {
        $theTopic = $webTopic;
    }

    # prevent recursive loop
    grep ( /^\Q$theWeb.$theTopic\E$/, @{$theProcessedTopicsRef} ) and return "";

    push( @{$theProcessedTopicsRef}, "$theWeb.$theTopic" );

    my $text = &_readTopicText( $theWeb, $theTopic );

    $text =~ s/.*?%STARTINCLUDE%//s;
    $text =~ s/%STOPINCLUDE%.*//s;

    # recursively expand includes
    $text =~
s/%INCLUDE{(.*?)}%/&_expandIncludedEvents( $1, $theProcessedTopicsRef )/geo;

    ## $text = Foswiki::Func::expandCommonVariables($text, $theTopic, $theWeb);

    return $text;
}

# =========================
sub _createUnknownParamsMessage {
    my $msg;
    $msg =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_UNKNOWNPARAMSMSG")
      || undef;
    $msg = $defaults{unknownparamsmsg} unless defined $msg;
    $msg =~ s/\%UNKNOWNPARAMSLIST\%/join(', ', sort @unknownParams)/eg;
    $msg =~ s/\%KNOWNPARAMSLIST\%/join(', ', sort keys %defaults)/eg;
    return $msg;
}

# =========================
sub _fetchCompat {
    my ( $line, $entries_ref, $excref, $setup ) = @_;

    my ( $dd, $mm, $yy ) = &_getStartDate();
    my ( $eyy, $emm, $edd ) = Add_Delta_Days( $yy, $mm, $dd, $options{'days'} );

    my $startDays = Date_to_Days( $yy,  $mm,  $dd );
    my $endDays   = Date_to_Days( $eyy, $emm, $edd );

    my $STARTTIME    = &_getTime( $options{'starttime'} );
    my $TIMEINTERVAL = $options{'timeinterval'};

    my ( $descr, $tt );
    my (
        $starttime, $endtime, $nstarttime, $nendtime,
        $fgcolor,   $bgcolor, $duration
    );
    my ($strdate);

    $starttime = undef, $endtime = undef;
    $fgcolor   = undef;
    $bgcolor   = undef;

    if ( $line =~ s/%TTCM{(.*?)}%// ) {
        ( $starttime, $endtime, $duration, $fgcolor, $bgcolor ) =
          _getTTCMValues($1);
    }
    elsif ( $line =~ s/($timerangestrict_rx(,\S+)*)// ) {
        ( $starttime, $endtime, $duration, $fgcolor, $bgcolor ) =
          _getTTCMValues($1);
    }
    if ( defined $setup ) {
        my $topicSetupRef = $topicDefaults{$setup};
        if ( defined $topicSetupRef ) {
            $starttime = $$topicSetupRef{'defaultstarttime'}
              if defined $$topicSetupRef{'defaultstarttime'};
            $endtime = $$topicSetupRef{'defaultendtime'}
              if defined $$topicSetupRef{'defaultendtime'};
            $fgcolor = $$topicSetupRef{'eventfgcolor'}
              if defined $$topicSetupRef{'eventfgcolor'};
            $bgcolor = $$topicSetupRef{'eventbgcolor'}
              if defined $$topicSetupRef{'eventbgcolor'};
        }
    }
    $starttime = 0 unless defined $starttime;
    $endtime = 1440 unless defined $endtime || defined $duration;

    ( $nstarttime, $nendtime ) = (
        &_normalize( $starttime, $STARTTIME, $TIMEINTERVAL ),
        &_normalize( $endtime, $STARTTIME, $TIMEINTERVAL, 1 )
    );

    if (   ( $line =~ m/^$daterange_rx/ )
        || ( $line =~ m/^$date_rx/ )
        || ( $line =~ m/^$monthyearrange_rx/ )
        || ( $line =~ m/^$monthyear_rx/ ) )
    {
        ### dd MMM yyyy - dd MMM yyyy
        ### dd MMM yyyy
        ### MMM yyyy
        ### MMM yyyy - MMM yyyy
        my ( $sdate, $edate );
        if (   ( $line =~ m/^$daterange_rx/ )
            || ( $line =~ m/^$monthyearrange_rx/ ) )
        {
            ( $sdate, $edate, $descr ) = split /\s+\-\s+/, $line;
        }
        else {
            ( $sdate, $descr ) = split /\s+\-\s+/, $line;
            $edate = $sdate;
        }

        my ( $start, $end ) = ( &_getDays($sdate), &_getDays( $edate, 1 ) );

        $descr =~ s/^\s*//;
        $descr =~ s/\s*$//;    # strip whitespaces

        my $date = $startDays;
        for (
            my $day = 0 ;
            ( $day < $options{'days'} ) && ( ( $date + $day ) <= $end ) ;
            $day++
          )
        {
            next if $$excref[$day];
            if ( ( $date + $day ) >= $start ) {
                push @{ $$entries_ref{ $day + 1 } },
                  {
                    'descr'      => $descr,
                    'longdescr'  => $line,
                    'starttime'  => $starttime,
                    'endtime'    => $endtime,
                    'nstarttime' => $nstarttime,
                    'nendtime'   => $nendtime,
                    'fgcolor'    => $fgcolor,
                    'bgcolor'    => $bgcolor,
                    'setup'      => $setup,
                    'duration'   => $duration
                  };
                &_fixEntryTime(
                    $entries_ref,
                    $$entries_ref{ $day + 1 }
                      [ $#{ $$entries_ref{ $day + 1 } } ],
                    $day
                );
            }
        }
    }
    elsif ( $line =~ m/^A\s+$date_rx/ ) {
        ### Yearly: A dd MMM yyyy

        ( $strdate, $descr ) = split /\s+\-\s+/, $line;
        $strdate =~ s/^A\s+//;

        my ( $dd1, $mm1, $yy1 ) = split /\s+/, $strdate;
        $mm1 = $months{$mm1};
        return unless check_date( $yy1, $mm1, $dd1 );

        for ( my $day = 0 ; $day < $options{'days'} ; $day++ ) {
            next if $$excref[$day];
            my ( $y, $m, $d ) = Add_Delta_Days( $yy, $mm, $dd, $day );
            if ( ( $m == $mm1 ) && ( $d == $dd1 ) ) {
                push @{ $$entries_ref{ $day + 1 } },
                  {
                    'descr'      => $descr,
                    'longdescr'  => $line,
                    'starttime'  => $starttime,
                    'endtime'    => $endtime,
                    'nstarttime' => $nstarttime,
                    'nendtime'   => $nendtime,
                    'fgcolor'    => $fgcolor,
                    'bgcolor'    => $bgcolor,
                    'setup'      => $setup,
                    'duration'   => $duration
                  };
                &_fixEntryTime(
                    $entries_ref,
                    $$entries_ref{ $day + 1 }
                      [ $#{ $$entries_ref{ $day + 1 } } ],
                    $day
                );
            }

        }

    }
    elsif ( $line =~ m/^$day_rx\s+($months_rx)\s+\-/ ) {
        ### Interval: dd MMM
        ( $strdate, $descr ) = split /\s+\-\s+/, $line;
        my ( $dd1, $mm1 ) = split /\s+/, $strdate;
        $mm1 = $months{$mm1};
        return if $dd1 > 31;

        for ( my $day = 0 ; $day < $options{'days'} ; $day++ ) {
            next if $$excref[$day];
            my ( $y, $m, $d ) = Add_Delta_Days( $yy, $mm, $dd, $day );
            if ( ( $mm1 == $m ) && ( $dd1 == $d ) ) {
                push @{ $$entries_ref{ $day + 1 } },
                  {
                    'descr'      => $descr,
                    'longdescr'  => $line,
                    'starttime'  => $starttime,
                    'endtime'    => $endtime,
                    'nstarttime' => $nstarttime,
                    'nendtime'   => $nendtime,
                    'fgcolor'    => $fgcolor,
                    'bgcolor'    => $bgcolor,
                    'setup'      => $setup,
                    'duration'   => $duration
                  };
                &_fixEntryTime(
                    $entries_ref,
                    $$entries_ref{ $day + 1 }
                      [ $#{ $$entries_ref{ $day + 1 } } ],
                    $day
                );
            }
        }
    }
    elsif ( $line =~ m/^[0-9L](\.|th)?\s+($dow_rx)(\s+($months_rx))?/ ) {
        ### Interval: w DDD MMM
        ### Interval: L DDD MMM
        ### Monthly: w DDD
        ### Monthly: L DDD

        ( $strdate, $descr ) = split /\s+\-\s+/, $line;

        my ( $n1, $dow1, $mm1 ) = split /\s+/, $strdate;
        $dow1 = $daysofweek{$dow1};
        $mm1 = $months{$mm1} if defined $mm1;

        for ( my $day = 0 ; $day < $options{'days'} ; $day++ ) {
            next if $$excref[$day];
            my ( $y, $m, $d ) = Add_Delta_Days( $yy, $mm, $dd, $day );
            if ( ( !defined $mm1 ) || ( $m == $mm1 ) ) {
                my ( $yy2, $mm2, $dd2 );
                if ( $n1 eq 'L' ) {
                    $n1 = 6;
                    do {
                        $n1--;
                        ( $yy2, $mm2, $dd2 ) =
                          Nth_Weekday_of_Month_Year( $y, $m, $dow1, $n1 );
                    } until ($yy2);
                }
                else {
                    eval {    # may fail with a illegal factor
                        ( $yy2, $mm2, $dd2 ) =
                          Nth_Weekday_of_Month_Year( $y, $m, $dow1, $n1 );
                    };
                    next if $@;
                }

                if ( ($dd2) && ( $dd2 == $d ) ) {
                    push @{ $$entries_ref{ $day + 1 } },
                      {
                        'descr'      => $descr,
                        'longdescr'  => $line,
                        'starttime'  => $starttime,
                        'endtime'    => $endtime,
                        'nstarttime' => $nstarttime,
                        'nendtime'   => $nendtime,
                        'fgcolor'    => $fgcolor,
                        'bgcolor'    => $bgcolor,
                        'setup'      => $setup,
                        'duration'   => $duration
                      };
                    &_fixEntryTime(
                        $entries_ref,
                        $$entries_ref{ $day + 1 }
                          [ $#{ $$entries_ref{ $day + 1 } } ],
                        $day
                    );
                }    # if
            }    # if
        }    # for
    }
    elsif ( $line =~ m/^$day_rx\s+\-/ ) {
        ### Monthly: dd
        ( $strdate, $descr ) = split /\s+\-\s+/, $line;
        return if $strdate > 31;
        for ( my $day = 0 ; $day < $options{'days'} ; $day++ ) {
            next if $$excref[$day];
            my ( $y, $m, $d ) = Add_Delta_Days( $yy, $mm, $dd, $day );
            if ( $strdate == $d ) {
                push @{ $$entries_ref{ $day + 1 } },
                  {
                    'descr'      => $descr,
                    'longdescr'  => $line,
                    'starttime'  => $starttime,
                    'endtime'    => $endtime,
                    'nstarttime' => $nstarttime,
                    'nendtime'   => $nendtime,
                    'fgcolor'    => $fgcolor,
                    'bgcolor'    => $bgcolor,
                    'setup'      => $setup,
                    'duration'   => $duration
                  };
                &_fixEntryTime(
                    $entries_ref,
                    $$entries_ref{ $day + 1 }
                      [ $#{ $$entries_ref{ $day + 1 } } ],
                    $day
                );
            }    # if
        }    # for
    }
    elsif ( $line =~ m/^E\s+($dow_rx)/ ) {
        ### Monthly: E DDD dd MMM yyy - dd MMM yyyy
        ### Monthly: E DDD dd MMM yyy
        ### Monthly: E DDD
        my $strdate2 = undef;
        if ( $line =~ m/^E\s+($dow_rx)\s+$daterange_rx/ ) {
            ( $strdate, $strdate2, $descr ) = split /\s+\-\s+/, $line;
        }
        else {
            ( $strdate, $descr ) = split /\s+\-\s+/, $line;
        }
        $strdate =~ s/^E\s+//;
        my ($dow1) = split /\s+/, $strdate;
        $dow1 = $daysofweek{$dow1};

        $strdate =~ s/^\S+\s*//;

        my ( $start, $end ) = ( undef, undef );
        if ( ( defined $strdate ) && ( $strdate ne "" ) ) {
            $start = &_getDays($strdate);
            return unless defined $start;
        }

        if ( defined $strdate2 ) {
            $end = &_getDays($strdate2);
            return unless defined $end;
        }

        return if ( defined $start ) && ( $start > $endDays );
        return if ( defined $end )   && ( $end < $startDays );

        for ( my $day = 0 ; $day < $options{'days'} ; $day++ ) {
            next if $$excref[$day];
            my ( $y, $m, $d ) = Add_Delta_Days( $yy, $mm, $dd, $day );
            my $date = Date_to_Days( $y, $m, $d );
            my $dow = Day_of_Week( $y, $m, $d );
            if (   ( $dow == $dow1 )
                && ( ( !defined $start ) || ( $date >= $start ) )
                && ( ( !defined $end )   || ( $date <= $end ) ) )
            {
                push @{ $$entries_ref{ $day + 1 } },
                  {
                    'descr'      => $descr,
                    'longdescr'  => $line,
                    'starttime'  => $starttime,
                    'endtime'    => $endtime,
                    'nstarttime' => $nstarttime,
                    'nendtime'   => $nendtime,
                    'fgcolor'    => $fgcolor,
                    'bgcolor'    => $bgcolor,
                    'setup'      => $setup,
                    'duration'   => $duration
                  };
                &_fixEntryTime(
                    $entries_ref,
                    $$entries_ref{ $day + 1 }
                      [ $#{ $$entries_ref{ $day + 1 } } ],
                    $day
                );
            }

        }
    }
    elsif ( $line =~ m/^E\d+\s+$date_rx/ ) {
        ### Periodic: En dd MMM yyyy - dd MMM yyyy
        ### Periodic: En dd MMM yyyy
        my $strdate2 = undef;
        if ( $line =~ m/^E\d+\s+$daterange_rx/ ) {
            ( $strdate, $strdate2, $descr ) = split /\s+\-\s+/, $line;
        }
        else {
            ( $strdate, $descr ) = split /\s+\-\s+/, $line, 4;
        }

        $strdate =~ s/^E//;
        my ($n1) = split /\s+/, $strdate;

        return unless $n1 > 0;

        $strdate =~ s/^\d+\s+//;

        my ( $start, $end ) = ( undef, undef );
        my ( $dd1, $mm1, $yy1 ) = split /\s+/, $strdate;
        $mm1 = $months{$mm1};

        $start = &_getDays($strdate);
        return unless defined $start;

        $end = &_getDays($strdate2) if defined $strdate2;
        return if ( defined $strdate2 ) && ( !defined $end );

        return if ( defined $start ) && ( $start > $endDays );
        return if ( defined $end )   && ( $end < $startDays );

        if ( $start < $startDays ) {
            ( $yy1, $mm1, $dd1 ) = Add_Delta_Days(
                $yy1, $mm1, $dd1,
                $n1 * int(
                    ( abs( $startDays - $start ) / $n1 ) +
                      ( ( abs( $startDays - $start ) % $n1 ) != 0 ? 1 : 0 )
                )
            );
            $start = Date_to_Days( $yy1, $mm1, $dd1 );
        }

        # start at first occurence and increment by repeating count ($n1)
        for (
            my $day = ( abs( $startDays - $start ) % $n1 ) ;
            (
                     ( $day < $options{'days'} )
                  && ( ( !defined $end ) || ( ( $startDays + $day ) <= $end ) )
              ) ;
            $day += $n1
          )
        {
            next if $$excref[$day];
            if ( ( $startDays + $day ) >= $start ) {
                push @{ $$entries_ref{ $day + 1 } },
                  {
                    'descr'      => $descr,
                    'longdescr'  => $line,
                    'starttime'  => $starttime,
                    'endtime'    => $endtime,
                    'nstarttime' => $nstarttime,
                    'nendtime'   => $nendtime,
                    'fgcolor'    => $fgcolor,
                    'bgcolor'    => $bgcolor,
                    'setup'      => $setup,
                    'duration'   => $duration
                  };
                &_fixEntryTime(
                    $entries_ref,
                    $$entries_ref{ $day + 1 }
                      [ $#{ $$entries_ref{ $day + 1 } } ],
                    $day
                );

            }
        }    # for

    }    # elsif
}    # sub

# =========================
sub _getDays {
    my ( $date, $ldom ) = @_;
    my $days = undef;

    $date =~ s/^\s*//;
    $date =~ s/\s*$//;

    my ( $yy, $mm, $dd );
    if ( $date =~ /^$date_rx$/ ) {
        ( $dd, $mm, $yy ) = split /\s+/, $date;
        $mm = $months{$mm};
    }
    elsif ( $date =~ /^$monthyear_rx$/ ) {
        ( $mm, $yy ) = split /\s+/, $date;
        $mm = $months{$mm};
        $dd = $ldom ? Days_in_Month( $yy, $mm ) : 1;
    }
    else {
        return undef;
    }
    $dd =~ /(\d+)/;
    $dd = $1;
    $days = check_date( $yy, $mm, $dd ) ? Date_to_Days( $yy, $mm, $dd ) : undef;

    return $days;

}

# =========================
sub _fetchExceptions {
    my ( $line, $startDays, $endDays ) = @_;

    my @exceptions = ();

    $_[0] =~ s /X\s*{\s*([^}]+)\s*}// || return \@exceptions;
    my $ex = $1;

    for my $x ( split /\s*\,\s*/, $ex ) {
        my ( $start, $end ) = ( undef, undef );
        if ( ( $x =~ m/^$daterange_rx$/ ) || ( $x =~ m/^$monthyearrange_rx/ ) )
        {
            my ( $sdate, $edate ) = split /\s*\-\s*/, $x;
            $start = &_getDays( $sdate, 0 );
            $end   = &_getDays( $edate, 1 );

        }
        elsif ( ( $x =~ m/^$date_rx/ ) || ( $x =~ m/^$monthyear_rx/ ) ) {
            $start = &_getDays( $x, 0 );
            $end   = &_getDays( $x, 1 );
        }
        next unless defined $start && ( $start <= $endDays );
        next unless defined $end   && ( $end >= $startDays );

        for (
            my $i = 0 ;
            ( $i < $options{'days'} ) && ( ( $startDays + $i ) <= $end ) ;
            $i++
          )
        {
            $exceptions[$i] = 1
              if ( ( ( $startDays + $i ) >= $start )
                && ( ( $startDays + $i ) <= $end ) );
        }
    }

    return \@exceptions;
}

# =========================
sub _fixTZDate {
    my ( $day, $time, $timezone ) = @_;
    my ( $dd,  $mm,   $yy )       = &_getStartDate();

    ( $yy, $mm, $dd ) = Add_Delta_Days( $yy, $mm, $dd, $day );

    my $otz =
      ( defined $TIMEZONES{ $options{'timezone'} } )
      ? $TIMEZONES{ $options{'timezone'} }
      : $options{'timezone'};

    my $deltatime = 60 * ( $timezone - $otz );    # minutes

    my $fixDays = 0;
    while ( $time >= 1440 ) {
        $time -= 1440;
        ( $yy, $mm, $dd ) = Add_Delta_Days( $yy, $mm, $dd, 1 );
        $fixDays++;
    }
    my ( $HH, $MM, $SS ) = ( int( $time / 60 ), ( $time % 60 ), 0 );

    my ( $yy1, $mm1, $dd1, $HH1, $MM1, $SS1 ) =
      Add_Delta_YMDHMS( $yy, $mm, $dd, $HH, $MM, $SS, 0, 0, 0, 0, $deltatime,
        0 );

    return ( $day + Delta_Days( $yy, $mm, $dd, $yy1, $mm1, $dd1 ) + $fixDays,
        ( $HH1 * 60 ) + $MM1 );

}

# =========================
sub _calcDuration {
    my ( $day, $starttime, $duration ) = @_;

    my ( $dd, $mm, $yy ) = &_getStartDate();
    ( $yy, $mm, $dd ) = Add_Delta_Days( $yy, $mm, $dd, $day );

    if ( $duration =~ m/d/i ) {
        my ( $ddays, $dhours, $dminutes ) = split /[\.:dhm]/i, $duration;
        $duration = ( $ddays * 1440 );
        $duration += $dhours * 60 if defined $dhours and ( $dhours ne "" );
        $duration += $dminutes if defined $dminutes and ( $dminutes ne "" );
    }
    elsif ( $duration =~ m/h/i ) {
        my ( $dhours, $dminutes ) = split /[\.:hm]/i, $duration;
        $duration = $dhours * 60;
        $duration += $dminutes if defined $dminutes and ( $dminutes ne "" );
    }
    elsif ( $duration =~ m/m/i ) {
        $duration =~ s/m$//i;
        ($duration) = split /[\.:]/i, $duration;
    }

    my ( $HH, $MM, $SS ) = ( int( $starttime / 60 ), ( $starttime % 60 ), 0 );
    my ( $yy1, $mm1, $dd1, $HH1, $MM1, $SS1 ) =
      Add_Delta_YMDHMS( $yy, $mm, $dd, $HH, $MM, $SS, 0, 0, 0, 0, $duration,
        0 );

    return ( $day + Delta_Days( $yy, $mm, $dd, $yy1, $mm1, $dd1 ),
        ( $HH1 * 60 ) + $MM1 );

}

# =========================
sub _duplicateDaysSpanningEntry {
    my ( $entry_ref, $entries_ref, $startday ) = @_;
    my ( $starttime, $endtime,     $duration ) = (
        $$entry_ref{'nstarttime'},
        $$entry_ref{'nendtime'}, $$entry_ref{'duration'}
    );

    my $STARTTIME    = &_getTime( $options{'starttime'} );
    my $TIMEINTERVAL = $options{'timeinterval'};
    my ($endday);

    if ( defined $duration ) {
        ( $endday, $endtime ) =
          &_calcDuration( $startday, $starttime, $duration );
    }
    else {
        return if ( $starttime <= $endtime );
        $endday = $startday + 1;
    }

    ## fix nendtime
    $$entry_ref{'nendtime'} =
      &_normalize( $endtime, $STARTTIME, $TIMEINTERVAL, 1 );

    return if ( $startday == $endday );    # nothing to duplicate

    my $wrapped = 0;
    for (
        my $d = $startday ;
        ( $d <= $endday )
          && ( ( $d < $options{'days'} ) || ( !$options{'compatmode'} ) ) ;
        $d++
      )
    {
        if ( $d == $options{'days'} )
        {    ## wrap arround if compatmode==0 (event goes above days limit)
            $endday -= 7;
            $d       = 0;
            $wrapped = 1;
        }
        if ( ( $d == $startday ) && ( !$wrapped ) ) {
            $$entry_ref{'nendtime'} =
              &_normalize( 1440, $STARTTIME, $TIMEINTERVAL, 1 );
        }
        else {
            my %newentry = ();

            foreach my $key ( keys %{$entry_ref} ) {
                $newentry{$key} = $$entry_ref{$key};
            }

            $newentry{'nstarttime'} =
              &_normalize( 0, $STARTTIME, $TIMEINTERVAL );
            $newentry{'nendtime'} =
              &_normalize( ( $d < $endday ? 1440 : $endtime ),
                $STARTTIME, $TIMEINTERVAL, 1 );
            $newentry{'fixed'} = 1;
            push @{ $$entries_ref{ $d + 1 } }, \%newentry;
        }

    }

}

# =========================
sub _fixEntryTime {
    my ( $entries_ref, $entry_ref, $day ) = @_;

    my $STARTTIME    = &_getTime( $options{'starttime'} );
    my $TIMEINTERVAL = $options{'timeinterval'};
    my $setup        = $$entry_ref{'setup'};
    my ( $starttime, $endtime, $duration ) = (
        $$entry_ref{'nstarttime'},
        $$entry_ref{'nendtime'}, $$entry_ref{'duration'}
    );

    my ( $topicSetupRef, $timezone );

    $topicSetupRef = $topicDefaults{$setup}      if defined $setup;
    $timezone      = $$topicSetupRef{'timezone'} if defined $topicSetupRef;
    $timezone = 0 unless defined $timezone;
    $timezone = $TIMEZONES{$timezone}
      if ( defined $timezone ) && ( defined $TIMEZONES{$timezone} );

    my $otz =
      ( defined $TIMEZONES{ $options{'timezone'} } )
      ? $TIMEZONES{ $options{'timezone'} }
      : $options{'timezone'};

    if ( ( ( $timezone - $otz ) != 0 ) && ( abs($timezone) <= 12 ) ) {
        my ( $nsday, $nstime ) = &_fixTZDate( $day, $starttime, $timezone );
        my ( $neday, $netime ) =
          ( defined $duration )
          ? &_calcDuration( $nsday, $nstime, $duration )
          : &_fixTZDate( ( $starttime < $endtime ) ? $day : $day + 1,
            $endtime, $timezone );

        $neday = $nsday if ( $neday == $nsday + 1 ) && ( $netime == 0 );

        $$entry_ref{'nstarttime'} =
          &_normalize( $nstime, $STARTTIME, $TIMEINTERVAL );
        $$entry_ref{'nendtime'} =
          &_normalize( $netime, $STARTTIME, $TIMEINTERVAL, 1 );
        $$entry_ref{'fixed'} = 1;

        ## fix full-time events:
        if (   ( $$entry_ref{'starttime'} == 0 )
            && ( $$entry_ref{'endtime'} >= 1439 ) )
        {
            $$entry_ref{'starttime'} = $$entry_ref{'nstarttime'};
            $$entry_ref{'endtime'}   = undef;
            $$entry_ref{'duration'}  = '24h';
        }

        if ( $nsday != $day ) {    ## move entry
            pop @{ $$entries_ref{ $day + 1 } };
            push @{ $$entries_ref{ $nsday + 1 } }, $entry_ref
              if ( $nsday >= 0 ) && ( $nsday < $options{'days'} );
        }

        $day = $nsday;

    }

    &_duplicateDaysSpanningEntry( $entry_ref, $entries_ref, $day );

}

1;
