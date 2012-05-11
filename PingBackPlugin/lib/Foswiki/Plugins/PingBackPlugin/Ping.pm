# Ping Abstraction
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

package Foswiki::Plugins::PingBackPlugin::Ping;

use strict;
use Digest::MD5 qw(md5_hex);
use vars qw($debug @ISA @EXPORT_OK);
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(readPing);
$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR '- PingBackPlugin::Ping - '.$_[0]."\n" if $debug;
}

###############################################################################
# static: read a ping from a file 
sub readPing {
  my ($db, $file) = @_;

  writeDebug("called readPing($file)");

  my %data = (
    date => '',
    source => '',
    target => '',
    title => '',
    favicon => '',
    paragraph => '',
    extra => '',
  );

  open(FILE, "<$file") || die "cannot open $file - $!";
  writeDebug('opening');
  while (my $line = <FILE>) {
    next if $line =~ /^#/;
    writeDebug("line=$line");
    if ($line =~ /^(date|source|target|title|favicon|title|paragraph)=(.*)$/) {
      unless ($data{$1}) {
	$data{$1} = $2;
	writeDebug("found $1=$2");
	next;
      }
    }
    writeDebug("adding extra");
    $data{extra} .= $line;
  }
  close FILE;
  writeDebug('closing');

  my $ping = $db->newPing(%data);
  writeDebug("read ping \n".$ping->toString("\n"));

  return $ping;
}

################################################################################
# constructor
sub new {
  my $class = shift;
  my $db = shift;

  writeDebug("new ping");

  my $this = {
    db=>$db,
    date=>'',
    source=>'',
    target=>'',
    title=>'',
    favicon=>'',
    paragraph=>'',
    extra=>'',
    @_
  };

  $this = bless($this, $class);

  return $this;
}

###############################################################################
sub timeStamp {
  my ($this, $date) = @_;

  writeDebug('called timeStamp');
  
  unless ($date) {
    # SMELL: lets have it numerical
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time());
    $date = sprintf("%.4u/%.2u/%.2u - %.2u:%.2u:%.2u", 
      $year+1900, $mon+1, $mday, $hour, $min, $sec);
  }
  $this->{date} = $date;

  return $date;
}

###############################################################################
# write w/o locking
sub write {
  my ($this, $queueName) = @_;

  if ($queueName) {
    # tag ping location
    $this->{queueName} = $queueName;
  } else {
    # retrieve location
    $queueName = $this->{queueName};
    die "don't know where to write this ping to" unless $queueName;
  }

  writeDebug("called write($queueName) for \n".$this->toString("\n"));

  my $pingFile = $this->getPingFile($queueName);

  open(FILE, ">$pingFile") || die "cannot append $pingFile - $!\n";

  print FILE 
    'date='.$this->{date}."\n".
    'source='.$this->{source}."\n".
    'target='.$this->{target}."\n".
    'title='.$this->{title}."\n".
    'paragraph='.$this->{paragraph}."\n".
    'favicon='.$this->{favicon}."\n".
    $this->{extra}; 

  close FILE;

  return $this;
}

###############################################################################
# safe write using locking
sub queue {
  my ($this, $queueName) = @_;

  writeDebug("called queue($queueName)");
  writeDebug($this->toString);

  $this->{db}->lockQueue($queueName);
  $this->write($queueName);
  $this->{db}->unlockQueue($queueName);

  return $this;
}

###############################################################################
sub unqueue {
  my ($this, $queueName) = @_;

  $queueName = $this->{queueName} unless $queueName;
  die "don't know where this ping is" unless $queueName;

  writeDebug("called unqueue($queueName)");
  writeDebug($this->toString);

  $this->{db}->lockQueue($queueName);
  unlink $this->getPingFile($queueName);
  $this->{db}->unlockQueue($queueName);

  $this->{queueName} = undef;

  return $this;
}

###############################################################################
sub toString {
  my ($this, $separator) = @_;
  $separator ||= ', ';

  return 
    'date='.$this->{date}.$separator.
    'source='.$this->{source}.$separator.
    'target='.$this->{target}.$separator.
    'title='.$this->{title}.$separator.
    'paragraph='.$this->{paragraph}.$separator.
    'favicon='.$this->{favicon}.$separator.
    'extra='.$this->{extra};
}

###############################################################################
sub getPingFile {
  my ($this, $queueName) = @_;

  $queueName = $this->{queueName} unless $queueName;
  die "don't know where this ping is" unless $queueName;

  my $queueDir = $this->{db}->getQueueDir($queueName);
  $this->{pingFile} = $queueDir.'/'.$this->getKey();

  return $this->{pingFile};
}

###############################################################################
sub getKey {
  my $this = shift;

  $this->{key} = md5_hex($this->{source}."\0".$this->{target}) 
    unless $this->{key};

  return $this->{key};
}

###############################################################################
sub isAlien {
  my $this = shift;

  $this->getTargetWebTopic();

  return $this->{targetWeb}?0:1;
}

###############################################################################
sub isInternal {
  my $this = shift;

  $this->getTargetWebTopic();
  $this->getSourceWebTopic();

  return ($this->{sourceWeb} && $this->{targetWeb})?1:0;
}

###############################################################################
sub getTargetWebTopic {
  my $this = shift;
  
  unless (defined $this->{targetWeb}) {

    my $viewUrl = Foswiki::Func::getScriptUrl(undef,undef,'view');
    
    if ($this->{target} =~ /^$viewUrl\/(.*)\/(.*?)$/) {
    
      ($this->{targetWeb}, $this->{targetTopic}) = 
	Foswiki::Func::normalizeWebTopicName($1, $2);
	
    } else {
    
      $this->{targetWeb} = '';
      $this->{targetTopic} = '';

    }
  }

  return ($this->{targetWeb}, $this->{targetTopic});
}

###############################################################################
sub getSourceWebTopic {
  my $this = shift;

  unless (defined $this->{sourceWeb}) {

    my $viewUrl = Foswiki::Func::getScriptUrl(undef,undef,'view');
    
    if ($this->{source} =~ /^$viewUrl\/(.*)\/(.*?)$/) {
    
      ($this->{sourceWeb}, $this->{sourceTopic}) = 
	Foswiki::Func::normalizeWebTopicName($1, $2);
	
    } else {
    
      $this->{sourceWeb} = '';
      $this->{sourceTopic} = '';

    }
  }

  return ($this->{sourceWeb}, $this->{sourceTopic});

}

###############################################################################
# send this ping using the pingback client
sub send {
  my $this = shift;

  eval 'use Foswiki::Plugins::PingBackPlugin::Client;';
  die $@ if $@; # never reach

  my $client = Foswiki::Plugins::PingBackPlugin::Client::getClient();
  return $client->ping($this->{source}, $this->{target});
}

1;
