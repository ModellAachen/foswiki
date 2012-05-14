# See bottom of file for license and copyright information
package Foswiki::Plugins::HolidaylistPlugin::Core;

use strict;
use warnings;

use Date::Calc qw(:all);
use CGI;

# Try to keep the following compatible with CalendarPlugin to make
# code sharing easier
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
my $years_rx  = '[12][0-9][0-9][0-9]';
my $months_rx = join( '|', keys %months );
my $wdays_rx  = join( '|', keys %wdays );
my $days_rx   = "[0-3]?[0-9](\.|th)?";
my $date_rx   = "$days_rx\\s+($months_rx)\\s+$years_rx";

my $full_date_rx        = "$date_rx\\s+($years_rx)";
my $monthly_rx          = "([1-6L])\\s+($wdays_rx)";
my $anniversary_date_rx = "A\\s+$date_rx\\s+($years_rx)";
my $weekly_rx           = "E\\s+($wdays_rx)";
my $periodic_rx         = "E([0-9]+)\\s+$full_date_rx";
my $numdaymon_rx        = "([0-9L])\\s+($wdays_rx)\\s+($months_rx)";

my $monthyear_rx       = "($months_rx)\\s+$years_rx";
my $monthyearrange_rx  = "$monthyear_rx\\s+\\-\\s+$monthyear_rx";
my $daterange_rx       = "$date_rx\\s*-\\s*$date_rx";
my $bullet_rx          = "^\\s+\\*\\s*";
my $bulletdate_rx      = "$bullet_rx$date_rx\\s*-";
my $bulletdaterange_rx = "$bulletdate_rx\\s*$date_rx\\s*-";

# These are localized in the HOLIDAYLIST function to maintain separation.
# Using an object would be more elegant.
our %options;
our @unknownParams;
our %table;
our %locationtable;
our %icontable;

our %defaults = (
    tableheadercolor => 'transparent',    # table header color
    weekendbgcolor   => '#eee',           # background color of weekend cells
    days             => 30,               # days to show
    lang             => 'English',        # language
    tablecaption     => '&nbsp;',         # table caption
    cellpadding      => 0,                # table cellpadding
    cellspacing      => 0,                # table cellspacing
    border           => 0,                # table border
    tablebgcolor     => 'transparent',    # table background color
    workicon         => '&nbsp;',         # on work icon (old behavior: ':mad:')
    holidayicon      => '8-)',            # on holiday icon
    adayofficon      => ':ok:',           # a day off icon
    showweekends =>
      0, # show weekends with month day and weekday in header and icons in cells
    name          => 'Name',    # first cell entry
    startdate     => undef,     # start date or a day offset
    notatworkicon => ':-I',     # not at work icon
    todaybgcolor =>
      undef
    ,    # background color for today cells (usefull for a defined startdate)
    todayfgcolor =>
      undef
    ,    # foreground color for today cells (usefull for a dark todaybgcolor)
    month   => undef,    # the month or a offset
    year    => undef,    # the year or a offset
    tcwidth => undef,    # width of the smily cells
    nwidth  => undef,    # width of the first column
    removeatwork =>
      0,    # removes names without calendar entries from table if set to "1"
    tablecaptionalign =>
      'top',    # table caption alignment (top|bottom|left|right)
    headerformat => '%a<br/>%e',    # format of the header
    compatmode =>
      0,    # compatibility mode (allows all CalendarPlugin event types)
    compatmodeicon => ':-)',    # compatibility mode icon
    daynames       => undef,    # day names (overrides lang attribute)
    monthnames     => undef,    # month names (overrides lang attribute)
    width          => undef,    # table width
    unknownparamsmsg =>
'%RED% Sorry, some parameters are unknown: %UNKNOWNPARAMSLIST% %ENDCOLOR% <br/> Allowed parameters are (see %SYSTEMWEB%.HolidaylistPlugin topic for more details): %KNOWNPARAMSLIST%',
    enablepubholidays => 1,        # enable public holidays
    showpubholidays   => 0,        # show public holidays in a separate row
    pubholidayicon    => ':-)',    # public holiday icon
    navnext => '%JQICON{"arrow_right"}%', # navigation button to the next n days
    navnexthalf  => '',                 # navigation button to the next n/2 days
    navnexttitle => 'Next %n day(s)',
    navnexthalftitle => 'Next %n day(s)',
    navprev => '%JQICON{"arrow_left"}%',  # navigation button to the last n days
    navprevhalf => '',    # navigation button to the last n/2 days
    navprevtitle       => 'Previous %n day(s)',
    navprevhalftitle   => 'Previous %n day(s)',
    navhome            => '',
    navhometitle       => 'Go to the start date',
    navenable          => 1,
    navdays            => undef,
    week               => undef,
    showmonthheader    => 1,
    monthheaderformat  => '%b',
    showstatcol        => 0,
    statcolheader      => '#',
    statcolformat      => '%{hh}',
    statcoltitle       => '%{ll}',
    showstatrow        => 0,
    statrowformat      => '%{hh}',
    statrowheader      => '#',
    statrowtitle       => '%{ll}',
    statformat_ll      => '%{ll:%LOCATION} x %LOCATION; ',
    statformat_l       => '%{l:%LOCATION} x %LOCATION; ',
    statformat_ii      => '%{ii:%ICON} x %ICON ; ',
    statformat_i       => '%{i:%ICON} x %ICON ; ',
    statformat_0       => 0,
    statformat         => undef,
    stattitle          => undef,
    statheader         => undef,
    showstatsum        => 1,
    statformat_perc    => '%3.1f%%',
    statformat_unknown => 'unknown',
    optionsformat =>
'<table class="hlpNavJump"><tr><th>%MAKETEXT{"Month"}%:</th><td>%MONTHSEL</td><th>%MAKETEXT{"Year"}%:</th><td>%YEARSEL</td><td>%BUTTON(Jump)</td></tr></table>',
    showoptions        => 0,
    optionspos         => 'bottom',
    rowcolors          => 'transparent',
    namecolors         => undef,
    order              => undef,
    namepos            => 'left',
    maxheight          => undef,
    allowvarsininclude => 0,
    topic              => undef
);

# reminder: don't forget change documentation (HolidaylistPlugin topic) if you add a new rendered option
my @renderedOptions = (
    'tablecaption', 'name',          'holidayicon',    'adayofficon',
    'workicon',     'notatworkicon', 'compatmodeicon', 'pubholidayicon'
);

# options to turn or switch things on (1) or off (0)
# this special handling allows 'on'/'yes';'off'/'no' values additionally to '1'/'0'
my @flagOptions = (
    'showweekends',    'removeatwork',
    'compatmode',      'enablepubholidays',
    'showpubholidays', 'navenable',
    'showmonthheader', 'showstatcol',
    'showstatrow',     'showstatsum',
    'showoptions',     'allowvarsininclude'
);

use vars qw(
  $startDays
  @processedTopics
  %rendererCache
  $expanding
  $hlid
);

sub init {

    # reset global vars
    # SMELL: what about the others
    $expanding = 0;
    $hlid      = 0;

    Foswiki::Func::addToZone( "head", "HOLIDAYLISTPLUGIN::CSS", <<CSS);
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/HolidaylistPlugin/hlp.css" media="all" /> 
CSS
}

sub HOLIDAYLIST() {
    my ( $session, $attributes, $topic, $web ) = @_;

    return '' unless Foswiki::Func::getContext()->{view};
    return '' if $expanding;    # don't evaluate %HOLIDAYLIST%
    local $expanding = 1;       # while expanding the event list

    # Item1491: horrific hack to stop the EditTablePlugin eating it's own
    # feet.
    local $Foswiki::Plugins::EditTablePlugin::recursionBlock = 1;

    # Localize globals to maintain separation between runs
    local %options;
    local @unknownParams;
    local %table;
    local %locationtable;
    local %icontable;

    $hlid++;

    return createUnknownParamsMessage()
      unless _initOptions( $attributes, $web );
    $options{topic} ||= "$web.$topic";

    # Read in the event list. Use %INCLUDE to get access control
    # checking right.
    my $text = join( "\n",
        map { '%INCLUDE{"' . $_ . '"}%' }
          split( /, */, $options{topic} ) );
    $text = Foswiki::Func::expandCommonVariables( $text, $topic, $web );

    return _renderHolidayList(
        _handlePublicHolidays( _fetchHolidayList($text) ), $web );
}

