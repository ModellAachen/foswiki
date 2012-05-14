# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2012 Michael Daum http://michaeldaumconsulting.com
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
# http://www.gnu.org/copyleft/gpl.html
#

package Foswiki::Plugins::UserInfoPlugin::Core;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Time ();

use constant DEBUG => 0; # toggle me

###############################################################################
# static
sub writeDebug {
  #Foswiki::Func::writeDebug("- UserInfoPlugin - " . $_[0]) if DEBUG;
  print STDERR "- UserInfoPlugin - " . $_[0] . "\n" if DEBUG;
}

###############################################################################
sub new {
  my $class = shift;

  my $this = bless({}, $class);

  #writeDebug("building a new Core");

  # figure out where the sessions are
  $this->{sessionDir} = $Foswiki::cfg{WorkingDir} . '/tmp';
  if (! -e $this->{sessionDir}) {
    $this->{sessionDir} = '/tmp';
  }
  
  # init properties
  $this->{ignoreHosts} = 
    Foswiki::Func::getPreferencesValue("USERINFOPLUGIN_IGNORE_HOSTS") || '';
  $this->{ignoreHosts} = join('|', split(/\s*,\s*/, $this->{ignoreHosts}));

  my $usersString =
    Foswiki::Func::getPreferencesValue("USERINFOPLUGIN_IGNORE_USERS") || '';

  my @users;
  foreach my $user (split(/\s*,\s*/, $usersString)) {
    $user =~ s/^.*\.(.*?)$/$1/;
    push @users, $user;
  }

  push @users, 
    $Foswiki::cfg{DefaultUserWikiName},
    $Foswiki::cfg{SuperAdminGroup},
    $Foswiki::cfg{AdminUserWikiName},
    $Foswiki::cfg{Register}{RegistrationAgentWikiName},
    "UnknownUser",
    "ProjectContributor";

  $this->{ignoreUsers} = join('|', @users);

  writeDebug("ignoreHosts=$this->{ignoreHosts}");
  writeDebug("ignoreUsers=$this->{ignoreUsers}");

  return $this;
}

###############################################################################
sub handleNrUsers {
  my $this = shift;

  writeDebug("called handleNrUsers");
  return $this->{nrUsers} if defined $this->{nrUsers};

  my $it = Foswiki::Func::eachUser();
  $this->{nrUsers} = scalar($it->all);
 
  writeDebug("got $this->{nrUsers} nr users");
  return $this->{nrUsers};
}

###############################################################################
sub handleNrVisitors {
  my $this = shift;

  writeDebug("called handleNrVisitors");
  return $this->{nrVisitors} if defined $this->{nrVisitors};

  my ($visitors) = $this->getVisitorsFromSessionStore(undef, $this->{ignoreUsers});
  $this->{nrVisitors} = scalar @$visitors;

  writeDebug("got $this->{nrVisitors} nr visitors");
  return $this->{nrVisitors};
}

###############################################################################
sub handleNrGuests {
  my $this =  shift;

  writeDebug("called handleNrGuests");
  return $this->{nrGuests} if defined $this->{nrGuests};

  my (undef, $guests) = $this->getVisitorsFromSessionStore($Foswiki::cfg{DefaultUserWikiName});
  $this->{nrGuests} = scalar @$guests;

  writeDebug("got $this->{nrGuests} nr guests");
  return $this->{nrGuests};
}

###############################################################################
sub handleNrLastVisitors {
  my ($this, $session, $params, $web, $topic) = @_;

  writeDebug("called handleNrLastVisitors");

  my $theDays = $params->{days} || 1;
  return $this->{nrLastVisitors}{$theDays} if defined $this->{nrLastVisitors}{$theDays};

  my $visitors = $this->getVisitors($theDays, undef, undef, $this->{ignoreUsers});
  $this->{nrLastVisitors}{$theDays} = scalar @$visitors;

  writeDebug("got $this->{nrLastVisitors} nr last visitors");
  return $this->{nrLastVisitors}{$theDays};
}

