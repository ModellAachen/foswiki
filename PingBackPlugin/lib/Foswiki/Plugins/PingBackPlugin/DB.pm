# PingBack Database
#
# Copyright (C) 2006 MichaelDaum@WikiRing.com
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

package Foswiki::Plugins::PingBackPlugin::DB;

use strict;
use vars qw($debug $pingDB @ISA @EXPORT_OK);
use Fcntl qw(:flock);
use Foswiki::Plugins::PingBackPlugin::Ping qw(readPing);
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(getPingDB);
$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR '- PingBackPlugin::DB - '.$_[0]."\n" if $debug;
}

###############################################################################
# static constructor of a signleton pingback db
sub getPingDB {
  return $pingDB if $pingDB;

  $pingDB = Foswiki::Plugins::PingBackPlugin::DB->new();

  return $pingDB;
}

################################################################################
# constructor
sub new {
  my ($class) = @_;

  writeDebug("called constructor");

  die 'this is a singleton class, use getPingDB()' if $pingDB;

  my $workarea = Foswiki::Func::getWorkArea('PingBackPlugin');
  my $this = {
    inQueueDir=>$workarea.'/in',
    outQueueDir=>$workarea.'/out',
    curQueueDir=>$workarea.'/cur',
    trashDir=>$workarea.'/trash',
  };

  # check and create db skelleton
  mkdir $this->{inQueueDir} unless -d $this->{inQueueDir};
  mkdir $this->{outQueueDir} unless -d $this->{outQueueDir};
  mkdir $this->{curQueueDir} unless -d $this->{curQueueDir};
  mkdir $this->{trashDir} unless -d $this->{trashDir};

  $pingDB = $this;
  
  return bless($this, $class);
}

###############################################################################
sub lockInQueue {
  my $this = shift;

  my $lockfile = $this->{inQueueDir}.'/lock';
  open(INQUEUE, ">$lockfile") || die "cannot create lock $lockfile - $!\n";
  flock(INQUEUE, LOCK_EX); # wait for exclusive rights
}

###############################################################################
sub unlockInQueue {
  flock(INQUEUE, LOCK_UN);
  close INQUEUE;
}

###############################################################################
sub lockOutQueue {
  my $this = shift;

  my $lockfile = $this->{outQueueDir}.'/lock';
  open(OUTQUEUE, ">$lockfile") || die "cannot create lock $lockfile - $!\n";
  flock(OUTQUEUE, LOCK_EX); # wait for exclusive rights
}

###############################################################################
sub unlockOutQueue {
  flock(OUTQUEUE, LOCK_UN);
  close OUTQUEUE;
}

###############################################################################
sub lockCurQueue {
  my $this = shift;

  my $lockfile = $this->{curQueueDir}.'/lock';
  open(CURQUEUE, ">$lockfile") || die "cannot create lock $lockfile - $!\n";
  flock(CURQUEUE, LOCK_EX); # wait for exclusive rights
}

###############################################################################
sub unlockCurQueue {
  flock(CURQUEUE, LOCK_UN);
  close CURQUEUE;
}

###############################################################################
sub lockTrash {
  my $this = shift;

  my $lockfile = $this->{trashDir}.'/lock';
  open(TRASH, ">$lockfile") || die "cannot create lock $lockfile - $!\n";
  flock(TRASH, LOCK_EX); # wait for exclusive rights
}

###############################################################################
sub unlockTrash {
  flock(TRASH, LOCK_UN);
  close TRASH;
}

###############################################################################
sub getQueueDir {
  my ($this, $queueName) = @_;
  
  return $this->{inQueueDir} if $queueName eq 'in';
  return $this->{outQueueDir} if $queueName eq 'out';
  return $this->{curQueueDir} if $queueName eq 'cur';
  return $this->{trashDir} if $queueName eq 'trash';

  die "unknown queue name $queueName";
}

###############################################################################
sub lockQueue {
  my ($this, $queueName) = @_;

  return $this->lockInQueue() if $queueName eq 'in';
  return $this->lockOutQueue() if $queueName eq 'out';
  return $this->lockCurQueue() if $queueName eq 'cur';
  return $this->lockTrash() if $queueName eq 'trash';

  die "unknown queue name $queueName";
}

###############################################################################
sub unlockQueue {
  my ($this, $queueName) = @_;
  
  return $this->unlockInQueue() if $queueName eq 'in';
  return $this->unlockOutQueue() if $queueName eq 'out';
  return $this->unlockCurQueue() if $queueName eq 'cur';
  return $this->unlockTrash() if $queueName eq 'trash';

  die "unknown queue name $queueName";
}

###############################################################################
sub queuePings {
  my ($this, $queueName, @pings) = @_;

  return unless @pings;

  # lock queue
  $this->lockQueue($queueName);

  # write all pings
  foreach my $ping (@pings) {
    $ping->write($queueName);
  }

  # unlock queue
  $this->unlockQueue($queueName);
}

###############################################################################
sub readQueue {
  my ($this, $queueName) = @_;

  writeDebug("called readQueue($queueName)");

  # lock queue
  $this->lockQueue($queueName);

  # read all pings
  my @pings = ();
  my $queueDir = $this->getQueueDir($queueName);
  opendir(DIR, $queueDir) || die "cannot open directory $queueDir - $!\n";
  foreach my $file (grep(!/^(\.|\.\.|lock)/, readdir(DIR))) {
    my $ping = readPing($this, $queueDir.'/'.$file);
    $ping->{queueName} = $queueName;
    push @pings, $ping;
  }
  closedir DIR;

  # unlock queue
  $this->unlockQueue($queueName);

  #writeDebug("found ".(scalar @pings)." pings");
  writeDebug("done readQueue($queueName)");

  return @pings;
}

###############################################################################
sub newPing {
  my $this = shift;

  writeDebug("called newPing");
  return Foswiki::Plugins::PingBackPlugin::Ping->new($this, @_);
}

1;