sub _initOptions() {
    my ( $params, $web ) = @_;

    my @allOptions = keys %defaults;

    # Check attributes:
    @unknownParams = ();
    foreach my $option ( keys %$params ) {
        next if $option =~ /^_/;    # internals
        push( @unknownParams, $option )
          unless grep( /^\Q$option\E$/, @allOptions );
    }
    return 0 if $#unknownParams != -1;

    my $cgi = Foswiki::Func::getCgiQuery();

    # Setup options (attributes>plugin preferences>defaults):
    %options = ();
    foreach my $option (@allOptions) {
        my $v = $cgi->param("hlp_${option}_$hlid");
        if ( !defined $v ) {
            $v =
                 ( !defined $cgi->param("hlp_id") )
              || ( $cgi->param("hlp_id") eq $hlid )
              ? $cgi->param("hlp_${option}")
              : undef;
        }
        $v = $params->{$option} unless defined $v;
        if ( defined $v ) {
            if ( grep /^\Q$option\E$/, @flagOptions ) {
                $options{$option} = ( $v !~ /^(0|false|no|off)$/i );
            }
            else {
                $options{$option} = $v;
            }
        }
        else {
            if ( grep /^\Q$option\E$/, @flagOptions ) {
                $v = Foswiki::Func::getPreferencesFlag(
                    "\UHOLIDAYLISTPLUGIN_$option\E")
                  || undef;
            }
            else {
                $v = Foswiki::Func::getPreferencesValue(
                    "\UHOLIDAYLISTPLUGIN_$option\E")
                  || undef;
            }
            $v = undef if ( defined $v ) && ( $v eq "" );
            $options{$option} = ( defined $v ) ? $v : $defaults{$option};
        }

    }

    # Render some options:
    foreach my $option (@renderedOptions) {
        if ( $options{$option} !~ /^(\s|\&nbsp\;)*$/ ) {
            $options{$option} = _renderText( $options{$option}, $web );
        }
    }

    my $defaultlang = undef;
    foreach my $lang ( split /\s*,\s*/, $options{lang} ) {
        chomp $lang;
        eval { Date::Calc::Language( Date::Calc::Decode_Language($lang) ); };

        $defaultlang = $lang unless defined $defaultlang;

        # Setup language specific month and day names:
        for ( my $i = 1 ; $i < 13 ; $i++ ) {
            if ( $i < 8 ) {
                my $dt = Day_of_Week_to_Text($i);
                $wdays{$dt} = $i;
                $wdays{ Day_of_Week_Abbreviation($i) } = $i;
                $wdays{ substr( $dt, 0, 2 ) } = $i;
            }
            my $mt = Month_to_Text($i);
            $months{$mt} = $i;
            $months{ substr( $mt, 0, 3 ) } = $i;
        }
    }
    eval { Date::Calc::Language( Date::Calc::Decode_Language($defaultlang) ); };

    # Setup user defined daynames:
    if (   ( defined $options{daynames} )
        && ( defined $defaults{daynames} )
        && ( $options{daynames} ne $defaults{daynames} ) )
    {
        my @dn = split /\s*\|\s*/, $options{daynames};
        if ( $#dn == 6 ) {
            for ( my $i = 1 ; $i < 8 ; $i++ ) {
                $wdays{ $dn[ $i - 1 ] } = $i;
            }
        }
    }

    # Setup user defined monthnames:
    if (   ( defined $options{monthnames} )
        && ( defined $defaults{monthnames} )
        && ( $options{monthnames} ne $defaults{monthnames} ) )
    {
        my @mn = split /\s*[\|,]\s*/, $options{monthnames};
        if ( $#mn == 11 ) {
            for ( my $i = 1 ; $i < 13 ; $i++ ) {
                $months{ $mn[ $i - 1 ] } = $i;
            }
        }
    }

    # Setup statcol(format|title) and statrow(format|title) defaults
    if ( $options{showweekends} ) {
        $options{statcolformat} = '%{h}'
          if $options{statcolformat} eq $defaults{statcolformat};
        $options{statcoltitle} = '%{l}'
          if $options{statcoltitle} eq $defaults{statcoltitle};
        $options{statrowformat} = '%{h}'
          if $options{statrowformat} eq $defaults{statrowformat};
        $options{statrowtitle} = '%{l}'
          if $options{statrowtitle} eq $defaults{statrowtitle};
    }

    @processedTopics = ();
    return 1;

}

sub createUnknownParamsMessage {
    my $msg;
    $msg = Foswiki::Func::getPreferencesValue("UNKNOWNPARAMSMSG") || undef;
    $msg = $defaults{unknownparamsmsg} unless defined $msg;
    $msg =~ s/\%UNKNOWNPARAMSLIST\%/join(', ', sort @unknownParams)/eg;
    $msg =~ s/\%KNOWNPARAMSLIST\%/join(', ', sort keys %defaults)/eg;
    return $msg;
}

