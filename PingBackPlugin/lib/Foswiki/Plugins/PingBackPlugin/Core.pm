# PingBackPlugin Core
#
# Copyright (C) 2006-2012 Michael Daum http://michaeldaumconsulting.com
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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

use strict;
use warnings;

package Foswiki::Plugins::PingBackPlugin::Core;

# this pacakage has three duties
# - reveive pings
# - send pings
# - manage ping queues

use Foswiki::Func();
use Foswiki::Plugins::PingBackPlugin ();
use Foswiki::Plugins::PingBackPlugin::DB qw(getPingDB);

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR '- PingBackPlugin::Core - '.$_[0]."\n" if DEBUG;
}

###############################################################################
# construct a pingClient
sub getClient {
  require Foswiki::Plugins::PingBackPlugin::Client;
  return Foswiki::Plugins::PingBackPlugin::Client::getClient();
}

###############################################################################
# receive a ping
#
# TODO: record the IP from which this ping was received and compare it
# with the source; for example, a ping spammer from an arbitrary host 
# names some google query to be the source of the ping. the pingbackmanager 
# will happily issue this query and increase some google ranking as a result
sub handlePingbackCall {
  my ($session, $params) = @_;

  writeDebug("called handlePingbackCall");

  # check arguments
  if (@$params != 2) {
    return ('400 Bad Request', -32602, 'Wrong number of arguments');
  }

  my $source = $params->[0]->value;
  my $target = $params->[1]->value;
  my $web = $session->{webName};
  my $topic = $session->{topicName};

  # write log
  writeEvent('ping', "source=$source, target=$target");
  #writeDebug("source=$source");
  #writeDebug("target=$target");

  if (Foswiki::Plugins::PingBackPlugin::isPingBackEnabled) {

    # queue incoming ping
    my $db = getPingDB();
    my $ping = $db->newPing(source=>$source, target=>$target);
    $ping->timeStamp();
    $ping->queue('in');

    writeDebug("done handlePingBackCall");
    return ('200 OK', 0, 'Pingback registered.');
  } else {
    # reject incoming ping
    writeDebug("resource not pingback-enabled");
    writeDebug("done handlePingBackCall");
    return ('200 OK', 33, 'resource not pingback-enabled');
  }
}

##############################################################################
sub writeEvent {
  return unless defined &Foswiki::Func::writeEvent;
  return Foswiki::Func::writeEvent(@_);
}

###############################################################################
# dispatch all sub commands
sub handlePingbackTag {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $action = $params->{action} || $params->{_DEFAULT} || 'ping';
  return handlePing(@_) if $action eq 'ping';
  return handleShow(@_) if $action eq 'show';
  return inlineError("ERROR: unknown action $action");
}

###############################################################################
# send a ping, used by the PingBackClient
sub handlePing {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handlePing");


  my $query = Foswiki::Func::getCgiQuery();
  my $action = $query->param('pingback_action') || '';
  my $source;
  my $target;
  my $format = $params->{format} || 
    '<pre style="overflow:auto">$status: $result</pre>';

  if ($action eq 'ping') { 
    # cgi mode
    $source = $query->param('source');
    $target = $query->param('target');
  } else { 
    # tml mode
    $source = $params->{source};
    $target = $params->{target};
  }

  return '' unless $target;
  $source = Foswiki::Func::getViewUrl($theWeb, $theTopic) unless $source;

  #writeDebug("source=$source");
  #writeDebug("target=$target");

  my ($status, $result) = getClient()->ping($source, $target);

  my $text = expandVariables($format, 
    status=>$status,
    result=>$result,
    target=>$target,
    source=>$source,
  );

  #writeDebug("done handlePing");

  return $text;
}