###############################################################################
sub handleVisitors {
  my ($this, $session, $params, $web, $topic) = @_;

  writeDebug("called handleVisitors");

  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theFormat = $params->{format};
  $theFormat = '   * $wikiusername' unless defined $theFormat;

  my $theSep = $params->{sep} || $params->{separator};
  $theSep = '$n' unless defined $theSep;

  my $theMax = $params->{max} || 0;
  $theMax = 0 if $theMax eq "unlimited";
  
  # get current visitors
  my ($visitors) = $this->getVisitorsFromSessionStore(undef, $this->{ignoreUsers});
  return '' unless @$visitors;

  # get more information from the logfiles
  $visitors = join('|', @$visitors);
  $visitors = $this->getVisitors(1, undef, $visitors, $this->{ignoreUsers});

  my @result = ();
  my $index = 0;
  foreach my $visitor (sort {$a->{wikiname} cmp $b->{wikiname}} @$visitors) {
    last if $theMax && $index > $theMax;
    my $line = $theFormat;

    push @result, replaceVars($line, {
      'index'=>$index,
      'wikiname'=>$visitor->{wikiname}, 
      'date'=>$visitor->{sdate},
      'time'=>$visitor->{time},
      'host'=>$visitor->{host},
      'topic'=>$visitor->{topic},
    });

    $index++;
    #writeDebug("found visitor $visitor->{wikiname}");
  }

  return '' unless @result;

  my $result = replaceVars($theHeader).join(replaceVars($theSep), @result).replaceVars($theFooter);
  $result =~ s/\$count/$index/g;
  $result =~ s/\$total/$this->handleNrUsers()/ge;
  
  return $result;
}

###############################################################################
# render list of 10 most recently registered users.
# this information is extracted from %HOMEWEB%.WikiUsers
sub handleNewUsers {
  my ($this, $session, $params, $web, $topic) = @_;

  writeDebug("called handleNewUsers");

  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';

  my $theFormat = $params->{format};
  $theFormat = '   * $date - $wikiusername' unless defined $theFormat;

  my $theSep = $params->{sep} || $params->{separator};
  $theSep = '$n' unless defined $theSep;

  my $theMax = $params->{max};
  $theMax = 10 unless defined $theMax;
  $theMax = 0 if $theMax eq "unlimited";

  my @users = ();
  my $it = Foswiki::Func::eachUser();
  while ($it->hasNext()) {
    my $user = $it->next();
    next if $user =~ $this->{ignoreUsers};
    next unless Foswiki::Func::topicExists($Foswiki::cfg{UsersWebName}, $user);
    my ($date) = Foswiki::Func::getRevisionInfo($Foswiki::cfg{UsersWebName}, $user, 1);
    push @users, {
      wikiname => $user,
      date => $date,
    };
  }

  my $index = 0;
  my @result = ();
  foreach my $user (sort { $b->{date} <=> $a->{date}} @users) {
    last if $theMax && $index > $theMax;

    my $line = $theFormat;
    push @result, replaceVars($line, {
      index=>$index,
      wikiname=>$user->{wikiname}, 
      date => Foswiki::Func::formatTime($user->{date}, '$day $mon $year'),
    });

    #writeDebug("found new user $user->{name}");
    $index++;
  }

  return '' unless @result;

  my $result = replaceVars($theHeader).join(replaceVars($theSep), @result).replaceVars($theFooter);
  $result =~ s/\$count/$index/g;
  $result =~ s/\$total/$this->handleNrUsers()/ge;

  return $result;
}

###############################################################################
sub handleLastVisitors {
  my ($this, $session, $params, $web, $topic) = @_;

  writeDebug("called handleLastVisitors");

  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';

  my $theFormat = $params->{format};
  $theFormat = '   * $date - $wikiusername' unless defined $theFormat;

  my $theSep = $params->{sep} || $params->{separator};
  $theSep = '$n' unless defined $theSep;

  my $theMax = $params->{max};
  $theMax = 0 unless defined $theMax;
  $theMax = 0 if $theMax eq "unlimited";

  my $theDays = $params->{days} || 1;

  my $visitors = $this->getVisitors($theDays, $theMax, undef, $this->{ignoreUsers});

  # garnish the collected data
  my @result = ();
  my $index = 0;
  foreach my $visitor (sort {$b->{date} <=> $a->{date}} @$visitors) {
    last if $theMax && $index > $theMax;

    my $line = $theFormat;
    push @result, replaceVars($line, {
      'index'=>$index,
      'wikiname'=>$visitor->{wikiname}, 
      'date'=>$visitor->{sdate},
      'time'=>$visitor->{time},
      'host'=>$visitor->{host},
      'topic'=>$visitor->{topic},
    });

    #writeDebug("found last visitor $visitor->{wikiname}");
    $index++;
  }

  return '' unless @result;

  my $result = replaceVars($theHeader).join(replaceVars($theSep), @result).replaceVars($theFooter);
  $result =~ s/\$count/$index/g;
  $result =~ s/\$total/$this->handleNrUsers()/ge;

  return $result;
}