sub getStartDate() {
    my ( $yy, $mm, $dd ) = Today();

    # handle startdate (absolute or offset)
    if ( defined $options{startdate} ) {
        my $sd = $options{startdate};
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
    if ( defined $options{year} ) {
        my $year = $options{year};
        if ( $year =~ /^(\d{4})$/ ) {
            $yy = $year;
        }
        elsif ( $year =~ /^([\+\-]?\d+)$/ ) {
            ( $yy, $mm, $dd ) = Add_Delta_YM( $yy, $mm, $dd, $1, 0 );
        }
    }

    # handle month (absolute or offset)
    if ( defined $options{month} ) {
        my $month   = $options{month};
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

    # handle week (absolute or offset)
    if ( defined $options{week} ) {
        my $week    = $options{week};
        my $matched = 0;
        if (   ( $week =~ /^\d+$/ )
            && ( $week > 0 )
            && ( $week <= Weeks_in_Year($yy) ) )
        {
            $matched = 1;
        }
        elsif ( $week =~ /^[\+\-]\d+$/ ) {
            $matched = 1;
            ( $yy, $mm, $dd ) = Add_Delta_Days( $yy, $mm, $dd, 7 * $week );
            $week = Week_of_Year( $yy, $mm, $dd );
        }
        ( $yy, $mm, $dd ) = Monday_of_Week( $week, $yy ) if ($matched);
    }

    # handle paging:
    my $cgi = Foswiki::Func::getCgiQuery();
    if ( defined $cgi->param( 'hlppage' . $hlid ) ) {
        if ( $cgi->param( 'hlppage' . $hlid ) =~ m/^([\+\-]?[\d\.]+)$/ ) {
            my $hlppage = $1;
            my $days    = int(
                (
                    defined $options{'navdays'}
                    ? $options{'navdays'}
                    : $options{'days'}
                ) * $hlppage
            );
            ( $yy, $mm, $dd ) = Add_Delta_YM( $yy, $mm, $dd, 0, $hlppage );
        }
    }

    return ( $dd, $mm, $yy );
}

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

sub _getTableRefs {
    my ($person) = @_;

    # cut whitespaces
    $person =~ s/\s+$//;

    my $ptableref = $table{$person};
    my $ltableref = $locationtable{$person};
    my $itableref = $icontable{$person};

    if ( !defined $ptableref ) {
        $ptableref              = [];
        $table{$person}         = $ptableref;
        $ltableref              = [];
        $locationtable{$person} = $ltableref;
        $itableref              = [];
        $icontable{$person}     = $itableref;
    }

    return ( $ptableref, $ltableref, $itableref );

}

sub _handleDateRange {
    my ( $person, $start, $end, $descr, $location, $icon, $excref ) = @_;

    my ( $ptableref, $ltableref, $itableref ) = _getTableRefs($person);

    my $date = $startDays;
    for (
        my $i = 0 ;
        ( $i < $options{days} ) && ( ( $date + $i ) <= $end ) ;
        $i++
      )
    {
        next if $$excref[$i];
        if ( ( $date + $i ) >= $start ) {
            $$ltableref[$i]{descr}    = $descr;
            $$ltableref[$i]{location} = $location;
            if ( defined $icon ) {
                $$ptableref[$i] = 4;
                $$itableref[$i] = $icon;
            }
            elsif ( defined $location ) {
                $$ptableref[$i] = 3;
            }
            else {
                $$ptableref[$i] = ( $start != $end ) ? 1 : 2;
            }
        }
    }
}

# Split a line consisting of fields separated by \s-\s, each field
# with at least one whitespace either side.
sub _fieldify {
    my ( $line, $lim ) = @_;
    return map { s/^\s+//; s/\s+$//; $_ } split( /\s\-\s/, $line, $lim );
}

sub _fetchHolidayList {
    my ($text) = @_;
    %table         = ();
    %locationtable = ();
    %icontable     = ();

    my ( $dd, $mm, $yy ) = &getStartDate();

    $startDays = Date_to_Days( $yy, $mm, $dd );

    my ( $eyy, $emm, $edd ) = Add_Delta_Days( $yy, $mm, $dd, $options{days} );
    my ($endDays) = Date_to_Days( $eyy, $emm, $edd );

    my ( $line, $descr );
    foreach $line ( grep( /$bullet_rx/, split( /\r?\n/, $text ) ) ) {
        my ( $person, $start, $end, $location, $icon );

        $line =~ s/\s+$//;
        $line =~ s/$bullet_rx//g;

        $descr = $line;

        _replaceSpecialDateNotations($line) if $options{compatmode};

        my $excref = &fetchExceptions( $line, $startDays, $endDays );

        if (   ( $line =~ m/^$daterange_rx/ )
            || ( $line =~ m/^$monthyearrange_rx/ ) )
        {
            my ( $sdate, $edate );
            ( $sdate, $edate, $person, $location, $icon ) =
              _fieldify( $line, 5 );
            ( $start, $end ) = ( _getDays( $sdate, 0 ), _getDays( $edate, 1 ) );
            next unless ( defined $start ) && ( defined $end );

            _handleDateRange( $person, $start, $end, $descr, $location, $icon,
                $excref );

        }
        elsif ( ( $line =~ m/^$date_rx/ ) || ( $line =~ m/^$monthyear_rx/ ) ) {
            my $date;
            ( $date, $person, $location, $icon ) = _fieldify( $line, 4 );
            ( $start, $end ) = ( _getDays( $date, 0 ), _getDays( $date, 1 ) );
            next unless ( defined $start ) && ( defined $end );

            _handleDateRange( $person, $start, $end, $descr, $location, $icon,
                $excref );
        }
        elsif ( $options{compatmode} ) {
            _handleCalendarEvents( $line, $descr, $yy, $mm, $dd, $startDays,
                $endDays, $excref );
        }

    }
    return ( \%table, \%locationtable, \%icontable );
}

sub _handlePublicHolidays {
    my ( $tableRef, $locationTableRef, $iconTableRef ) = @_;
    if ( $options{enablepubholidays} ) {
        my $all = '!!__@ALL__!!';
        $$tableRef{$all}         = [];
        $$locationTableRef{$all} = [];
        $$iconTableRef{$all}     = [];
        my ( $aptableref, $altableref, $aitableref ) =
          ( $$tableRef{$all}, $$locationTableRef{$all}, $$iconTableRef{$all} );
        for my $person ( keys %{$tableRef} ) {
            if ( ( $person ne $all ) && ( $person =~ /\@all/i ) ) {
                my ( $ptableref, $ltableref, $itableref ) = (
                    $$tableRef{$person}, $$locationTableRef{$person},
                    $$iconTableRef{$person}
                );
                for ( my $i = 0 ; $i < $options{days} ; $i++ ) {
                    if ( defined $$ptableref[$i] ) {
                        $$aptableref[$i] = 6;
                        $$altableref[$i] =
                          ( defined $$ltableref[$i] )
                          ? $$ltableref[$i]
                          : $$ptableref[$i];
                        $$aitableref[$i] = $$itableref[$i];
                    }
                }
            }
        }
    }
    return ( $tableRef, $locationTableRef, $iconTableRef );
}

sub _replaceSpecialDateNotations {

    # replace special (business) notations:
    ### DDD Wn yyyy
    ### DDD Week n yyyy
    $_[0] =~
s /($wdays_rx)\s+W(eek)?\s*([0-9]?[0-9])\s+($years_rx)/_getFullDateFromBusinessDate($1,$3,$4)/egi;
    ### Wn yyyy
    ### Week n yyyy
    $_[0] =~
s /W(eek)?\s*([0-9]?[0-9])\s+($years_rx)/_getFullDateFromBusinessDate('Mon',$2,$3)/egi;
}

sub fetchExceptions {
    my ( $line, $startDays, $endDays ) = @_;

    my @exceptions = ();

    $_[0] =~ s /X\s+{\s*([^}]+)\s*}// || return \@exceptions;
    my $ex = $1;

    for my $x ( split /\s*\,\s*/, $ex ) {
        my ( $start, $end ) = ( undef, undef );
        if ( ( $x =~ m/^$daterange_rx$/ ) || ( $x =~ m/^$monthyearrange_rx/ ) )
        {
            my ( $sdate, $edate ) = split /\s*\-\s*/, $x;
            $start = _getDays( $sdate, 0 );
            $end   = _getDays( $edate, 1 );

        }
        elsif ( ( $x =~ m/^$date_rx/ ) || ( $x =~ m/^$monthyear_rx/ ) ) {
            $start = _getDays( $x, 0 );
            $end   = _getDays( $x, 1 );
        }
        next unless defined $start && ( $start <= $endDays );
        next unless defined $end   && ( $end >= $startDays );

        for (
            my $i = 0 ;
            ( $i < $options{days} ) && ( ( $startDays + $i ) <= $end ) ;
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

sub _getFullDateFromBusinessDate {
    my ( $t_dow, $week, $year ) = @_;
    my ($ret);
    my ( $y1, $m1, $d1 );
    if ( check_business_date( $year, $week, $wdays{$t_dow} ) ) {
        ( $y1, $m1, $d1 ) =
          Business_to_Standard( $year, $week, $wdays{$t_dow} );
        $ret = "$d1 " . Month_to_Text($m1) . " $y1";
    }
    return $ret;
}

sub _handleCalendarEvents {
    my ( $line, $descr, $yy, $mm, $dd, $startDays, $endDays, $excref ) = @_;
    my ( $strdate, $person, $location, $icon );

    if ( $line =~ m/^A\s+$date_rx/ ) {
        ### Yearly: A dd MMM yyyy
        ( $strdate, $person, $location, $icon ) = _fieldify( $line, 4 );
        my ( $ptableref, $ltableref, $itableref ) = _getTableRefs($person);
        $strdate =~ s/^A\s+//;
        my ( $dd1, $mm1, $yy1 ) = split /\s+/, $strdate;
        $mm1 = $months{$mm1};

        return unless check_date( $yy1, $mm1, $dd1 );

        for ( my $i = 0 ; $i < $options{days} ; $i++ ) {
            next if $$excref[$i];
            my ( $y, $m, $d ) = Add_Delta_Days( $yy, $mm, $dd, $i );

            if ( ( $mm1 == $m ) && ( $dd1 == $d ) ) {
                $$ptableref[$i] = 5;
                $$ltableref[$i]{descr}    = $descr . ' (' . ( $y - $yy1 ) . ')';
                $$ltableref[$i]{location} = $location;
                $$itableref[$i]           = $icon;
            }
        }
    }
    elsif ( $line =~ m/^$days_rx\s+($months_rx)/ ) {
        ### Interval: dd MMM
        ( $strdate, $person, $location, $icon ) = _fieldify( $line, 4 );
        my ( $ptableref, $ltableref, $itableref ) = _getTableRefs($person);
        my ( $dd1, $mm1 ) = split /\s+/, $strdate;
        $mm1 = $months{$mm1};
        return if $dd1 > 31;

        for ( my $i = 0 ; $i < $options{days} ; $i++ ) {
            next if $$excref[$i];
            my ( $y, $m, $d ) = Add_Delta_Days( $yy, $mm, $dd, $i );
            if ( ( $m == $mm1 ) && ( $d == $dd1 ) ) {
                $$ptableref[$i]           = 5;
                $$ltableref[$i]{descr}    = $descr;
                $$ltableref[$i]{location} = $location;
                $$itableref[$i]           = $icon;
            }
        }
    }
    elsif ( $line =~ m/^[0-9L](\.|th)?\s+($wdays_rx)(\s+($months_rx))?/ ) {
        ### Interval: w DDD MMM
        ### Interval: L DDD MMM
        ### Monthly: w DDD
        ### Monthly: L DDD

        ( $strdate, $person, $location, $icon ) = _fieldify( $line, 4 );
        my ( $ptableref, $ltableref, $itableref ) = _getTableRefs($person);
        my ( $n1, $dow1, $mm1 ) = split /\s+/, $strdate;
        $dow1 = $wdays{$dow1};
        $mm1 = $months{$mm1} if defined $mm1;

        for ( my $i = 0 ; $i < $options{days} ; $i++ ) {
            next if $$excref[$i];
            my ( $y, $m, $d ) = Add_Delta_Days( $yy, $mm, $dd, $i );
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
                    $$ptableref[$i]           = 5;
                    $$ltableref[$i]{descr}    = $descr;
                    $$ltableref[$i]{location} = $location;
                    $$itableref[$i]           = $icon;
                }
            }
        }
    }
    elsif ( $line =~ m/^$days_rx\s+\-/ ) {
        ### Monthly: dd
        ( $strdate, $person, $location, $icon ) = _fieldify( $line, 4 );
        my ( $ptableref, $ltableref, $itableref ) = _getTableRefs($person);
        return if $strdate > 31;
        for ( my $i = 0 ; $i < $options{days} ; $i++ ) {
            next if $$excref[$i];
            my ( $y, $m, $d ) = Add_Delta_Days( $yy, $mm, $dd, $i );
            if ( $strdate == $d ) {
                $$ptableref[$i]           = 5;
                $$ltableref[$i]{descr}    = $descr;
                $$ltableref[$i]{location} = $location;
                $$itableref[$i]           = $icon;
            }
        }
    }
    elsif ( $line =~ m/^E\s+($wdays_rx)/ ) {
        ### Monthly: E DDD dd MMM yyy - dd MMM yyyy
        ### Monthly: E DDD dd MMM yyy
        ### Monthly: E DDD

        my $strdate2 = undef;
        if ( $line =~ m/^E\s+($wdays_rx)\s+$daterange_rx/ ) {
            ( $strdate, $strdate2, $person, $location, $icon ) =
              _fieldify( $line, 5 );
        }
        else {
            ( $strdate, $person, $location, $icon ) = _fieldify( $line, 4 );
        }
        my ( $ptableref, $ltableref, $itableref ) = _getTableRefs($person);

        $strdate =~ s/^E\s+//;
        my ($dow1) = split /\s+/, $strdate;
        $dow1 = $wdays{$dow1};

        $strdate =~ s/^\S+\s*//;

        my ( $start, $end ) = ( undef, undef );
        if ( ( defined $strdate ) && ( $strdate ne "" ) ) {
            $start = _getDays($strdate);
            return unless defined $start;
        }

        if ( defined $strdate2 ) {
            $end = _getDays($strdate2);
            return unless defined $end;
        }

        return if ( defined $start ) && ( $start > $endDays );
        return if ( defined $end )   && ( $end < $startDays );

        for ( my $i = 0 ; $i < $options{days} ; $i++ ) {
            next if $$excref[$i];
            my ( $y, $m, $d ) = Add_Delta_Days( $yy, $mm, $dd, $i );
            my $date = Date_to_Days( $y, $m, $d );
            my $dow = Day_of_Week( $y, $m, $d );
            if (   ( $dow == $dow1 )
                && ( ( !defined $start ) || ( $date >= $start ) )
                && ( ( !defined $end )   || ( $date <= $end ) ) )
            {
                $$ptableref[$i]           = 5;
                $$ltableref[$i]{descr}    = $descr;
                $$ltableref[$i]{location} = $location;
                $$itableref[$i]           = $icon;
            }
        }

    }
    elsif ( $line =~ m/^E\d+\s+$date_rx/ ) {
        ### Periodic: En dd MMM yyyy - dd MMM yyyy
        ### Periodic: En dd MMM yyyy
        my $strdate2 = undef;
        if ( $line =~ m/^E\d+\s+$daterange_rx/ ) {
            ( $strdate, $strdate2, $person, $location, $icon ) =
              _fieldify( $line, 5 );
        }
        else {
            ( $strdate, $person, $location, $icon ) = _fieldify( $line, 4 );
        }
        my ( $ptableref, $ltableref, $itableref ) = _getTableRefs($person);

        $strdate =~ s/^E//;
        my ($n1) = split /\s+/, $strdate;

        return unless $n1 > 0;

        $strdate =~ s/^\d+\s+//;

        my ( $start, $end ) = ( undef, undef );
        my ( $dd1, $mm1, $yy1 ) = split /\s+/, $strdate;
        $mm1 = $months{$mm1};

        $start = _getDays($strdate);
        return unless defined $start;

        $end = _getDays($strdate2) if defined $strdate2;
        return if ( defined $strdate2 ) && ( !defined $end );

        return if ( defined $start ) && ( $start > $endDays );
        return if ( defined $end )   && ( $end < $startDays );

        if ( $start < $startDays ) {
            ( $yy1, $mm1, $dd1 ) = Add_Delta_Days(
                $yy1, $mm1, $dd1,
                ### $n1 * int( (abs($startDays-$start)/$n1) + ($startDays-$start!=0?1:0) ) );
                $n1 * int(
                    ( abs( $startDays - $start ) / $n1 ) +
                      ( ( abs( $startDays - $start ) % $n1 ) != 0 ? 1 : 0 )
                )
            );
            $start = Date_to_Days( $yy1, $mm1, $dd1 );
        }

        # start at first occurence and increment by repeating count ($n1)
        for (
            my $i = ( abs( $startDays - $start ) % $n1 ) ;
            (
                     ( $i < $options{days} )
                  && ( ( !defined $end ) || ( ( $startDays + $i ) <= $end ) )
              ) ;
            $i += $n1
          )
        {
            next if $$excref[$i];
            if ( ( $startDays + $i ) >= $start ) {
                $$ptableref[$i]           = 5;
                $$ltableref[$i]{descr}    = $descr;
                $$ltableref[$i]{location} = $location;
                $$itableref[$i]           = $icon;
            }
        }    # for
    }    # if

}

sub _mystrftime($$$$) {
    my ( $yy, $mm, $dd, $format ) = @_;
    my $text = defined $format ? $format : $options{headerformat};

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

sub _renderHolidayList() {
    my ( $tableRef, $locationTableRef, $iconTableRef, $web ) = @_;
    my $text = "";

    my ( $ty, $tm, $td ) = Today();
    my $today = Date_to_Days( $ty, $tm, $td );

    my $optionrow = $options{showoptions} ? _renderOptions() : '';

    # create table header:

    $text .= $optionrow if ( $options{optionspos} =~ /^(top|both)$/i );
    $text .= '<noautolink>' . CGI::a( { -name => 'hlpid' . $hlid }, "" );
    $text .= CGI::start_table(
        {
            -class => 'hlpTable',
            -style => "background-color:" . $options{tablebgcolor},
            -width => $options{width}
        }
    );

    $text .= CGI::caption( { -align => $options{tablecaptionalign} },
        $options{tablecaption} );

    my $header   = "";
    my $namecell = "";
    $namecell .= CGI::th(
        {
            -class   => "hlpNav",
            -width   => $options{nwidth},
            -rowspan => ( $options{showmonthheader} ? 2 : 1 )
        },
        "<div class='hlpResourceTitle'>" 
          . $options{name} 
          . "</div>"
          . (
              $options{'navenable'}
            ? &_renderNav(-1) . &_renderNav(0) . &_renderNav(1)
            : ''
          )
    );

    my ( $dd, $mm, $yy ) = getStartDate();

    # render month header:
    my $monthheader = "";
    if ( $options{showmonthheader} ) {
        my $restdays = $options{days};
        my ( $yy1, $mm1, $dd1 ) = ( $yy, $mm, $dd );
        while ( $restdays > 0 ) {
            my $daysdiff = Days_in_Month( $yy1, $mm1 ) - $dd1 + 1;
            $daysdiff = $restdays if ( $restdays - $daysdiff < 0 );
            $monthheader .= CGI::th(
                {
                    -class   => 'hlpMonthHeader',
                    -colspan => $daysdiff,
                    -title   => Month_to_Text($mm1) . ' ' . $yy1
                },
                _mystrftime( $yy1, $mm1, $dd1, $options{monthheaderformat} )
            );
            ( $yy1, $mm1, $dd1 ) =
              Add_Delta_Days( $yy1, $mm1, $dd1, $daysdiff );
            $restdays -= $daysdiff;
        }
        if ( $options{showstatcol} ) {
            foreach my $h (
                split( /\|/, _getStatOption( 'statheader', 'statcolheader' ) ) )
            {
                $monthheader .= CGI::th(
                    {
                        -class  => 'hlpStatsHeader',
                        rowspan => 2,
                    },
                    $h
                );
            }
        }
    }

    # render header:

    for ( my $i = 0 ; $i < $options{days} ; $i++ ) {
        my ( $yy1, $mm1, $dd1 ) = Add_Delta_Days( $yy, $mm, $dd, $i );
        my $dow = Day_of_Week( $yy1, $mm1, $dd1 );
        my $date = Date_to_Days( $yy1, $mm1, $dd1 );

        my $bgcolor;
        $bgcolor = $options{weekendbgcolor} unless $dow < 6;
        $bgcolor = $options{todaybgcolor}
          if ( defined $options{todaybgcolor} ) && ( $today == $date );

        my $class = 'hlpDayHeader';
        $class = 'hlpWeekendHeader' unless $dow < 6;
        $class = 'hlpTodayHeader' if $today == $date;

        my %params = (
            -class => $class,
            -title => Date_to_Text_Long( $yy1, $mm1, $dd1 )
        );
        $params{style} = 'background-color:' . $bgcolor if defined $bgcolor;
        $params{-width} = $options{tcwidth}
          if ( ( defined $options{tcwidth} )
            && ( ( $dow < 6 ) || $options{showweekends} ) );
        $params{-style} = 'color:' . $options{todayfgcolor}
          if ( $today == $date ) && ( defined $options{todayfgcolor} );
        $header .= CGI::th( \%params,
            ( ( $dow < 6 ) || $options{showweekends} )
            ? _mystrftime( $yy1, $mm1, $dd1, undef )
            : '&nbsp;' );
    }
    if ( ( !$options{showmonthheader} ) && $options{showstatcol} ) {
        foreach my $h (
            split( /\|/, _getStatOption( 'statheader', 'statcolheader' ) ) )
        {
            $header .= CGI::th( {}, $h );
        }

    }
    $text .= CGI::Tr( {},
            ( $options{namepos} =~ /^(left|both)$/i ? $namecell : '' )
          . $monthheader
          . ( $options{namepos} =~ /^(right|both)$/i ? $namecell : '' ) )
      . CGI::Tr($header)
      if $options{showmonthheader};
    $text .= CGI::Tr( {},
            ( $options{namepos} =~ /^(left|both)$/i ? $namecell : '' ) 
          . $header
          . ( $options{namepos} =~ /^(right|both)$/i ? $namecell : '' ) )
      unless $options{showmonthheader};

    # create table with names and dates:

    my %iconstates = (
        0 => $options{workicon},
        1 => $options{holidayicon},
        2 => $options{adayofficon},
        3 => $options{notatworkicon},
        4 => $options{notatworkicon},
        5 => $options{compatmodeicon},
        6 => $options{pubholidayicon}
    );

    my @rowcolors =
      defined $options{rowcolors}
      ? split( /[\,\|\;\:]/, $options{rowcolors} )
      : ( $options{tablebgcolor} );
    my %namecolors = %{ _getNameColors() };

    my %sumstatistics;
    my %rowstatistics;
    foreach my $person ( @{ _reorderPersons($tableRef) } ) {
        my $ptableref = $$tableRef{$person};
        my $ltableref = $$locationTableRef{$person};
        my $itableref = $$iconTableRef{$person};

        my $aptableref = $$tableRef{'!!__@ALL__!!'};
        my $altableref = $$locationTableRef{'!!__@ALL__!!'};
        my $aitableref = $$iconTableRef{'!!__@ALL__!!'};

        # ignore entries with @all
        next
          if $options{enablepubholidays}
              && ( !$options{showpubholidays} )
              && ( $person =~ /\@all/i );
        next if $person eq '!!__@ALL__!!';

        # ignore table rows without an entry if removeatwork == 1
        next
          if $options{removeatwork}
              && !grep( /[^0]+/, join( '', map( $_ || 0, @{$ptableref} ) ) );

        my %statistics;

        my $rowcolor = shift @rowcolors;
        push @rowcolors, $rowcolor;
        $rowcolor = $namecolors{$person} if defined $namecolors{$person};

        $person =~ s/\@all//ig if $options{enablepubholidays};

        my $tr = "";
        my $pcell = CGI::th( { -class => 'hlpResourceHeader', },
            '<noautolink>' . _renderText( $person, $web ) . '</noautolink>' );
        $tr .= $pcell if $options{namepos} =~ /^(left|both)$/i;

        for ( my $i = 0 ; $i < $options{days} ; $i++ ) {
            my ( $yy1, $mm1, $dd1 ) = Add_Delta_Days( $yy, $mm, $dd, $i );
            my $dow = Day_of_Week( $yy1, $mm1, $dd1 );

            my $bgcolor;
            my $class = 'hlpCell';

            $bgcolor = $options{weekendbgcolor} unless $dow < 6;
            $class   = 'hlpWeekend'             unless $dow < 6;

            if ( $today == Date_to_Days( $yy1, $mm1, $dd1 ) ) {
                $class = 'hlpToday';
                if ( defined $options{todaybgcolor} ) {
                    $bgcolor = $options{todaybgcolor};
                }
            }

            my $td = "";

            if (   $options{enablepubholidays}
                && defined $$aptableref[$i]
                && $$aptableref[$i] > 0 )
            {
                $statistics{pubholidays}++;
                $rowstatistics{$i}{pubholidays}++;
                $sumstatistics{pubholidays}++;
            }
            if (
                ( defined $$ptableref[$i] && $$ptableref[$i] > 0 )
                || (   $options{enablepubholidays}
                    && defined $$aptableref[$i]
                    && $$aptableref[$i] > 0 )
              )
            {
                $statistics{holidays}++;
                $statistics{icons}{ $$itableref[$i] }++
                  if defined $$itableref[$i];
                $statistics{icons}{ $options{statformat_unknown} }++
                  if !defined $$itableref[$i];
                $statistics{locations}{ $$ltableref[$i]{location} }++
                  if defined $$ltableref[$i]{location};
                $statistics{locations}{ $options{statformat_unknown} }++
                  if !defined $$ltableref[$i]{location};
                $rowstatistics{$i}{holidays}++;
                $rowstatistics{$i}{icons}{ $$itableref[$i] }++
                  if defined $$itableref[$i];
                $rowstatistics{$i}{icons}{ $options{statformat_unknown} }++
                  if !defined $$itableref[$i];
                $rowstatistics{$i}{locations}{ $$ltableref[$i]{location} }++
                  if defined $$ltableref[$i]{location};
                $rowstatistics{$i}{locations}{ $options{statformat_unknown} }++
                  if !defined $$ltableref[$i]{location};
                $sumstatistics{holidays}++;
                $sumstatistics{icons}{ $$itableref[$i] }++
                  if defined $$itableref[$i];
                $sumstatistics{icons}{ $options{statformat_unknown} }++
                  if !defined $$itableref[$i];
                $sumstatistics{locations}{ $$ltableref[$i]{location} }++
                  if defined $$ltableref[$i]{location};
                $sumstatistics{locations}{ $options{statformat_unknown} }++
                  if !defined $$ltableref[$i]{location};

            }
            else {
                $statistics{work}++;
                $rowstatistics{$i}{work}++;
                $sumstatistics{work}++;
            }
            $statistics{days}++;
            $statistics{'days-w'}++ if $dow < 6;
            $rowstatistics{$i}{days} = 1;
            $rowstatistics{$i}{'days-w'} = 1;
            $sumstatistics{days}++;
            $sumstatistics{'days-w'}++ if $dow < 6;

            my $title = _substTitle(
                $person . ' -- ' . Date_to_Text_Long( $yy1, $mm1, $dd1 ) );
            my $fgcolor = undef;

            if ( ( $dow < 6 ) || $options{showweekends} ) {
                my $icon =
                  $iconstates{ defined $$ptableref[$i] ? $$ptableref[$i] : 0 };
                if (   $dow < 6
                    && $options{enablepubholidays}
                    && defined $$aptableref[$i]
                    && $$aptableref[$i] > 0 )
                {
                    $statistics{'pubholidays-w'}++;
                    $rowstatistics{$i}{'pubholidays-w'}++;
                    $sumstatistics{'pubholidays-w'}++;
                }

                # override personal holidays with public holidays:
                if ( $options{enablepubholidays} && defined $$aptableref[$i] ) {
                    $icon           = $iconstates{ $$aptableref[$i] };
                    $$itableref[$i] = $$aitableref[$i];
                    $$ltableref[$i] = $$altableref[$i];
                }

                if (
                       $dow < 6
                    && defined $$ptableref[$i]
                    && $$ptableref[$i] > 0
                    && (   ( !defined $$aptableref[$i] )
                        || ( $$aptableref[$i] <= 0 ) )
                  )
                {
                    $statistics{'holidays-w'}++;
                    $statistics{'icons-w'}
                      { ( defined $$itableref[$i] ? $$itableref[$i] : $icon )
                      }++;
                    $statistics{'locations-w'}{ $$ltableref[$i]{location} }++
                      if defined $$ltableref[$i]{location};
                    $statistics{'locations-w'}{ $options{statformat_unknown} }++
                      if !defined $$ltableref[$i]{location};
                    $rowstatistics{$i}{'holidays-w'}++;
                    $rowstatistics{$i}{'icons-w'}
                      { ( defined $$itableref[$i] ? $$itableref[$i] : $icon )
                      }++;
                    $rowstatistics{$i}{'locations-w'}
                      { $$ltableref[$i]{location} }++
                      if defined $$ltableref[$i]{location};
                    $rowstatistics{$i}{'locations-w'}
                      { $options{statformat_unknown} }++
                      if !defined $$ltableref[$i]{location};
                    $sumstatistics{'holidays-w'}++;
                    $sumstatistics{'icons-w'}
                      { ( defined $$itableref[$i] ? $$itableref[$i] : $icon )
                      }++;
                    $sumstatistics{'locations-w'}{ $$ltableref[$i]{location} }++
                      if defined $$ltableref[$i]{location};
                    $sumstatistics{'locations-w'}
                      { $options{statformat_unknown} }++
                      if !defined $$ltableref[$i]{location};
                }
                else {
                    $statistics{'work-w'}++;
                    $rowstatistics{$i}{'work-w'}++;
                    $sumstatistics{'work-w'}++;
                }

                if ( defined $$itableref[$i] ) {
                    $icon = $$itableref[$i];
                    $icon = _renderText( $icon, $web )
                      if $icon !~ /^(\s|\&nbsp\;)*$/;
                }

                my $location = $$ltableref[$i]{descr} if defined $ltableref;
                $title .= ": " . $$ltableref[$i]{location}
                  if defined $ltableref && defined $$ltableref[$i]{location};

                if ( defined $location ) {
                    $location =~ s/\s*(\@all|(fg)?color\([^\)]+\))//ig
                      if $options{enablepubholidays};    # remove @all
                    $location = _substTitle($location);
                    $location = CGI::escapeHTML($location);

                 # SMELL: this is broken somehow
                 #   $icon =~ s/<img /<img alt="$location" /is
                 #     unless $icon =~
                 #         s/(<img[^>]+alt=")[^">]+("[^>]*>)/$1$location$2/is;
                 #   $icon =~ s/<img /<img title="$location" /is
                 #     unless $icon =~
                 #         s/(<img[^>]+title=")[^">]+("[^>]*>)/$1$location$2/is;
                }
                if ( $icon =~ s/fgcolor\(([^\)]+)\)//g ) {
                    $fgcolor = $1;
                }
                if ( $icon =~ s/color\(([^\)]+)\)//g ) {
                    $bgcolor = $1;
                }
                if ( $icon =~ s/class\(([^\)]+)\)//g ) {
                    $class = $1;
                }
                else {
                    $td .= $icon;
                }
            }
            else {
                $td .= '&nbsp;';
            }
            $tr .= CGI::td(
                {
                    -class => $class,
                    -style => ( defined $fgcolor ? "color:$fgcolor;" : "" )
                      . (
                        defined $bgcolor ? "background-color:$bgcolor;" : "" ),
                    -title => $title
                },
                $td
            );
        }
        $tr .= _renderStatisticsCol( \%statistics )
          if ( $options{showstatcol} );
        $tr .= $pcell if $options{namepos} =~ /^(right|both)$/i;
        $text .= CGI::Tr( { -style => "background-color:" . $rowcolor }, $tr );
    }
    $text .= _renderStatisticsRow( \%rowstatistics, \%sumstatistics )
      if ( $options{showstatrow} );
    $text .= _renderStatisticsSumRow( \%sumstatistics )
      if ( $options{showstatcol}
        && ( !$options{showstatrow} )
        && ( $options{showstatsum} ) );
    $text .= CGI::end_table();
    $text .= $optionrow if ( $options{optionspos} =~ /^(bottom|both)$/i );
    $text .= '</noautolink>';

    $text = CGI::div(
        {
            -class => 'holidaylistPlugin',
            -style => (
                defined $options{maxheight}
                ? "max-height:$options{maxheight}"
                : ""
            )
        },
        $text
    );

    return $text;
}

