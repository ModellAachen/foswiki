# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2009-2010 Michael Daum http://michaeldaumconsulting.com
#
# Based on DatabasePlugin Copyright (C) 2002-2007 Tait Cyrus, tait.cyrus@usa.net
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

package Foswiki::Plugins::SqlPlugin::Connection;

use DBI ();
use strict;
use Error qw( :try );
use Foswiki::Sandbox ();

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR "- SqlPlugin::Connection - $_[0]\n" if DEBUG;
}


###############################################################################
sub new {
  my $class = shift;

  my $this = {
    db => undef,
    id => '',
    dsn => '',
    @_
  };

  # untaint this
  foreach my $key (%$this) {
    next unless $key && $this->{$key};
    $this->{$key} = Foswiki::Sandbox::untaintUnchecked($this->{$key});
  }

  bless($this, $class);

  return $this;
}

###############################################################################
sub DESTROY {
  my $this = shift;
  
  $this->disconnect();
  #writeDebug("destroying $this->{id}");
}

###############################################################################
sub disconnect {
  my $this = shift;

  return unless $this->{db};

  $this->{db}->disconnect();
  $this->{db} = undef;
}

###############################################################################
sub connect {
  my $this = shift;

  return if $this->{db};

  writeDebug("connecting $this->{id} using $this->{dsn}");

  # just create it
  my $workarea = Foswiki::Func::getWorkArea('SqlPlugin');

  my $db = DBI->connect(
    $this->{dsn},
    $this->{username},
    $this->{password},
    { 
      PrintError => 0, 
      RaiseError => 1 
    });

  throw Error::Simple("Can't open database $this->{id}: ". $DBI::errstr)
    unless $db;

  $this->{db} = $db;
}

1;

