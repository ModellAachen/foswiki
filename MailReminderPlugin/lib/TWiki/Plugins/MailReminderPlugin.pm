#
# Copyright (C) 2001 Andrea Sterbini, a.sterbini@flashnet.it
# Christian Schultze: debugging, relative month/year, highlight today
# Akim Demaille <akim@freefriends.org>: handle date intervals.
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
# http://www.gnu.ai.mit.edu/copyleft/gpl.html
#
# =========================
#
# This is a plugin for showing a Month calendar with events.
#
# =========================
package TWiki::Plugins::MailReminderPlugin;

# use strict;

# =========================
use vars
  qw( $web $topic $user $installWeb $VERSION $RELEASE $Name_g $rem_g $email_g
  $libsLoaded $libsError $defaultsInitialized $file_path %defaults );

$VERSION = '$Rev$';

$libsLoaded          = 0;
$libsError           = 0;
$defaultsInitialized = 0;
%defaults            = ();

# =========================
sub initPlugin {

    use Mysql;
    use DBI;

    ( $topic, $web, $user, $installWeb ) = @_;

    $defaultsInitialized = 0;

    # return true if initialization OK

    $file_path = &TWiki::Func::getDataDir();
    $file_path =~ s/\/[^\/]*$//;
    $file_path = $file_path . "/lib/TWiki/Plugins/MailReminderPlugin";

    open( CONFIG, "$file_path/calender_config_file" )
      ;    # open configuration file.
    while (<CONFIG>) {
        chomp;
        s/#.*//;
        s/^\s+//;
        s/\s+$//;
        next unless length;
        my ( $var, $value ) = split( /\s*=\s*/, $_, 2 );
        $$var = $value;    # get configuration variables.
    }

    close(CONFIG);

    eval {
        $dbh = Mysql->connect( $host, $database, $user, $passwd )
          ;                # connect to database.
    };
    return 0 if $@;

    return 1;
}

# =========================
sub initDefaults {
    my $webColor = &TWiki::Func::getPreferencesValue( "WEBBGCOLOR", $web )
      || 'wheat';

    # reasonable defaults to produce a small calendar
    %defaults = (

        # normal HTML::CalendarMonthSimple options
        border                    => 1,
        width                     => 0,
        showdatenumbers           => 0,
        showweekdayheaders        => 0,
        weekdayheadersbig         => undef,         # the default is ok
        cellalignment             => 'center',
        vcellalignment            => 'center',
        header                    => undef,         # the default is ok
        nowrap                    => undef,         # the default is ok
        sharpborders              => 1,
        cellheight                => undef,         # the default is ok
        cellclass                 => undef,         # the default is ok
        weekdaycellclass          => undef,         # the default is ok
        weekendcellclass          => undef,         # the default is ok
        todaycellclass            => undef,         # the default is ok
        headerclass               => undef,         # the default is ok
                                                    # colors
        bgcolor                   => 'white',
        weekdaycolor              => undef,         # the default is ok
        weekendcolor              => 'lightgrey',
        todaycolor                => $webColor,
        bordercolor               => 'black',
        weekdaybordercolor        => undef,         # the default is ok
        weekendbordercolor        => undef,         # the default is ok
        todaybordercolor          => undef,         # the default is ok
        contentcolor              => undef,         # the default is ok
        weekdaycontentcolor       => undef,         # the default is ok
        weekendcontentcolor       => undef,         # the default is ok
        todaycontentcolor         => undef,         # the default is ok
        headercolor               => $webColor,
        headercontentcolor        => undef,         # the default is ok
        weekdayheadercolor        => undef,         # the default is ok
        weekdayheadercontentcolor => undef,         # the default is ok
        weekendheadercolor        => undef,         # the default is ok
        weekendheadercontentcolor => undef,         # the default is ok
        weekstartsonmonday        => '0',

        # other options not belonging to HTML::CalendarMonthSimple
        daynames =>
          undef
        ,   # order is: Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday
        topic => $topic,
        web   => $web,
        format =>
"<a href=\"%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/\$web/\$topic\"><font size=\"+2\">"
          . "\$old</font><img alt=\"\$description\" src=\"%PUBURLPATH%/$installWeb/MailReminderPlugin/exclam.gif\" border=\"0\" /></a>"
    );

    # now get defaults from CalendarPlugin topic
    my $v;
    foreach $option ( keys %defaults ) {

        # read defaults from CalendarPlugin topic
        $v = &TWiki::Func::getPreferencesValue("MAILREMINDERPLUGIN_\U$option\E")
          || undef;
        $defaults{$option} = $v if defined($v);
    }
    $defaultsInitialized = 1;
}