sub _int {
    return $_[0] =~ /(\d+)/ ? $1 : 0;
}

sub _reorderPersons {
    my ($tableRef) = @_;
    my @persons = ();
    if ( defined $options{order} ) {
        if ( $options{order} =~ /\[:nextfirst:\]/i ) {
            @persons = sort {
                join( '', map( $_ || 0, @{ $$tableRef{$b} } ) ) cmp
                  join( '', map( $_ || 0, @{ $$tableRef{$a} } ) )
            } keys %{$tableRef};
        }
        elsif ( $options{order} =~ /\[:ralpha:\]/ ) {
            @persons = sort { $b cmp $a } keys %{$tableRef};
        }
        elsif ( $options{order} =~ /\[:num:\]/ ) {
            @persons = sort { _int($a) <=> _int($b) } keys %{$tableRef};
        }
        elsif ( $options{order} =~ /\[:rnum:\]/ ) {
            @persons = sort { _int($b) <=> _int($a) } keys %{$tableRef};
        }
        else {
            @persons = split( /\s*[\,\;\|]\s*/, $options{order} );
            if ( $options{order} =~ /\[:rest:\]/i ) {
                my @rest = ();
                foreach my $p ( sort keys %{$tableRef} ) {
                    push @rest, $p unless grep( /^\Q$p\E$/, @persons );
                }
                my $order = $options{order};
                $order =~ s/\[:rest:\]/join(',', @rest)/eig;
                @persons = split( /\s*[\,\;\|]\s*/, $order );
            }
        }
    }
    else {
        @persons = sort keys %{$tableRef};
    }
    return \@persons;

}