###############################################################################
# display pings, used in the PingManager
sub handleShow {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("called handleShow");

  my $header = $params->{header} || 
    '<span class="foswikiAlert">$count</span> ping(s) found<p/>'.
    '<table class="foswikiTable" width="100%">';
  my $format = $params->{format} || 
    '<tr><th>$index</th><th>$date</th></tr>'.
    '<tr><td>&nbsp;</td><td>'. '
      <table><tr><td><b>Source</b>:</td><td> $source </td></tr>'.
	'<tr><td><b>Target</b>:</td><td> $target </td></tr>'.
	'<tr><td>&nbsp;</td><td> <noautolink>"$title": $paragraph </noautolink></td></tr>'.
      '</table>'.
    '</tr>';
  my $footer = $params->{footer} || '</table>';
  my $separator = $params->{sep} || $params->{separator} || '$n';
  my $warn = $params->{warn} || 'on';
  my $reverse = $params->{reverse} || 'on';
  my $queue = $params->{queue} || 'in';
  return inlineError('ERROR: unknown queue '.$queue) unless $queue =~ /^(in|out|cur|trash)$/;

  my $result = '';
  my @pings;

  my $db = getPingDB();
  @pings = $db->readQueue($queue);
  @pings = reverse @pings if $reverse eq 'on';

  my $index = 0;
  foreach my $ping (@pings) {
    my $text = '';
    $index++;
    $text .= $separator if $result;
    $text .= $format;
    $text = expandVariables($text,
      date=>$ping->{date},
      source=>$ping->{source},
      target=>$ping->{target},
      extra=>$ping->{extra},
      title=>$ping->{title},
      paragraph=>$ping->{paragraph},
      'index'=>$index,
      queue=>$queue,
    );
    $result .= $text;
  }
  #writeDebug("result=$result");

  $result = $header.$separator.$result if $header;
  $result .= $separator.$footer if $footer;
  $result = expandVariables($result, queue=>$queue, count=>" $index" );

  writeDebug("done handleShow");

  return $result;
}

################################################################################
sub afterSaveHandler {
  my ($text, $topic, $web, $error, $meta) = @_;

  writeDebug("called afterSaveHandler($web.$topic)");

  if ($error) {
    writeDebug("bailing out afterSaveHandler ... save error");
    return;
  }

  if ($web =~ /^_/) {
    writeDebug("bailing out afterSaveHandler ... no pings for template webs");
    return;
  }

  # check if we just enabled/disabled pingback during this save; these values aren't 
  # in the preference cache yet; this SMELLs
  my $found = 0;
  my $isEnabled = 0;
  my $setRegex = Foswiki::Func::getRegularExpression('setRegex');
  my $enablePingbackRegex = qr/^${setRegex}ENABLEPINGBACK\s*=\s*(on|yes|1|off|no|0)$/o;
  foreach my $line (split(/\r?\n/, $text)) {
    if ($line =~ /$enablePingbackRegex/) {
      $found = 1;
      $isEnabled = $1;
      $isEnabled =~ s/off//gi;
      $isEnabled =~ s/no//gi;
      $isEnabled = $found?1:0;
      last;
    }
  } 
  $isEnabled = Foswiki::Plugins::PingBackPlugin::isPingBackEnabled unless $found;
  if ($isEnabled) {
    writeDebug("generating pingbacks for $web.$topic");
  } else {
    writeDebug("bailing out afterSaveHandler ... not generating pingbacks for $web.$topic");
    return; # nop
  }

  # now do it
  my $urlHost = &Foswiki::Func::getUrlHost();
  my $source = Foswiki::Func::getViewUrl($web, $topic);
  my @pings;
  my $db = getPingDB();

  # get all text
  $text =~ s/.*?%STARTPINGBACK%//os;
  $text =~ s/%STOPPINGBACK%.*//os;
  $text =~ s/%META:[A-Z]+{.*}%\s*//go;
  my @fields = $meta->find('FIELD');
  foreach my $field (@fields) {
    $text .= ' ' . $field->{value};
  }

  # expand it
  $Foswiki::Plugins::SESSION->enterContext('absolute_urls');
  $text = Foswiki::Func::expandCommonVariables($text, $topic, $web);
  $text = Foswiki::Func::renderText($text, $web);
  $Foswiki::Plugins::SESSION->leaveContext('absolute_urls');
  writeDebug("text=$text");

  # analyse it
  while ($text =~ /<a\s+[^>]*?href=(?:\"|\'|&quot;)?([^\"\'\s>]+)(?:\"|\'|\s|&quot;>)?/gios) {
    my $target = $1;
    my $doPing = 0;
    $target =~ /^http/i && ($doPing = 1); # only for outgoing
    #$target =~ /^$urlHost/i && ($doPing = 0); # not for own host
    next unless $doPing;
    writeDebug("found target $target");
    my $ping = $db->newPing(source=>$source, target=>$target);
    $ping->timeStamp();
    push @pings, $ping;
  }
  $db->queuePings('out', @pings);
  writeDebug('queued '.(scalar @pings).' pings');
  writeDebug("done afterSaveHandler");
}

################################################################################
sub expandVariables {
  my ($format, %variables) = @_;

  my $text = $format;

  foreach my $key (keys %variables) {
    $text =~ s/\$$key/$variables{$key}/g;
  }
  $text =~ s/\$perce?nt/\%/go;
  $text =~ s/\$nop//g;
  $text =~ s/\$n/\n/go;
  $text =~ s/\$dollar/\$/go;

  return $text;
}

###############################################################################
sub inlineError {
  return '<span class="foswikiAlert">'.$_[0].'</span>';
}

1;