# =========================
sub commonTagsHandler {
    $_[0] =~
s/%MAILREMINDER_PLUGIN{(.*?)}%/&handleCalendar( $1, \$_[0], $_[1], $_[2] )/geo;
    $_[0] =~
s/%MAILREMINDER_PLUGIN%/&handleCalendar(        "", \$_[0], $_[1], $_[2] )/geo;
}

# =========================
sub readTopicText {
    my ( $theWeb, $theTopic ) = @_;
    my $text = '';
    if ( $TWiki::Plugins::VERSION >= 1.010 ) {
        $text = &TWiki::Func::readTopicText( $theWeb, $theTopic, '', 1 );
    }
    else {
        $text = &TWiki::Func::readTopic( $theWeb, $theTopic );
    }

    # return raw topic text, including meta data
    return $text;
}

# =========================
sub expandIncludedEvents {
    my ( $theAttributes, $theWeb, $theTopic, @theProcessedTopics ) = @_;

    my $webTopic = &TWiki::Func::extractNameValuePair($theAttributes);
    if ( $webTopic =~ m|^([^.]+)[\.\/](.*)$| ) {
        $theWeb   = $1;
        $theTopic = $2;
    }
    else {
        $theTopic = $webTopic;
    }

    # prevent recursive loop
    if (   (@theProcessedTopics)
        && ( grep { /^$theWeb.$theTopic$/ } @theProcessedTopics ) )
    {

        # file already included
        return "";
    }
    else {

        # remember for next time
        push( @theProcessedTopics, "$theWeb.$theTopic" );
    }

    my $text = &readTopicText( $theWeb, $theTopic );
    $text =~ s/.*?%STARTINCLUDE%//s;
    $text =~ s/%STOPINCLUDE%.*//s;

    # recursively expand includes
    $text =~
s/%INCLUDE{(.*?)}%/&expandIncludedEvents( $1, $theWeb, $theTopic, @theProcessedTopics )/geo;
    return $text;
}

# =========================
sub fetchDays {
    my ( $pattern, $refBullets ) = @_;

    $pattern = "^\\s*\\*\\s+$pattern(\\s+X\\s+{(.+)})?\\s+-\\s+(.*)\$";
    my @res = map {
        join '|',
          ( map { $_ || "" } m/$pattern/ )
      }
      grep { m/$pattern/ } @$refBullets;

    # Remove the bullets we handled, so that when several patterns
    # match a line, only the first pattern is really honored.
    @{$refBullets} = grep { !m/$pattern/ } @{$refBullets};

    return @res;
}

# =========================
sub emptyxmap {
    use Date::Calc qw( Days_in_Month );
    ( $y, $m ) = @_;
    for $d ( 1 .. Days_in_Month( $y, $m ) ) {
        $ret[$d] = 1;
    }
    return @ret;
}

# =========================
sub fetchxmap {
    use Date::Calc qw( Add_Delta_Days );
    ( $xlist, $y, $m ) = @_;
    @ret = &emptyxmap( $y, $m );
    @xcepts = split ",", $xlist;
    for $xc (@xcepts) {
        if ( @dparts = $xc =~ m/$full_date_rx\s*-\s*$full_date_rx/ ) {
            ( $d1, $m1, $y1, $d2, $m2, $y2 ) = @dparts;
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
                    ( $y1, $m1, $d1 ) = Add_Delta_Days( $y1, $m1, $d1, 1 );
                } until ( $m1 > $m || ( $m1 == $m2 && $d1 > $d2 ) );
            }
        }
        elsif ( @dparts = $xc =~ m/$full_date_rx/ ) {
            ( $d1, $m1, $y1 ) = @dparts;
            $m1 = $months{$m1};
            if ( $m1 == $m && $y1 == $y ) {
                $ret[$d1] = 0;
            }
        }
    }
    &TWiki::Func::writeDebug( $ret{06} );
    return @ret;
}