sub _getNameColors {
    my %colors = ();
    return \%colors unless defined $options{namecolors};
    foreach my $entry ( split( /\s*[\,\|\;]\s*/, $options{namecolors} ) ) {
        my ( $name, $color ) = split( /\:/, $entry );
        $colors{$name} = $color;
    }
    return \%colors;
}

sub _substTitle {
    my ($title) = @_;

    $title =~ s/<!--.*?-->//g;        # remove HTML comments
    $title =~ s/ - <img[^>]+>//ig;    # throw image address away
    $title =~ s/<\/?\S+[^>]*>//g;

    $title =~ s /&nbsp;/ /g;
    $title =~ s/\%(\w+[^\%]+?)\%//g;    # delete Vars
    $title =~
      s/\[\[[^\]]+\]\[([^\]]+)\]\]/$1/g;    # replace forced link with comment
    $title =~ s/\[\[([^\]]+)\]\]/$1/g;      # replace forced link with comment
    $title =~ s/\[\[/!\[\[/g;               # quote forced links - !!!unused
    $title =~ s/[A-Z][a-z0-9]+[\.\/]([A-Z])/$1/g;    # delete Web names
    ##$title =~ s/([A-Z][a-z]+\w*[A-Z][a-z0-9]+)/$1/g; # quote WikiNames

    $title =~ s/(class|fgcolor|color)\(([^\)]+)\)//g;   # remove view config
    $title =~ s/\s*\-\s*$//;                            # remove trailing dashes
    $title =~ s/X\s*{[^}]*}\s*//g;                      # remove excludes

    return $title;
}

sub _substStatisticsVars {
    my ( $textformat, $titleformat, $statisticsref ) = @_;
    return ( _substStatsVars( $textformat, $statisticsref ),
        _substTitle( _substStatsVars( $titleformat, $statisticsref ) ) );
}

sub _substStatsVars {
    my ( $textformat, $statisticsref ) = @_;

    my $text = $textformat;

    $statisticsref = {} unless defined $statisticsref;

    my %statistics = %{$statisticsref};

    if ( $textformat =~ /\%{ll:?}/i ) {
        my $t = "";
        foreach my $location ( sort keys %{ $statistics{'locations-w'} } ) {
            my $f = $options{statformat_ll};
            $f =~ s/\%LOCATION/$location/g;
            $t .= $f;
        }
        $text =~ s/\%{ll:?}/$t/g;
    }
    if ( $textformat =~ /\%{l}/i ) {
        my $t = "";
        foreach my $location ( sort keys %{ $statistics{'locations'} } ) {
            my $f = $options{statformat_l};
            $f =~ s/\%LOCATION/$location/g;
            $t .= $f;
        }
        $text =~ s/\%{l:?}/$t/g;
    }
    if ( $textformat =~ /\%{ii:?}/i ) {
        my $t = "";
        foreach my $icon ( keys %{ $statistics{'icons-w'} } ) {
            my $f = $options{statformat_ii};
            $f =~ s/\%ICON/$icon/g;
            $t .= $f;
        }
        $text =~ s/\%{ii:?}/$t/g;
    }
    if ( $textformat =~ /\%{i:?}/i ) {
        my $t = "";
        foreach my $icon ( keys %{ $statistics{'icons-w'} } ) {
            my $f = $options{statformat_i};
            $f =~ s/\%ICON/$icon/g;
            $t .= $f;
        }
        $text =~ s/\%{i:?}/$t/g;
    }

    sub _vz {
        return
            defined $_[0]                  ? $_[0]
          : defined $options{statformat_0} ? $options{statformat_0}
          :                                  0;
    }
    $text =~ s/\%{i:([^}]+)}/_vz($statistics{icons}{$1})/egi;
    $text =~ s/\%{ii:([^}]+)}/_vz($statistics{'icons-w'}{$1})/egi;
    $text =~ s/\%{l:([^}]+)}/_vz($statistics{locations}{$1})/egi;
    $text =~ s/\%{ll:([^}]+)}/_vz($statistics{'locations-w'}{$1})/egi;

    $text =~ s/\%hh/_vz($statistics{'holidays-w'})/egi;
    $text =~ s/\%h/_vz($statistics{holidays})/egi;
    $text =~ s/\%{h:?}/_vz($statistics{holidays})/egi;
    $text =~ s/\%{hh:?}/_vz($statistics{'holidays-w'})/egi;

    $text =~ s/\%pp/_vz($statistics{'pubholidays-w'})/egi;
    $text =~ s/\%p/_vz($statistics{pubholidays})/egi;
    $text =~ s/\%{p:?}/_vz($statistics{pubholidays})/egi;
    $text =~ s/\%{pp:?}/_vz($statistics{'pubholidays-w'})/egi;

    $text =~ s/\%ww/_vz($statistics{'work-w'})/egi;
    $text =~ s/\%w/_vz($statistics{work})/egi;
    $text =~ s/\%{w:?}/_vz($statistics{work})/egi;
    $text =~ s/\%{ww:?}/_vz($statistics{'work-w'})/egi;

    $text =~ s/\%dd/_vz($statistics{'days-w'})/egi;
    $text =~ s/\%d/_vz($statistics{days})/egi;
    $text =~ s/\%{d:?}/_vz($statistics{days})/egi;
    $text =~ s/\%{dd:?}/_vz($statistics{'days-w'})/egi;

    # percentages:
    sub _dz {
        return defined $_[0] ? $_[0] : 0;
    }

    sub _perc {
        return _dz( $_[1] ) == 0 ? "n.d." : sprintf(
            $options{statformat_perc},
            ( _dz( $_[0] ) * 100 / _dz( $_[1] ) )
        );
    }

    # locations to days:
    $text =~
      s/\%{ld:([^}]+)}/_perc($statistics{locations}{$1}, $statistics{days})/egi;
    $text =~
