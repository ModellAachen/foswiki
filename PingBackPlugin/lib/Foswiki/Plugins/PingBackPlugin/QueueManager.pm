# PingBack QueueManager
#
# Copyright (C) 2006 MichaelDaum@WikiRing.com
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

package Foswiki::Plugins::PingBackPlugin::QueueManager;

use strict;
use vars qw($debug);

$debug = 0; # toggle me

use Foswiki::Plugins::PingBackPlugin::DB qw(getPingDB);
use LWP::UserAgent;
use HTML::TokeParser;
use HTTP::Request;
use HTML::Entities qw(encode_entities);

###############################################################################
sub writeDebug {
  print STDERR '- PingBackPlugin::QueueManager - '.$_[0]."\n" if $debug;
}

###############################################################################
sub writeLog {
  print LOG '- PingBackPlugin::QueueManager - '.$_[0]."\n";
  writeDebug($_[0]);
}

###############################################################################
sub run {
  my $session = shift;

  $Foswiki::Plugins::SESSION = $session;

  writeDebug("called run");

  # open log
  my $time = Foswiki::Func::formatTime(time());
  my $logfile = Foswiki::Func::getDataDir().'/pingback.log';
  open(LOG, ">>$logfile") || die "cannot create lock $logfile - $!\n";
  writeLog("started at $time");

  my $queueManager = Foswiki::Plugins::PingBackPlugin::QueueManager->new();

  $queueManager->processInQueue();
  $queueManager->processOutQueue();

  # close log
  $time = Foswiki::Func::formatTime(time());
  writeLog("finished at $time");
  close LOG;

  writeDebug("done run");
}

################################################################################
# constructor
sub new {
  my $class = shift;

  my $this = {
    ua=>'', # LWP::UserAgent
    timeout=>30,
    @_
  };

  return bless($this, $class);
}

################################################################################
sub getAgent {
  my $this = shift;

  unless ($this->{ua}) {
    $this->{ua} = LWP::UserAgent->new();
    $this->{ua}->agent("Foswiki Pingback Manager");
    $this->{ua}->timeout($this->{timeout});
    $this->{ua}->env_proxy();
    writeDebug("new agent=" . $this->{ua}->agent());
  }

  return $this->{ua};
}

################################################################################
# get target page
sub fetchPage {
  my ($this, $source, $target) = @_;

  my $ua = $this->getAgent();
  my $request = HTTP::Request->new('GET', $target);
  $request->referer($source);
  return $ua->request($request);
}

###############################################################################
# check if the source links to the target
sub checkBackLink {
  my ($this, $ping) = @_;

  writeDebug("called checkBackLink source=$ping->{source}, target=$ping->{target}");

  # fetch page
  my $page = $this->fetchPage($ping->{target}, $ping->{source});
  my $content = $page->content();

  # search source
  my $parser = HTML::TokeParser->new(\$content);
  die "can't construct parser: $!" unless $parser;

  # get title
  my $title = '';
  if ($parser->get_tag('title')) {
    $title = $parser->get_trimmed_text;
    encode_entities($title);
    writeDebug("found document titled '$title'");
  }

  # get base
  my $baseHref;
  my $baseSpec = $parser->get_tag('base');
  if ($baseSpec) {
    my (undef, $baseHash) = @$baseSpec;
    $baseHref = $baseHash->{href} || '';
    writeDebug("found baseHref=$baseHref");
  }

  # get http_host
  my $targetHost = $ping->{target};
  if ($targetHost =~ /^(https?:\/\/.*?(:\d+)?)(\/.*)?$/) {
    $targetHost = $1;
  }
  writeDebug("targetHost=$targetHost");

  # find source in target
  my @accu;
  while (my $token = $parser->get_token) {
    push @accu, $token;
    next unless $token->[0] eq 'S';
    #writeDebug("pushing $token->[1]");
    next if $token->[1] ne 'a';

    # analyse anchors
    my $url = $token->[2]{href};
    next unless $url;

    # make relative urls absolute
    if ($url =~ /^\//) {
      $url = $targetHost.$url;
    }
    writeDebug("url=$url");

    # check source
    unless ($url eq $ping->{target}) {
      #writeDebug("does not match source");
      next;
    }

    # reconstruct last paragraph
    # by collecting the recent text tokens
    my @lastParagraph = '';
    while (my $oldToken = pop(@accu)) {
      unshift @lastParagraph, $oldToken->[1] if $oldToken->[0] eq 'T';
      last if $oldToken->[1] =~ /^(div|p|span)$/;
    }
    my $text = 
      substr(join(' ', @lastParagraph), -160, 160) . ' ' .
      substr($parser->get_text('p', 'br'), 0, 160);
    encode_entities($text);
    $text =~ s/[\r\n]/ /go;
    $text =~ s/^\s+//go;
    $text =~ s/\s+$//go;

    $ping->{title} = $title;
    $ping->{paragraph} = $text;
    writeDebug("found url=$url, text=$text");
    return 1;
  }

  return 0;
}


###############################################################################
sub processInQueue {
  my $this = shift;
  writeDebug("called processInQueue");

  my $db = getPingDB();
  my @pings = $db->readQueue('in');

  # process all pings
  foreach my $ping (@pings) {
    writeLog("processing pingback ".
      "from $ping->{source} to $ping->{target}");

    # remove circular ping
    if ($ping->{source} eq $ping->{target}) {
      writeLog("cirular ping ... moving to trash");
      $ping->unqueue();
      $ping->queue('trash');
      next;
    }

    # check for foregin ping
    if ($ping->isAlien) {
      writeLog("found alien ping .".$ping->toString);
      # remove from queue
      $ping->unqueue();
      next;
    }

    # check for an internal ping
    if ($ping->isInternal) {
      # internal ping
      writeLog('processing internal pingback from '.
	$ping->{sourceWeb}.'.'.$ping->{sourceTopic}.' to '.
	$ping->{targetWeb}.'.'.$ping->{targetTopic});

      # check if target exists
      unless (Foswiki::Func::topicExists($ping->{targetWeb}, $ping->{targetTopic})) {
	writeLog("target does not exist ... moving to trash");
	$ping->unqueue();
	$ping->queue('trash');
	next;
      }

      # check if source exists
      unless (Foswiki::Func::topicExists($ping->{sourceWeb}, $ping->{sourceTopic})) {
	writeLog("source does not exist ... moving to trash");
	$ping->unqueue();
	$ping->queue('trash');
	next;
      }
    } else {
    }

    # check if target links to source
    unless ($this->checkBackLink($ping)) {
      writeLog("target does not link back to source ... moving to trash");
      $ping->unqueue();
      $ping->queue('trash'); # how about _deleting_ it right away
      next;
    }

    # approved
    writeLog("approved ping !!!");
    $ping->unqueue();
    $ping->queue('cur');
  }
  
  writeDebug("done processInQueue");
}

###############################################################################
sub processOutQueue {
  my $this = shift;

  writeDebug("called processOutQueue");
  my $db = getPingDB();
  my @pings = $db->readQueue('out');

  # process all pings
  foreach my $ping (@pings) {
    writeLog("sending pingback ".
      "from $ping->{source} to $ping->{target}");
    my ($status, $result) = $ping->send();
    $ping->unqueue();
    writeLog("status=$status");
    writeLog("result=$result");
  }
  writeDebug("done processOutQueue");
}

###############################################################################
sub processTrash {
  my $this = shift;

  writeDebug("called processTrash");

  # TODO: remove old items from trash
  writeDebug("done processTrash");
}

1;
