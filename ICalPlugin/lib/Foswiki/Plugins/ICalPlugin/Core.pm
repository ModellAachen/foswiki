# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# ICalPlugin is Copyright (C) 2011-2012 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::ICalPlugin::Core;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Sandbox ();
use Foswiki::Form ();
use Foswiki::Plugins ();
use Foswiki::Plugins::ICalPlugin::DataICal ();
use DateTime::Duration ();
use DateTime::Format::ICal ();
use DateTime::Span ();
use Data::ICal::Entry::Event ();
use Error qw(:try);
use Foswiki::Contrib::JSCalendarContrib ();
#use Data::Dumper ();

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR "ICalPlugin::Core - $_[0]\n" if DEBUG;
}

###############################################################################
sub new {
  my ($class, $baseWeb, $baseTopic) = @_;

  my $this = bless({
    baseWeb=>$baseWeb,
    baseTopic=>$baseTopic,
  }, $class);

  Foswiki::Contrib::JSCalendarContrib::addHEAD("foswiki");

  return $this;
}

###############################################################################
sub inlineError {
  my $msg = shift;
  die "wot?" unless defined $msg;
  return '<span class="foswikiAlert">'.$msg.'</span>';
}

###############################################################################
sub FORMATICAL {
  my ($this, $session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("### called FORMATICAL()");

  my $web = $params->{web} || $this->{baseWeb};
  my $topic = $params->{topic} || $this->{baseTopic};
  my $attachment = $params->{attachment} || 'calendar.ics';
  my $text = $params->{_DEFAULT} || $params->{text};
  my $skip = $params->{skip} || 0;
  my $limit = $params->{limit};

  ($web, $topic) = Foswiki::Func::normalizeWebTopicName($web, $topic);

  return inlineError("topic $web.$topic does not exist") 
    unless Foswiki::Func::topicExists($web, $topic);

  my $cal;
  if (defined $text) { 
    $cal = Foswiki::Plugins::ICalPlugin::DataICal->new(data=>$text);
  } else {
    return inlineError("calendar $attachment not found at $web.$topic")
      unless Foswiki::Func::attachmentExists($web, $topic, $attachment);

    my $error;
    try {
      $text = Foswiki::Func::readAttachment($web, $topic, $attachment);
    } catch Foswiki::AccessControlException with {
      $error = shift->{-text};
    };

    return inlineError($error) if defined $error;

    my $data = Foswiki::Func::readAttachment($web, $topic, $attachment);
    $cal = Foswiki::Plugins::ICalPlugin::DataICal->new(data=>$data);
  }

  return '' unless $cal;

  return $cal->as_string if Foswiki::Func::isTrue($params->{raw});

  my ($queryStart, $queryEnd) = getQuerySpan($params);
  writeDebug("querySpan start=$queryStart, end=$queryEnd");

  my @events = ();
  foreach my $entry (@{ $cal->entries() }) {
    next unless $entry->ical_entry_type() eq 'VEVENT';
    my $props = $entry->properties();

    my $recurrence = ($entry->property("rrule")||$entry->property("rdate"));
    if ($recurrence) {
      my @recurrence = unfoldRecurrence($props, $params, $queryStart, $queryEnd);
      #writeDebug("### generated ".scalar(@recurrence)." events from recurrence ".$recurrence->[0]->value);
      push @events, @recurrence;
    } else {
      push @events, generateEvent($props);
    }
  }

  # sort events
  my $sortCrit;
  my $theSort = $params->{sort} || 'off';
  if ($theSort eq 'start' || $theSort eq 'on') {
    $sortCrit = '_startepoch';
  } elsif ($theSort eq 'end') {
    $sortCrit = '_endepoch';
#  } elsif ($theSort eq 'modified') {
#    $sortCrit = '_modifiedepoch';
#  } elsif ($theSort eq 'created') {
#    $sortCrit = '_createdepoch';
  } else {
    $theSort = 'off';
  }
  unless ($theSort eq 'off') {
    @events = sort {($a->{$sortCrit}||0) <=> ($b->{$sortCrit}||0)} @events;
  }

  writeDebug("### generated ".scalar(@events)." events");

  my @result = ();
  my $index = 0;
  my $queryStartEpoch = $queryStart->epoch;
  my $queryEndEpoch = $queryEnd->epoch;
  #print STDERR "queryStartEpoch=$queryStartEpoch, queryEndEpoch=$queryEndEpoch\n";
  foreach my $event (@events) {
    $index++;

#   print STDERR "startepoch=$event->{_startepoch}\n" if defined $event->{_startepoch};
#   print STDERR "endepoch=$event->{_endepoch}\n" if defined $event->{_endepoch};
#
#   if (defined $event->{_startepoch}) {
#     if ($event->{_startepoch} > $queryEndEpoch) {
#       print STDERR "startepoch ".$event->{dtstart}." is > queryEndEpoch ... out\n";
#     } else {
#       print STDERR "startepoch ".$event->{dtstart}."is <= queryEndEpoch\n";
#     }
#   }
#   if (defined $event->{_endepoch}) {
#     if ($event->{_endepoch} < $queryStartEpoch) {
#       print STDERR "endepoch ".($event->{dtend}||'')." is < queryStartEpoch ... out\n";
#     } else {
#       print STDERR "endepochh ".($event->{dtend}||'')."is >= queryStartEpoch\n";
#     }
#   }

    next if (defined $event->{_startepoch} && $event->{_startepoch} > $queryEndEpoch) ||
            (defined $event->{_endepoch} && $event->{_endepoch} < $queryStartEpoch);

    next unless $index > $skip;

    if (defined $limit) {
      last if $index > $skip+$limit;
    }
 
    my $line = formatEvent($event, $params);
    #print STDERR "line=$line\n";

    # add params
    while (my ($key, $val) = each %$params) {
      next if $key =~ /^(_.*|start|end)$/;
      next unless defined $val;
      $line =~ s/\$$key/$val/g;
    }

    # clean up
    $line =~ s/\$index/$index/g;
    $line =~ s/\$(?:location|dtstart|start|dtend|until|end|last-modified|modified|description|attendee|organizer|rrule|rdate|summary)//g;
    $line =~ s/\$[mec]?(seco?n?d?s?|minu?t?e?s?|hour?s?|day|w(eek|day)|dow|mo(?:nt?h?)?|ye(?:ar)?)(\(\)|(?=\W|$))//g;

    push @result, $line;
  }

  return '' unless @result;

  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSeparator = $params->{separator} || '';

  my $result = $theHeader.join($theSeparator, @result).$theFooter;

  $result =~ s/\$n/\n/g;
  $result =~ s/\$perce?nt/\%/g;
  $result =~ s/\$dollar/\$/g;

  return $result;
}

###############################################################################
sub formatEvent {
  my ($event, $params) = @_;

  my $format = $params->{format};
  $format = $params->{eventformat} if defined $params->{eventformat};
  $format = '   * $day $mon $year - $location - $summary' unless defined $format;
  
  if (defined $params->{rangeformat} && defined $event->{end} && $event->{start} != $event->{end}) {
    $format = $params->{rangeformat};
    writeDebug("found a range: start=$event->{start} - end=$event->{end}: $event->{summary}");
  }

  #writeDebug("### called formatEvent($format)");

  while (my ($key, $val) = each %$event) {
    next unless defined $val && defined $val;
    next if $key =~ /^_/;
    $format =~ s/\$$key/$val/g;

    #writeDebug("$key=$val");
    if ($key eq 'created') {
      $format = formatTime($val, $format, "c");
    } elsif ($key eq 'start') {
      $format = formatTime($val, $format);
    } elsif ($key eq 'dtend') {
      $format = formatTime($val, $format, "e");
    } elsif ($key eq 'last-modified') {
      $format = formatTime($val, $format, "m");
    }
  }

  #writeDebug("### result = $format");

  return $format;
}

###############################################################################
sub parseTime {
  my $time = shift;

  if (ref($time) eq 'DateTime') {
    return $time->epoch();
  }

  my $epoch;

  $time =~ s/^\s*//;
  $time =~ s/\s*$//;

  # deal with 20111224
  if ($time =~ /^(\d\d\d\d)(\d\d)(\d\d)$/) {
    $time = "$1-$2-$3";
  } 
  
  # deal with 20111224T1200000
  elsif ($time =~ /^(\d\d\d\d)(\d\d)(\d\d)T(\d\d)(\d\d)(\d\d)(Z.*?)$/) {
    $time = "$1-$2-$3T$4:$5:$6$7";
  }

  my $result = Foswiki::Time::parseTime($time);
  
  unless (defined $result) {
    Foswiki::Func::writeWarning("ICalPlugin::Core - cant parse time '$time'");
    $result = 0;
  }

  return $result;
}

###############################################################################
sub formatTime {
  my ($time, $formatString, $prefix, $outputTimeZone) = @_;

  return '' unless defined $formatString;

  my $epochSeconds = parseTime($time);
  $outputTimeZone ||= $Foswiki::cfg{DisplayTimeValues};

  $prefix ||= '';

  my ($sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst);
  if ($outputTimeZone eq 'servertime') {
    ($sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst) = localtime($epochSeconds);
  } else {
    ($sec, $min, $hour, $day, $mon, $year, $wday, $yday) = gmtime($epochSeconds);
  }

  #writeDebug("formatTime($time), year=$year, mon=$mon, day=$day");

  my $value = $formatString;
  $value =~ s/\$${prefix}seco?n?d?s?/sprintf('%.2u',$sec)/gei;
  $value =~ s/\$${prefix}minu?t?e?s?/sprintf('%.2u',$min)/gei;
  $value =~ s/\$${prefix}hour?s?/sprintf('%.2u',$hour)/gei;
  $value =~ s/\$${prefix}day/sprintf('%.2u',$day)/gei;
  $value =~ s/\$${prefix}wday/$Foswiki::Time::WEEKDAY[$wday]/gi;
  $value =~ s/\$${prefix}dow/$wday/gi;
  $value =~ s/\$${prefix}week/Foswiki::Time::_weekNumber($wday, $yday, $year + 1900)/egi;
  $value =~ s/\$${prefix}mont?h?/$Foswiki::Time::ISOMONTH[$mon]/gi;
  $value =~ s/\$${prefix}mo/sprintf('%.2u',$mon+1)/gei;
  $value =~ s/\$${prefix}year?/sprintf('%.4u',$year + 1900)/gei;
  $value =~ s/\$${prefix}ye/sprintf('%.2u',$year%100)/gei;
  $value =~ s/\$${prefix}epoch/$epochSeconds/gi;

  return $value;
}

###############################################################################
sub unfoldRecurrence {
  my ($props, $params, $from, $to) = @_;

  my $start;

  if (defined $props->{dtstart}) {
    $start = DateTime::Format::ICal->parse_datetime($props->{dtstart}[0]->value);
  } else {
    $start = $from;
  }

  my @events = ();
  my $templateEvent = generateEvent($props);

  if ($props->{rrule}) {
    foreach my $rule (@{$props->{rrule}}) {
      my $val = $rule->value;
      #print STDERR "val=$val\n";

      my $recur = DateTime::Format::ICal->parse_recurrence(
        recurrence => $val,
        dtstart => $start
      );

      my $span = DateTime::Span->from_datetimes(
        start => $from,
        end => $to
      );


      my $iter = $recur->iterator(span => $span);
      while (my $dt = $iter->next) {
        my $dtEpochSeconds = $dt->epoch();

        my %dtEvent = %$templateEvent;
        $dtEvent{start} = $dt;
        $dtEvent{dtstart} = $dt;
        delete $dtEvent{dtend};
        delete $dtEvent{end};
        push @events, \%dtEvent;
      }
    }
  }

  if ($props->{rdate}) {
    foreach my $rule (@{$props->{rdate}}) {
      my $val = $rule->value;
      $val = DateTime::Format::ICal->parse_datetime($val);

      my %dtEvent = %$templateEvent;
      $dtEvent{start} = $val;
      $dtEvent{dtstart} = $val;
      delete $dtEvent{dtend};
      delete $dtEvent{end};
      push @events, \%dtEvent;
    }
  }

  return @events;
}

###############################################################################
sub generateEvent {
  my ($props, %override) = @_;

  my %event = ();
  foreach my $key (keys %$props) {
    my $property = $props->{$key}[0];

    my $val = (defined $override{$key}) ? $override{$key} : $property->value;
    $val =~ s/^mailto://i;

    if ($key eq 'description') {
      $val =~ s/</&lt;/g;
      $val =~ s/>/&gt;/g;
      $val =~ s/\n/<br \/>/g;
      $event{$key} = $val;

    } elsif ($key eq 'created') {
      $event{created} = DateTime::Format::ICal->parse_datetime($val);
      #$event{_createdepoch} = $event{created}->epoch();
    } elsif ($key eq 'dtstart') {
      $event{start} = $event{$key} = DateTime::Format::ICal->parse_datetime($val);
      $event{_startepoch} = $event{start}->epoch();
    } elsif ($key eq 'dtend') {
      $event{end} = $event{$key} = DateTime::Format::ICal->parse_datetime($val);
      $event{_endepoch} = $event{end}->epoch();
    } elsif ($key eq 'last-modified') {
      $event{modified} = $event{$key} = DateTime::Format::ICal->parse_datetime($val);
      #$event{_modifiedepoch} = $event{modified}->epoch();
    } else {
      $event{$key} = $val;
    }
  }

  return \%event;
}

###############################################################################
sub getQuerySpan {
  my $params = shift;

  my $theStart = $params->{start};

  my $dtStart = DateTime->from_epoch(epoch => (defined $theStart)?parseTime($theStart):time);

  my $theSpan = $params->{span} || '1 month';
  my $theEnd = $params->{end};

  my $querySpan;
  my $dtEnd;
  if (defined $theEnd) {
    $dtEnd = DateTime->from_epoch(epoch => parseTime($theEnd));
  } else {
    my $years = 0;
    my $months = 0;
    my $weeks = 0;
    my $days = 0;
    my $hours = 0;
    my $minutes = 0;
    my $seconds = 0;
    $years = $1 if $theSpan =~ /(\d+)\s+years(s)?/;
    $months = $1 if $theSpan =~ /(\d+)\s+month(s)?/;
    $weeks = $1 if $theSpan =~ /(\d+)\s+week(s)?/;
    $days = $1 if $theSpan =~ /(\d+)\s+day(s)?/;
    $hours = $1 if $theSpan =~ /(\d+)\s+hour(s)?/;
    $minutes = $1 if $theSpan =~ /(\d+)\s+minute(s)?/;
    $seconds = $1 if $theSpan =~ /(\d+)\s+sec(ond)?(s)?/;
    $dtEnd = $dtStart->clone();
    $dtEnd->add(
      years => $years,
      months => $months,
      weeks => $weeks,
      days => $days,
      hours => $hours,
      minutes => $minutes,
      seconds => $seconds,
    );
  }

  $querySpan = DateTime::Span->from_datetimes(
    start=>$dtStart,
    end=>$dtEnd
  );

  return ($querySpan->start, $querySpan->end);
}

###############################################################################
sub afterSaveHandler {
  my ($this, $text, $topic, $web, $meta) = @_;

  unless ($meta) {
    ($meta) = Foswiki::Func::readTopic($web, $topic);
  }

  writeDebug("called afterSaveHandler");

  my @events = ();
  my $event = $this->getEventFromDataForm($meta);
  push @events, $event if defined $event;

  if (Foswiki::Func::getContext()->{MetaDataPluginEnabled}) {
    push @events, $this->getEventsFromMetaData($meta);
  }

  if (@events) {
    try {
      $this->updateCalendar(\@events);
    } catch Error::Simple with {
      my $error = shift;
      print STDERR "ERROR: can't update calendar - " . $error . "\n";
    }
  } else {
    writeDebug("nothing to update");
  }
}

###############################################################################
sub updateCalendar {
  my ($this, $newEvents, $deleteEvents) = @_;

  writeDebug("called updateCalendar");

  my ($calendarWeb, $calendarTopic, $calendarAttachment) = $this->getCalendarAttachment;
  return unless defined $calendarWeb;

  my %knownUID;

  # add deletable uids as "known" so they are skipped constructing the updated ical file
  if (defined $deleteEvents) {
    foreach my $event (@$deleteEvents) {
      my $uid = $event->property("uid")->[0]->value;
      $knownUID{$uid} = 1;
      #print STDERR "deleting uid=$uid\n";
    }
  }

  if (defined $newEvents) {
    foreach my $event (@$newEvents) {
      my $uid = $event->property("uid")->[0]->value;
      $knownUID{$uid} = 1;
      #print STDERR "uid=$uid is known\n";
    }
  }

  my $newCal = Foswiki::Plugins::ICalPlugin::DataICal->new(
      data => 
"BEGIN:VCALENDAR
PRODID:-//Foswiki///ICalPlugin//$Foswiki::Plugins::ICalPlugin::RELEASE
VERSION:2.0
END:VCALENDAR
"
  );



  if (Foswiki::Func::attachmentExists($calendarWeb, $calendarTopic, $calendarAttachment)) {
    my $data = Foswiki::Func::readAttachment($calendarWeb, $calendarTopic, $calendarAttachment);
    if ($data) {
      $data = Foswiki::Sandbox::untaintUnchecked($data); # SMELL: some libs barf on tainted strings

      my $oldCal = Foswiki::Plugins::ICalPlugin::DataICal->new(data => $data); # SMELL: do we still need this wrapper?

      if (ref($oldCal) eq 'Class::ReturnValue') {
        print STDERR "ERROR:" . $oldCal->error_message . "\n"; # ERROR ... but keep on going
      } else {
        foreach my $entry (@{ $oldCal->entries() }) {
          next unless $entry->ical_entry_type() eq 'VEVENT';
          my $uid = $entry->property("uid")->[0]->value;
          unless ($knownUID{$uid}) {
            $newCal->add_entry($entry);
          }
        }
      }
    }
  }

  if (defined $newEvents) {
    foreach my $event (@$newEvents) {
      $newCal->add_entry($event);
    }
  }

  my $data = $newCal->as_string;
  open(my $fh, '<', \$data) or die $!;

  Foswiki::Func::saveAttachment($calendarWeb, $calendarTopic, $calendarAttachment, {
    filesize => length($data),
    stream => $fh
    #SMELL: attachment attributes are lost when saving again (comments, hide, ...)
  });

  close $fh;

  #print STDERR "cal=".Data::Dumper->Dump([$newCal])."\n";
  return 1; # success
}

###############################################################################
sub getCalendarAttachment {
  my $this = shift;

  unless ($this->{calendarWeb}) {
    my $calendar = Foswiki::Func::getPreferencesValue('ICALPLUGIN_CALENDAR') || $Foswiki::cfg{ICalPlugin}{DefaultCalendar};
    $calendar = Foswiki::Func::expandCommonVariables($calendar) if $calendar =~ /%[A-Z]+{.+?}%/;

    #throw Error::Simple("ICALPLUGIN_CALENDAR not defined") unless $calendar;
    return unless $calendar;
    
    if ($calendar =~ /^($Foswiki::regex{webNameRegex})\.($Foswiki::regex{topicNameRegex})\.(.*?)$/) {
      $this->{calendarWeb} = $1;
      $this->{calendarTopic} = $2;
      $this->{calendarAttachment} = $3;
    } else {
      throw Error::Simple("invalid format of ICALPLUGIN_CALENDAR: $calendar, must be web.topic.attachment");
    }
  }

  writeDebug("using calendar at web=$this->{calendarWeb} topic=$this->{calendarTopic}, attachment=$this->{calendarAttachment}");

  return ($this->{calendarWeb}, $this->{calendarTopic}, $this->{calendarAttachment});
}


###############################################################################
sub getEventFromDataForm {
  my ($this, $meta) = @_;

  #print STDERR "called getEventFromDataForm\n";

  my $topicType = getField($meta, 'TopicType');
  return unless defined $topicType;

  #print STDERR "topicType=$topicType\n";
  return unless $topicType =~ /\bEventTopic\b/;

  my $uid = $meta->getPath();
  $uid =~ s/\//./g;
  my $web = $meta->web;
  my $topic = $meta->topic;

  return $this->createEvent(
    uid => $uid,
    location => Foswiki::Func::getScriptUrl($web, $topic, 'view'),
    summary => getTopicTitle($meta),
    description => getField($meta, "Summary"),
    start => getField($meta, 'StartDate'),
    end => getField($meta, 'EndDate'),
    freq => getField($meta, 'Recurrence') || 'none',
    weekday => getField($meta, 'WeekDay'),
    montday => getField($meta, 'MonthDay'),
    month => getField($meta, 'Month'),
    yearday => getField($meta, 'YearDay'),
    interval => getField($meta, 'Interval'),
    #count => getField($meta, 'RecurrenceCount'), # unusede for now
  );
}

###############################################################################
sub getEventFromMetaData {
  my ($this, $web, $topic, $record) = @_;

  $web =~ s/\//./g;
  my $uid = $web.'.'.$topic.'#'.$record->{name};

  my $event = $this->createEvent(

    uid => $uid,
    location => Foswiki::Func::getScriptUrl($web, $topic, 'view'),
    summary => $record->{TopicTitle} || '',
    description => $record->{Summary} || '',
    start => $record->{StartDate},
    end => $record->{EndDate},
    freq => $record->{Recurrence} || 'none',
    weekday => $record->{WeekDay},
    monthday => $record->{MonthDay},
    month => $record->{Month},
    yearday => $record->{YearDay},
    interval => $record->{Interval},

    # count => $record->{count}, # unused for now
  );
}

###############################################################################
sub getEventsFromMetaData {
  my ($this, $meta) = @_;

  my $web = $meta->web;
  my $topic = $meta->topic;

  my @events = ();

  # SMELL: there's no way to iterate over all known meta data keys
  # so we have to break data encapsulation of Foswiki::Meta
  while (my ($alias, $name) = each %Foswiki::Meta::aliases) {
    $name =~ s/^META://;
   
    # SMELL: there's no way to access the meta data definition record for
    # a given key
    my $metaDataDef = $Foswiki::Meta::VALIDATE{$name};
    next unless $metaDataDef;

    # SMELL: there's a form attribute stored into the record by MetaDataPlugin,
    # that's not standard, yet we need it now to read the TopicType formfield
    my $formWebTopic = $metaDataDef->{form};
    next unless $formWebTopic;

    # now, we've found a meta data definition that has got a DataForm associated with it
    my ($formWeb, $formTopic) = Foswiki::Func::normalizeWebTopicName($web, $formWebTopic);
    next unless Foswiki::Func::topicExists($formWeb, $formTopic);

    # now check the TopicType for "EventTopic"
    my $form = new Foswiki::Form($Foswiki::Plugins::SESSION, $formWeb, $formTopic);

    my $topicTypeField = $form->getField('TopicType');
    next unless $topicTypeField;

    my $topicType = $topicTypeField->{value};
    next unless $topicType || $topicType !~ /\bEventTopic\b/;

    # now we've found an EventTopic, we can extract the metadata for this key
    foreach my $record ($meta->find($name)) {
      push @events, $this->getEventFromMetaData($web, $topic, $record);
    }
  }

  return @events;
}

###############################################################################
sub createEvent {
  my ($this, %params) = @_;

  # create new event entry
  my $vevent = Data::ICal::Entry::Event->new();
  $vevent->add_properties(
    uid => $params{uid},
    summary => $params{summary},
    description => $params{description},
  );

  # datetime properties
  my %event = ();

  if (defined $params{start} && $params{start} ne '') {
    $event{dtstart} = DateTime->from_epoch(epoch => parseTime($params{start}));

    my $icalStart = DateTime::Format::ICal->format_datetime($event{dtstart});
    $icalStart =~ s/T.*//; # strip of time
    $vevent->add_properties('dtstart' => [ $icalStart, { VALUE => 'DATE' } ]);
  }

  if ($params{end}) {
    $event{dtend} = DateTime->from_epoch(epoch => parseTime($params{end}));
    my $icalEnd = DateTime::Format::ICal->format_datetime($event{dtend});
    $icalEnd =~ s/T.*//; # strip of time
    $vevent->add_properties('dtend' => [ $icalEnd, { VALUE => 'DATE' } ]);
  }

  # other datetime properties
  foreach my $prop qw(created dtstamp last-modified) {
    my $val = $params{$prop};
    next unless defined $val;
    $val = DateTime->from_epoch(epoch => parseTime($params{$prop}));
    $vevent->add_properties($prop=>$val);
  }

  # optional unique
  foreach my $prop qw(location organizer priority recurrence-id sequence status transp uid url) {
    my $val = $params{$prop};
    $vevent->add_properties($prop=>$val) if defined $val;
  }

  # optional repeatable
  # - attach
  # - attendee
  # - categories
  # - comment
  # - contact
  # - exdate
  # - exrule
  # - request-status
  # - related-to
  # - resources

  if (defined $params{freq} && $params{freq} ne 'none') {
    $event{freq} = $params{freq};
    $event{interval} = $params{interval} if $params{interval};
    $event{until} = $event{dtend} if defined $event{dtend};
    #$event{count} = $params{count}; # unused for now

    if ($params{freq} eq 'daily') {
      # nothing else
    } elsif ($params{freq} eq 'weekly') {
      $event{byday} = $params{weekday};
    } elsif ($params{freq} eq 'monthly') {
      $event{bymonthday} = $params{monthday};
    } elsif ($params{freq} eq 'yearly') {
      $event{bymonth} = $params{month} if defined $params{month};
      $event{bymonthday} = $params{monthday} if defined $params{monthday};
      $event{byyearday} = $params{yearday} if defined $params{yearday};
    }

    $event{byday} = [split(/\s*,\s*/, $event{byday})] if defined $event{byday};
    $event{bymonth} = [split(/\s*,\s*/, $event{bymonth})] if defined $event{bymonth};
    $event{bymonthday} = [split(/\s*,\s*/, $event{bymonthday})] if defined $event{bymonthday};
    $event{byyearday} = [split(/\s*,\s*/, $event{byyearday})] if defined $event{byyearday};

    my $set;
    my $error;

    try {
      $set = DateTime::Event::ICal->recur(%event); # needs DateTimes
    } catch Error::Simple with {
      $error = shift;
      print STDERR "ERROR: ".$error."\n";
    };

    unless ($error) {
      my @recurr = DateTime::Format::ICal->format_recurrence($set);
      foreach my $recurr (@recurr) {
        #print STDERR "recurr=$recurr\n";
        if ($recurr =~ s/^RRULE://) {
          $vevent->add_properties(rrule => $recurr);
        } elsif ($recurr =~ s/^RDATE://) {
          foreach my $rdate (split(/,/, $recurr)) {
            $vevent->add_properties(rdate => [ $rdate, { VALUE => 'DATE' } ]);
          }
        }
      }
    }
  } 

  writeDebug("generated vevent ".$vevent->as_string());
  return $vevent;
}

###############################################################################
sub getField {
  my ($meta, $name) = @_;

  return unless $meta;

  my $field = $meta->get('FIELD', $name);
  return unless $field;

  return $field->{value};
}

###############################################################################
sub getTopicTitle {
  my ($meta) = @_;

  my $web = $meta->web;
  my $topic = $meta->topic;

  if ($Foswiki::cfg{SecureTopicTitles}) {
    my $wikiName = Foswiki::Func::getWikiName();
    return $topic
      unless Foswiki::Func::checkAccessPermission('VIEW', $wikiName, undef, $topic, $web, $meta);
  }

  # read the formfield value
  my $title = $meta->get('FIELD', 'TopicTitle');
  $title = $title->{value} if $title;

  # read the topic preference
  unless ($title) {
    $title = $meta->get('PREFERENCE', 'TOPICTITLE');
    $title = $title->{value} if $title;
  }

  # read the preference
  unless ($title)  {
    Foswiki::Func::pushTopicContext($web, $topic);
    $title = Foswiki::Func::getPreferencesValue('TOPICTITLE');
    Foswiki::Func::popTopicContext();
  }

  # default to topic name
  $title ||= $topic;

  $title =~ s/\s*$//;
  $title =~ s/^\s*//;

  return $title;
} 

1;