s/\%{ldd:([^}]+)}/_perc($statistics{locations}{$1}, $statistics{'days-w'})/egi;
    $text =~
s/\%{lld:([^}]+)}/_perc($statistics{locations}{$1}, $statistics{days})/egi;
    $text =~
s/\%{lldd:([^}]+)}/_perc($statistics{locations}{$1}, $statistics{'days-w'})/egi;

    # locations to holidays:
    $text =~
s/\%{lh:([^}]+)}/_perc($statistics{locations}{$1}, $statistics{holidays})/egi;
    $text =~
s/\%{lhh:([^}]+)}/_perc($statistics{locations}{$1}, $statistics{'holidays-w'})/egi;
    $text =~
s/\%{llh:([^}]+)}/_perc($statistics{locations}{$1}, $statistics{holidays})/egi;
    $text =~
s/\%{llhh:([^}]+)}/_perc($statistics{locations}{$1}, $statistics{'holidays-w'})/egi;

    # icons to days:
    $text =~
      s/\%{id:([^}]+)}/_perc($statistics{icons}{$1}, $statistics{days})/egi;
    $text =~
s/\%{idd:([^}]+)}/_perc($statistics{icons}{$1}, $statistics{'days-w'})/egi;
    $text =~
      s/\%{iid:([^}]+)}/_perc($statistics{icons}{$1}, $statistics{days})/egi;
    $text =~