# =========================
sub handleCalendar {
    my ( $attributes, $refText, $theTopic, $theWeb ) = @_;

    use Date::Calc
      qw( Date_to_Days Days_in_Month Day_of_Week Nth_Weekday_of_Month_Year Add_Delta_Days Today_and_Now Add_Delta_YMDHMS Today);

    # lazy load of needed libraries
    if ($libsError) { return ""; }
    if ( !$libsLoaded ) {
        eval 'require HTML::CalendarMonthSimple';
        if ( defined($HTML::CalendarMonthSimple::VERSION) ) {
            $libsLoaded = 1;
        }
        else {
            $libsError = 1;
            return "hello";
        }
    }
    initDefaults() unless ($defaultsInitialized);

    # read options from the %CALENDAR% tag
    my %options = %defaults;
    my $v;
    my $orgtopic = $options{topic};
    my $orgweb   = $options{web};
    foreach $option ( keys %options ) {
        $v = &TWiki::Func::extractNameValuePair( $attributes, $option )
          || undef;
        $options{$option} = $v if defined($v);
    }

    # read fixed months/years
    my $m = scalar &TWiki::Func::extractNameValuePair( $attributes, "month" );
    my $y = scalar &TWiki::Func::extractNameValuePair( $attributes, "year" );

    # read and set the desired language
    my $lang = scalar &TWiki::Func::extractNameValuePair( $attributes, "lang" );
    Date::Calc::Language( Date::Calc::Decode_Language($lang) ) if $lang;

    # get GMT offset
    my (
        $currentYear, $currentMonth,  $currentDay,
        $currentHour, $currentMinute, $currentSecond
    ) = Today_and_Now(1);
    my $gmtoff =
      scalar &TWiki::Func::extractNameValuePair( $attributes, "gmtoffset" );
    if ($gmtoff) {
        $gmtoff += 0;
        (
            $currentYear, $currentMonth,  $currentDay,
            $currentHour, $currentMinute, $currentSecond
          )
          = Add_Delta_YMDHMS( $currentYear, $currentMonth, $currentDay,
            $currentHour, $currentMinute, $currentSecond, 0, 0, 0, $gmtoff, 0,
            0 );
    }

    # handle relative dates, too  #cs#
    $y = 0 if $y eq "";    # to avoid warnings in +=
    $y += $currentYear if $y =~ /^[-+]|^0?$/;    # must come before $m !
    if ( $m =~ /^[-+]|^0?$/ ) {
        $m = 0 if $m eq "";                      # to avoid warnings in +=
        $m += $currentMonth;
        ( $m += 12, --$y ) while $m <= 0;
        ( $m -= 12, ++$y ) while $m > 12;
    }

    my $cal = new HTML::CalendarMonthSimple(
        month       => $m,
        year        => $y,
        today_year  => $currentYear,
        today_month => $currentMonth,
        today_date  => $currentDay
    );

    # set the day names in the desired language
    if ($lang) {
        $cal->saturday( Date::Calc::Day_of_Week_to_Text(6) );
        $cal->sunday( Date::Calc::Day_of_Week_to_Text(7) );
        $cal->weekdays( map { Date::Calc::Day_of_Week_to_Text $_ } ( 1 .. 5 ) );
    }

    my $p = "";
    while ( ( $k, $v ) = each %options ) {
        $p = "HTML::CalendarMonthSimple::$k";
        $cal->$k($v) if defined(&$p);
    }

    # header color
    my $webColor =
      &TWiki::Func::getPreferencesValue( "WEBBGCOLOR", $options{web} )
      || 'wheat';

    # Highlight today
    $options{todaycolor}  = $webColor;
    $options{headercolor} = $webColor;

    # set the initial day values if normal date numbers are not shown
    if ( $cal->showdatenumbers == 0 ) {
        for ( $i = 1 ; $i < 33 ; $i++ ) {
            $cal->setcontent( $i, "$i" );
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
    my @days = ();
    my ( $descr, $d, $dd, $mm, $yy, $text ) = ( '', '', '', '', '', '' );
    our %months = (
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
    our %wdays =
      ( Sun => 7, Mon => 1, Tue => 2, Wed => 3, Thu => 4, Fri => 5, Sat => 6 );
    our $days_rx      = '[0-9]?[0-9]';
    our $months_rx    = join( '|', keys %months );
    our $wdays_rx     = join( '|', keys %wdays );
    our $years_rx     = '[12][0-9][0-9][0-9]';
    our $date_rx      = "($days_rx)\\s+($months_rx)";
    our $monthly_rx   = "([1-6])\\s+($wdays_rx)";
    our $full_date_rx = "$date_rx\\s+($years_rx)";
    our $weekly_rx    = "E\\s+($wdays_rx)";
    our $periodic_rx  = "E([0-9]+)\\s+$full_date_rx";
    our $numdaymon_rx = "([0-9L])\\s+($wdays_rx)\\s+($months_rx)";
    $text = getTopicText( %options, $theTopic, $theWeb, $refText );

    # recursively expand includes
    # (don't rely on TWiki::Func::expandCommonVariables to avoid deep recursion)
    $text =~
s/%INCLUDE{(.*?)}%/&expandIncludedEvents( $1, $options{web}, $options{topic}, () )/geo;

    # keep only bullet lines

    #*****************************************

    my @bullets   = grep { /^\s*\*/ } split( /[\n\r]+/, $text );
    my @info      = grep { /^\s*\+/ } split( /[\n\r]+/, $text );
    my @del_event = grep { /^\s*\-/ } split( /[\n\r]+/, $text );

    foreach $a (@info) {
        $a =~ s/^\s*\+\s*//;
        $a =~ s/\s+$//;
        my ( $var, $value ) = split( /\s*=\s*/, $a, 2 );
        $$var = $value;
    }
    $Name_g  = $Name;
    $email_g = $email;
    $rem_g   = $reminder;

    foreach $a (@del_event) {
        delete_entry_from_database($a);
    }

    #*********************************
    # bail out early if no events
    unless (@bullets) {
        return $cal->as_HTML;
    }

    # collect all date intervals with year
    @days = fetchDays( "$full_date_rx\\s+-\\s+$full_date_rx", \@bullets );
    foreach $d (@days) {
        my ( $dd1, $mm1, $yy1, $dd2, $mm2, $yy2, $xs, $xcstr, $descr ) =
          split( /\|/, $d );

        if ( length($xcstr) > 9 ) {
            @xmap = &fetchxmap( $xcstr, $y, $m );
        }
        else {
            @xmap = &emptyxmap( $y, $m );
        }
        my $date1 = Date_to_Days( $yy1, $months{$mm1}, $dd1 );
        my $date2 = Date_to_Days( $yy2, $months{$mm2}, $dd2 );

        for my $d ( 1 .. Days_in_Month( $y, $m ) ) {
            my $date = Date_to_Days( $y, $m, $d );
            if ( $date1 <= $date && $date <= $date2 ) {
                if ( $xmap[$d] ) {
                    &highlightDay( $cal, $d, $descr, %options );
                }
            }
        }
    }

    # then collect all intervals without year
    @days = fetchDays( "$date_rx\\s+-\\s+$date_rx", \@bullets );

    foreach $d (@days) {
        my ( $dd1, $mm1, $dd2, $mm2, $xs, $xcstr, $descr ) = split( /\|/, $d );
        if ( length($xcstr) > 9 ) {
            @xmap = &fetchxmap( $xcstr, $y, $m );
        }
        else {
            @xmap = &emptyxmap( $y, $m );
        }
        my $date1 = Date_to_Days( $y, $months{$mm1}, $dd1 );
        my $date2 = Date_to_Days( $y, $months{$mm2}, $dd2 );
        for my $d ( 1 .. Days_in_Month( $y, $m ) ) {
            my $date = Date_to_Days( $y, $m, $d );
            if ( $date1 <= $date && $date <= $date2 && $xmap[$d] ) {
                &highlightDay( $cal, $d, $descr, %options );
            }
        }
    }

    # first collect all dates with year
    @days = fetchDays( "$full_date_rx", \@bullets );

    foreach $d (@days) {
        ( $dd, $mm, $yy, $xs, $xcstr, $descr ) = split( /\|/, $d );

        #*****************************************

        handledatabase( $yy, $months{$mm}, $dd, $descr );

        #*********************************
        if ( $yy == $y && $months{$mm} == $m ) {

            &highlightDay( $cal, $dd, $descr, %options );
        }
    }

    # then collect all dates without year
    @days = fetchDays( "$date_rx", \@bullets );
    foreach $d (@days) {
        ( $dd, $mm, $xs, $xcstr, $descr ) = split( /\|/, $d );

        #*****************************************

        handledatabase( $yy, $months{$mm}, $dd, $descr );

        #*****************************************
        if ( length($xcstr) > 9 ) {
            @xmap = &fetchxmap( $xcstr, $y, $m );
        }
        else {
            @xmap = &emptyxmap( $y, $m );
        }
        if ( $months{$mm} == $m && $xmap[$dd] ) {
            &highlightDay( $cal, $dd, $descr, %options );
        }
    }

    # collect monthly repeaters
    @days = fetchDays( "$monthly_rx", \@bullets );
    foreach $d (@days) {
        ( $nn, $dd, $xs, $xcstr, $descr ) = split( /\|/, $d );
        if ( length($xcstr) > 9 ) {
            @xmap = &fetchxmap( $xcstr, $y, $m );
        }
        else {
            @xmap = &emptyxmap( $y, $m );
        }
        $hd = Nth_Weekday_of_Month_Year( $y, $m, $wdays{$dd}, $nn );
        if ( $hd <= Days_in_Month( $y, $m ) && $xmap[$hd] ) {
            &highlightDay( $cal, $hd, $descr, %options );
        }
    }

    # collect weekly repeaters
    @days = fetchDays( "$weekly_rx", \@bullets );
    foreach $d (@days) {
        ( $dd, $xs, $xcstr, $descr ) = split( /\|/, $d );
        if ( length($xcstr) > 9 ) {
            @xmap = &fetchxmap( $xcstr, $y, $m );
        }
        else {
            @xmap = &emptyxmap( $y, $m );
        }
        $hd = Nth_Weekday_of_Month_Year( $y, $m, $wdays{$dd}, 1 );
        do {
            if ( $xmap[$hd] ) {
                &highlightDay( $cal, $hd, $descr, %options );
            }
            ( $ny, $nm, $hd ) = Add_Delta_Days( $y, $m, $hd, 7 );
        } while ( $ny == $y && $nm == $m );
    }

    # collect num-day-mon repeaters
    @days = fetchDays( "$numdaymon_rx", \@bullets );
    foreach $d (@days) {
        ( $dd, $dy, $mn, $xs, $xcstr, $descr ) = split( /\|/, $d );
        $mn = $months{$mn};

        if ( length($xcstr) > 9 ) {
            @xmap = &fetchxmap( $xcstr, $y, $m );
        }
        else {
            @xmap = &emptyxmap( $y, $m );
        }
        if ( $mn == $m ) {
            if ( $dd == "L" ) {
                $dd = 6;
                do {
                    $dd--;
                    $hd = Nth_Weekday_of_Month_Year( $y, $m, $wdays{$dy}, $dd );
                } until ($hd);
            }
            else {
                $hd = Nth_Weekday_of_Month_Year( $y, $m, $wdays{$dy}, $dd );
            }
            if ( $xmap[$hd] ) {
                &highlightDay( $cal, $hd, $descr, %options );
            }
        }
    }

    # collect periodic repeaters
    @days = fetchDays( "$periodic_rx", \@bullets );

    foreach $d (@days) {
        ( $p, $dd, $mm, $yy, $xs, $xcstr, $descr ) = split( /\|/, $d );
        if ( length($xcstr) > 9 ) {
            @xmap = &fetchxmap( $xcstr, $y, $m );
        }
        else {
            @xmap = &emptyxmap( $y, $m );
        }
        $mm = $months{$mm};
        if ( ( $mm <= $m && $yy == $y ) || ( $yy < $y ) ) {
            until ( $yy == $y && $mm == $m ) {
                ( $yy, $mm, $dd ) = Add_Delta_Days( $yy, $mm, $dd, $p );
            }
            do {
                if ( $xmap[$dd] ) {
                    &highlightDay( $cal, $dd, $descr, %options );
                }
                ( $yy, $mm, $dd ) = Add_Delta_Days( $yy, $mm, $dd, $p );
            } while ( $yy == $y && $mm == $m );
        }
    }

    # collect date monthly repeaters
    @days = fetchDays( "($days_rx)", \@bullets );
    foreach $d (@days) {
        ( $dd, $xs, $xcstr, $descr ) = split( /\|/, $d );
        if ( length($xcstr) > 9 ) {
            @xmap = &fetchxmap( $xcstr, $y, $m );
        }
        else {
            @xmap = &emptyxmap( $y, $m );
        }
        if ( $dd > 0 && $dd <= Days_in_Month( $y, $m ) && $xmap[$dd] ) {
            &highlightDay( $cal, $dd, $descr, %options );
        }
    }

    return $cal->as_HTML;
}

sub getTopicText {
    my ( %options, $theTopic, $theWeb, $refText ) = @_;
    my $topics = $options{topic};

    #   return "   * 1 Mar 2002 - foo ". $topics."\n";

# I've disabled this functionality as I was not clear what I was supposed to
# do with it. Check the src code of the previous version if it does not work
# for you.
#   if( $topics == $theTopic) {
#       # use current text so that preview can show unsaved events
#       my $tmpText = $$refText; # dereference topic text
#       $text = $tmpText;        # create a copy of topic text since $text will change
#       return $text;
#    }
    return getMultipleTopicText($topics);

    # e.g. return "   * 1 Mar 2002 - FOO\n";
}

sub getMultipleTopicText {
    my ($topics) = @_;
    my @topics = split /, */, $topics;
    my $ans = "";
    foreach my $topicpair (@topics) {

        #      $ans .= "   * 1 Mar 2002 - topicpair=$topicpair\n";
        if ( $topicpair =~ m/([^\.]+)\.([^\.]+)/ ) {
            ( $web, $topic ) = ( $1, $2 );
        }
        else {
            $web   = "";
            $topic = $topicpair;
        }

#      $ans .= "   * 3 Mar 2002 - FOO>bar $topics";#<nop>$web.<nop>$topicpair\n";
#      $ans .= "   * 1 Mar 2002 - web=$web topic=$topic\n";
        $ans .= readTopicText( $web, $topic );
    }
    return $ans;
}

sub highlightDay {
    my ( $c, $day, $description, %options ) = @_;
    my $old    = $c->getcontent($day);
    my $format = $options{format};
    $format =~ s/\$description/$description/g;
    $format =~ s/\$web/$options{web}/g;
    $format =~ s/\$topic/$options{topic}/g;
    $format =~ s/\$day/$day/g;
    $format =~ s/\$old/$old/g;
    $format =~ s/\$installWeb/$installWeb/g;
    $format =~ s/\$n/\n/g;

    $c->setcontent( $day, $format );
}

sub handledatabase {
    my ( $y, $m, $d, $event_name ) = @_;    # get event atrributes.

    $event_name =~ s/'/''/;

    $r     = $rem_g;
    $event = $event_name;
    $email = $email_g;
    $name  = $Name_g;

    @e_date = ( $y, $m, $d );
    use Date::Calc qw (Add_Delta_Days);
    $rem = $r * -1;
    @r_date = Add_Delta_Days( $y, $m, $d, -3 );

    use Date::Calc qw (Delta_Days);
    ( $day, $month, $year ) = (localtime)[ 3, 4, 5 ];
    $year  = $year + 1900;
    $month = $month + 1;
    @today = ( $year, $month, $day );
    $diff  = Delta_Days( @today, @r_date );

    if ( $diff > 0
      ) # enter event into database only if reminder date is greater than todays date.
    {
        $query = "insert into caltab (NAME ,E_DATE,R_DATE,EVENT,EMAIL_ID) VALUES
(\'" 
          . $name . "\'," . "\'" 
          . $y . "-" 
          . $m . "-" 
          . $d . "\',"
          . "DATE_ADD(\'"
          . $y . "-"
          . $m . "-"
          . $d . "\',"
          . "INTERVAL -"
          . $r
          . " DAY), \'"
          . $event . "\',\'"
          . $email
          . "\')";    # form query.
        $sth = $dbh->query($query);    # enter event into database.
    }
}

sub delete_entry_from_database {
    my $event_var = $_[0];

    my %month = (
        "Jan", 1, "Feb", 2, "Mar", 3, "Apr", 4,  "May", 5,  "Jun", 6,
        "Jul", 7, "Aug", 8, "Sep", 9, "Oct", 10, "Nov", 11, "Dec", 12
    );

    $event_var =~ s/^\s*-//;
    $event_var =~ s/\s*$//;
    my ( $date, $event ) =
      split( /\s*-\s*/, $event_var );    # seperate date & event.
    $date  =~ s/^\s*//;
    $date  =~ s/\s*$//;
    $event =~ s/^\s*//;
    $event =~ s/\s*$//;

    ( $d, $m, $y ) = split( /\s+/, $date );    # parse date.

    if ( $y eq '' )    # if year not specified, make it current year.
    {
        ($year) = (localtime)[5];
        $year = $year + 1900;
        $y    = $year;
    }

    $mn = $month{$m};    # get number of the month.

    $query =
        "delete from caltab where name like \'" 
      . $Name_g
      . "\' and email_id like \'"
      . $email_g
      . "\' and e_date = \'"
      . $y . "-"
      . $mn . "-"
      . $d
      . "\' and event like \'"
      . $event . "\'";

    $sth = $dbh->query($query);    # delete the event from the database.
}

#print getMultipleTopicText("Main.Foo, People.Foo");

1;