###############################################################################
# TODO: add a cache 
#
# get list of users that still have a session object
# this is the number of session objects
sub getVisitorsFromSessionStore {
  my ($this, $includeNames, $excludeNames) = @_;

  writeDebug("getVisitorsFromSessionStore()");
  writeDebug("includeNames=$includeNames") if $includeNames;
  writeDebug("excludeNames=$excludeNames") if $excludeNames;

  # get session directory

  # get wikinames of current visitors
  my %users = ();
  my %guests = ();
  my @sessionFiles = reverse glob $this->{sessionDir}.'/cgisess_*';
  foreach my $sessionFile (@sessionFiles) {

    #writeDebug("reading $sessionFile");
  
    my $dump = Foswiki::Func::readFile($sessionFile);
    next unless $dump;

    my $wikiName = $Foswiki::cfg{DefaultUserWikiName};
    if ($dump =~ /['"]?AUTHUSER['"]? => ["'](.*?)["']/) {
      $wikiName = $1;
    }
    #writeDebug("wikiName=$wikiName");

    my $host;
    if ($dump =~ /["']?_SESSION_REMOTE_ADDR["']? => ['"](.*?)['"]/) {
      $host = $1;
    }

    if ($host) {
      #writeDebug("host=$host");
      next if $host =~ /$this->{ignoreHosts}/;
      $guests{$host} = 1 if $wikiName eq $Foswiki::cfg{DefaultUserWikiName};
    }

    next if $users{$wikiName};
    next if $excludeNames && $wikiName =~ /$excludeNames/;
    next if $includeNames && $wikiName !~ /$includeNames/;
    writeDebug("found $wikiName");
    $users{$wikiName} = 1;
  }

  my @users = keys %users;
  my @guests = keys %guests;

  return (\@users, \@guests);
}

###############################################################################
# TODO: cache up to the max seen days and extract a list matching the 
# include/excludeNames pattern afterwards
sub getVisitors {
  my ($this, $theDays, $theMax, $includeNames, $excludeNames) = @_;

  $theMax = 0 unless $theMax;

  writeDebug("getVisitors()");
  writeDebug("theDays=$theDays") if $theDays;
  writeDebug("theMax=$theMax") if $theMax;
  writeDebug("includeNames=$includeNames") if $includeNames;
  writeDebug("excludeNames=$excludeNames") if $excludeNames;
  my @lastVisitors = ();
  my %seen;

  # Round "now" to today
  my $then = (time() / (24 * 60 * 60)) * (24 * 60 * 60);
  $then -= ($theDays * 24 * 60 * 60);
  $then = int($then / (24 * 60 * 60)) * 24 * 60 * 60;
  my $it = Foswiki::Func::eachEventSince($then);
  while ($it->hasNext()) {
      my $e = $it->next();

      my $wikiName = Foswiki::Func::getWikiName($e->[1]);

      # check back
      next unless Foswiki::Func::topicExists($Foswiki::cfg{UsersWebName}, $wikiName);

      # create visitor struct
      my $visitor = {
          'sdate'    => Foswiki::Time::formatTime($e->[0], '$day $mon $year'),
          'date'     => $e->[0],
          'wikiname' => $wikiName,
          'time'     =>  Foswiki::Time::formatTime($e->[0], '$min:$sec'),
          'topic'    => $e->[3],
          'host'     => $e->[5],
      };
      # store
      $seen{$wikiName} = $visitor;
  }

  @lastVisitors = values %seen;

  return \@lastVisitors;
}

###############################################################################
# static
sub replaceVars {
  my ($format, $data) = @_;

  #writeDebug("replaceVars($format, data)");

  if (defined $data) {
    if (defined $data->{wikiname}) {
      $data->{username} = Foswiki::Func::wikiToUserName($data->{wikiname});
      $data->{wikiusername} = Foswiki::Func::userToWikiName($data->{wikiname});
    }

    foreach my $key (keys %$data) {
      $format =~ s/\$$key/$data->{$key}/g;
    }
  }

  $format =~ s/\$perce?nt/\%/go;
  $format =~ s/\$nop\b//go;
  $format =~ s/\$n/\n/go;
  $format =~ s/\$dollar/\$/go;

  #writeDebug("returns '$format'");

  return $format;
}

1;