s/\%{iidd:([^}]+)}/_perc($statistics{icons}{$1}, $statistics{'days-w'})/egi;

    # icons to holidays:
    $text =~
      s/\%{ih:([^}]+)}/_perc($statistics{icons}{$1}, $statistics{holidays})/egi;
    $text =~
s/\%{ihh:([^}]+)}/_perc($statistics{icons}{$1}, $statistics{'holidays-w'})/egi;
    $text =~
s/\%{iih:([^}]+)}/_perc($statistics{icons}{$1}, $statistics{holidays})/egi;
    $text =~
s/\%{iihh:([^}]+)}/_perc($statistics{icons}{$1}, $statistics{'holidays-w'})/egi;

    # holidays to days:
    $text =~ s/\%{hd:?}/_perc($statistics{holidays},$statistics{days})/egi;
    $text =~ s/\%{hdd:?}/_perc($statistics{holidays},$statistics{'days-w'})/egi;
    $text =~
      s/\%{hhd:?}/_perc($statistics{'holidays-w'}, $statistics{days})/egi;
    $text =~
      s/\%{hhdd:?}/_perc($statistics{'holidays-w'}, $statistics{'days-w'})/egi;

    # public holidays to days:
    $text =~ s/\%{pd:?}/_perc($statistics{pubholidays},$statistics{days})/egi;
    $text =~
      s/\%{pdd:?}/_perc($statistics{pubholidays},$statistics{'days-w'})/egi;
    $text =~
      s/\%{ppd:?}/_perc($statistics{'pubholidays-w'}, $statistics{days})/egi;
    $text =~
s/\%{ppdd:?}/_perc($statistics{'pubholidays-w'}, $statistics{'days-w'})/egi;

    # working days to days:
    $text =~ s/\%{wd:?}/_perc($statistics{work}, $statistics{days})/egi;
    $text =~ s/\%{wdd:?}/_perc($statistics{work}, $statistics{'days-w'})/egi;
    $text =~ s/\%{wwd:?}/_perc($statistics{'work-w'}, $statistics{days})/egi;
    $text =~
      s/\%{wwdd:?}/_perc($statistics{'work-w'}, $statistics{'days-w'})/egi;

    return $text;
}

sub _getStatOption {
    return ( defined $options{ $_[0] } )
      ? $options{ $_[0] }
      : $options{ $_[1] };
}

sub _renderStatisticsSumRow {
    my ($sumstatisticsref) = @_;
    my $cgi                = Foswiki::Func::getCgiQuery();
    my $text               = "";
    my $row                = "";
    my @stattitles =
      split( /\|/, _getStatOption( 'stattitle', 'statcoltitle' ) );
    foreach my $statcol (
        split( /\|/, _getStatOption( 'statformat', 'statcolformat' ) ) )
    {
        my $stattitle = shift @stattitles;
        $stattitle = _getStatOption( 'stattitle', 'statcoltitle' )
          unless defined $stattitle;
        my ( $txt, $t ) =
          _substStatisticsVars( $statcol, $stattitle, $sumstatisticsref );
        $row .= $cgi->th( { -title => $t }, $txt );
    }
    $row .= $cgi->th('&nbsp;') if $options{namepos} =~ /^(right|both)$/i;
    my $colspan = $options{days};
    $colspan++ if $options{namepos} =~ /^(left|both)$/i;
    $text .= $cgi->Tr( { -class => "hlpStatisticsSum" },
        $cgi->th( { -colspan => $colspan }, '&nbsp;' ) . $row );

    return $text;
}

sub _renderStatisticsRow {
    my ( $statisticsref, $sumstatisticsref ) = @_;
    my $cgi  = Foswiki::Func::getCgiQuery();
    my $text = "";
    my ( $dd, $mm, $yy ) = getStartDate();

    my ( $ty, $tm, $td ) = Today();
    my $today = Date_to_Days( $ty, $tm, $td );

    my $statrowformat = _getStatOption( 'statformat', 'statrowformat' );
    my $statrowtitle  = _getStatOption( 'stattitle',  'statrowtitle' );
    my $statrowheader = _getStatOption( 'statheader', 'statrowheader' );

    my @rowformats = split( /\|/, $statrowformat );
    my @rowheaders = split( /\|/, $statrowheader );
    my @rowtitles  = split( /\|/, $statrowtitle );
    my $showsums   = 0;
    foreach my $rowformat (@rowformats) {
        my $rowheader = shift(@rowheaders);
        my $rowtitle  = shift(@rowtitles);
        $rowheader = $statrowheader unless defined $rowheader;
        $rowtitle  = $statrowtitle  unless defined $rowtitle;
        my $row = "";
        for ( my $i = 0 ; $i < $options{days} ; $i++ ) {
            my ( $yy1, $mm1, $dd1 ) = Add_Delta_Days( $yy, $mm, $dd, $i );
            my $dow = Day_of_Week( $yy1, $mm1, $dd1 );
            my $date = Date_to_Days( $yy1, $mm1, $dd1 );
            my ( $text, $title ) =
              _substStatisticsVars( $rowformat, $rowtitle,
                $$statisticsref{$i} );

            my $style = "";
            $style .= "color:$options{todayfgcolor};"
              if ( defined $options{todayfgcolor} ) && ( $date == $today );
            $style .= "background-color:$options{todaybgcolor};"
              if ( defined $options{todaybgcolor} ) && ( $date == $today );
            if ( ( $dow < 6 ) || ( $options{showweekends} ) ) {
                $row .= $cgi->td(
                    {
                        -style => $style,
                        -title => $title,
                    },
                    $text
                );
            }
            else {
                $row .=
                  $cgi->th( { -style => $style, -title => $title }, '&nbsp;' );
            }
        }

        if ( ( !$showsums ) && ( $options{showstatcol} ) ) {
            $showsums = 1;
            my @rowspanf = split( /\|/, $statrowformat );
            my $rowspan = $#rowspanf + 1;
            if ( $options{showstatsum} ) {
                my @stattitles =
                  split( /\|/, _getStatOption( 'stattitle', 'statcoltitle' ) );
                foreach my $statcol (
                    split(
                        /\|/, _getStatOption( 'statformat', 'statcolformat' )
                    )
                  )
                {
                    my $stattitle = shift @stattitles;
                    $stattitle = _getStatOption( 'stattitle', 'statcoltitle' )
                      unless defined $stattitle;
                    my ( $txt, $t ) =
                      _substStatisticsVars( $statcol, $stattitle,
                        $sumstatisticsref );
                    $row .= $cgi->th(
                        {
                            -rowspan => $rowspan,
                            -title   => $t
                        },
                        $txt
                    );
                }
            }
            else {
                my @colspanf =
                  split( /\|/,
                    _getStatOption( 'statformat', 'statcolformat' ) );
                my $colspan = $#colspanf + 1;
                $row .=
                  $cgi->th( { -rowspan => $rowspan, -colspan => $colspan },
                    '&nbsp;' );
            }
        }

        $text .= $cgi->Tr(
            {
                -class => "hlpStatistics",
                -style => "background-color:" . $options{tableheadercolor}
            },
            (
                  $options{namepos} =~ /^(left|both)$/i
                ? $cgi->th( {}, $rowheader )
                : ''
              )
              . $row
              . (
                  $options{namepos} =~ /^(right|both)$/i
                ? $cgi->th( {}, $rowheader )
                : ''
              )
        );
    }

    return $text;
}

sub _renderStatisticsCol {
    my ($statisticsref) = @_;
    my $text            = "";
    my $cgi             = Foswiki::Func::getCgiQuery();

    my @statcoltitles =
      split( /\|/, _getStatOption( 'stattitle', 'statcoltitle' ) );
    foreach my $statcol ( split /\|/,
        _getStatOption( 'statformat', 'statcolformat' ) )
    {
        my $statcoltitle = shift(@statcoltitles);
        $statcoltitle = _getStatOption( 'stattitle', 'statcoltitle' )
          unless defined $statcoltitle;
        ( $statcol, $statcoltitle ) =
          _substStatisticsVars( $statcol, $statcoltitle, $statisticsref );
        $text .= $cgi->td(
            {
                -class => "hlpStatsCell",
                -style => "background-color:" . $options{tableheadercolor},
                -title => $statcoltitle,
            },
            $statcol
        );
    }
    return $text;
}

sub _renderNav {
    my ($nextp) = @_;
    my $nav = "";

    my $cgi        = &Foswiki::Func::getCgiQuery();
    my $newcgi     = new CGI($cgi);
    my $newhalfcgi = new CGI($cgi);

    my $days =
      ( defined $options{'navdays'} ) ? $options{'navdays'} : $options{'days'};

    my $qphlppage = $cgi->param( 'hlppage' . $hlid );
    $qphlppage = "0" unless defined $qphlppage;
    $qphlppage =~ m/^([\+\-]?[\d\.]+)$/;
    my $hlppage = $1;
    $hlppage = 0 unless defined $hlppage;

    $hlppage += $nextp;
    my $halfpage = 0;
    $halfpage = $hlppage - 0.5 if $nextp == 1;
    $halfpage = $hlppage + 0.5 if $nextp == -1;

    if ( ( $nextp == 0 ) || ( $hlppage == 0 ) ) {
        $newcgi->delete( 'hlppage' . $hlid );
    }
    else {
        $newcgi->param( -name => 'hlppage' . $hlid, -value => $hlppage );
    }
    if ( ( $nextp == 0 ) || ( $halfpage == 0 ) ) {
        $newhalfcgi->delete( 'hlppage' . $hlid );
    }
    else {
        $newhalfcgi->param( -name => 'hlppage' . $hlid, -value => $halfpage );
    }

    $newcgi->delete('contenttype');
    $newhalfcgi->delete('contenttype');

    my $href = $newcgi->self_url();
    $href =~ s/\#.*$//;
    $href .= "#hlpid$hlid";

    my $halfhref = $newhalfcgi->self_url();
    $halfhref =~ s/\#.$//;
    $halfhref .= "#hlpid$hlid";

    my $title = $options{'navhometitle'};
    my $d = int( $days * ( $hlppage - $nextp ) );
    if ( $d == 0 ) {
        $d = '';
    }
    else {
        $d = '+' . $d if ( $d > 0 );
    }

    $title = $options{'navnexttitle'} if $nextp == 1;
    $title = $options{'navprevtitle'} if $nextp == -1;
    $title =~ s/%n/$days/g;
    $title =~ s/%d/$d/eg;

    my $halftitle = "";
    $halftitle = $options{'navnexthalftitle'} if $nextp == 1;
    $halftitle = $options{'navprevhalftitle'} if $nextp == -1;
    my $halfdays = int( $days / 2 );
    $halftitle =~ s/%n/$halfdays/g;
    $halftitle =~ s/%d/$d/eg;

    my $text = $options{'navhome'};
    $text = $options{'navnext'} if $nextp == 1;
    $text = $options{'navprev'} if $nextp == -1;
    $text =~ s/%n/$days/g;
    $text =~ s/%d/$d/eg;

    my $halftext = "";
    $halftext = $options{'navnexthalf'} if $nextp == 1;
    $halftext = $options{'navprevhalf'} if $nextp == -1;

    my $class = 'hlpNavHome';
    $class = 'hlpNavNext' if $nextp == 1;
    $class = 'hlpNavPrev' if $nextp == -1;

    my $halfClass = $nextp == 1 ? 'hlpNavHalfNext' : 'hlpNavHalfPrev';

    $nav .= $cgi->a(
        { -class => $halfClass, -href => $halfhref, -title => $halftitle },
        $halftext )
      if ( $nextp == 1 ) && $halftext;

    $nav .=
      $cgi->a( { -class => $class, -href => $href, -title => $title }, $text )
      if $text;

    $nav .= $cgi->a(
        { -class => $halfClass, -href => $halfhref, -title => $halftitle },
        $halftext )
      if ( $nextp == -1 ) && $halftext;

    return $nav;
}

sub _renderOptions {
    my $text    = $options{optionsformat};
    my $navdays = $options{navdays};
    $navdays = $options{days} unless defined $navdays;

    my ( $dd, $mm, $yy ) = getStartDate();
    my $week = Week_of_Year( $yy, $mm, $dd );
    my $wiy = Weeks_in_Year($yy);

    while ( $text =~ /\%(STARTDATE|WEEK|MONTH|YEAR)OFFS(\(([^\)]*)\))?/ ) {
        my $what = $1;
        my ( $a, $b, $s ) = _getOptionRange( $3, '-3:+3' );
        my @vals = ('');
        for ( my $offs = $a ; $offs != $b + $s ; $offs += $s ) {
            push @vals, ( $offs >= 0 ? '+' : '' ) . $offs;
        }
        $text =~
s/\%\Q$what\EOFFS(\([^\)]*\))?/CGI::popup_menu(-class=>"foswikiSelect", -title=>"\L$what\E offset",-name=>"hlp_\L$what\E_$hlid",-values=>\@vals, -default=>$options{lc($what)})/e;
    }
    while ( $text =~ /\%(WEEK|MONTH|YEAR)SEL(\(([^\)]*)\))?/ ) {
        my ( $what, $range ) = ( $1, $3 );
        my $default = "";
        $default = ( $yy - 3 ) . ':' . ( $yy + 3 ) if $what eq 'YEAR';
        $default = '1:12'                          if $what eq 'MONTH';
        $default = "1:$wiy"                        if $what eq 'WEEK';
        my ( $a, $b, $s ) = _getOptionRange( $range, $default );

        my @vals = ('');
        for ( my $offs = $a ; $offs != $b + $s ; $offs += $s ) {
            push @vals, $offs;
        }

        $text =~
s/\%\Q$what\ESEL(\([^\)]*\))?/CGI::popup_menu(-class=>"foswikiSelect", -title=>"\L$what\E",-name=>"hlp_\L$what\E_$hlid",-values=>\@vals, -default=>$options{lc($what)})/e;
    }
    while ( $text =~ /\%(STARTDATE|WEEK|MONTH|YEAR)(\(([^\)]*)\))?/ ) {
        my ( $what, $default ) = ( $1, $3 );
        $default = $options{ lc($what) } unless defined $default;
        $text =~
s/\%\Q$what\E(\([^\)]*\))?/CGI::textfield(-class=>"foswikiTextField", -title=>"\L$what\E",-name=>"hlp_\L$what\E_$hlid",-default=>$default)/e;
    }

    $text =~
s/%BUTTON(\(([^\)]*)\))?/CGI::submit(-class=>'foswikiSubmit', -name=>'hlp_change_'.$hlid,-value=>(defined $2?$2:'Change'))/eg;

    $text =
        CGI::start_form( -action => "#hlpid$hlid", -method => 'get' ) 
      . $text
      . CGI::end_form();
    return $text;
}

sub _getOptionRange {
    my ( $range, $default ) = @_;
    $range = $default if !defined $range;
    my ( $a, $b, $s ) = split( /:/, $range );
    $s = 1  unless defined $s;
    $b = $a unless defined $b;

    # avoid endless loops:
    $s = 1 if ( abs( $a - $b ) % abs($s) ) != 0;

    # change sign of steps:
    $s = $a > $b ? -abs($s) : abs($s);

    # avoid large ranges:
    $b = $a + ( 100 * $s ) if ( abs( $a - $b ) / abs($s) ) > 100;

    return ( $a, $b, $s );
}

sub _renderText {
    my ( $text, $web ) = @_;
    my $ret = $text;
    if ( defined $rendererCache{$web} && defined $rendererCache{$web}{$text} ) {
        $ret = $rendererCache{$web}{$text};
    }
    else {
        $ret = Foswiki::Func::renderText( $text, $web );
        $rendererCache{$web}{$text} = $ret;
    }
    return $ret;
}

1;
__END__

Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
Copyright (C) 2005-2009 Daniel Rohde
Copyright (C) 2008-2010 Foswiki Contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at 
http://www.gnu.org/copyleft/gpl.html
