# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2006 MichaelDaum@WikiRing.com
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
###############################################################################

package Foswiki::Plugins::BlogPlugin::WebDB;

use strict;
use warnings;

use Foswiki::Plugins::DBCachePlugin::WebDB ();
use Time::Local;
@Foswiki::Plugins::BlogPlugin::WebDB::ISA = ("Foswiki::Plugins::DBCachePlugin::WebDB");

use vars qw( %MON2NUM );

%MON2NUM = (
  Jan => 0,
  Feb => 1,
  Mar => 2,
  Apr => 3,
  May => 4,
  Jun => 5,
  Jul => 6,
  Aug => 7,
  Sep => 8,
  Oct => 9,
  Nov => 10,
  Dec => 11
);

###############################################################################
sub new {
  my ($class, $web, $cacheName) = @_;
  $cacheName = '_BlogPluginWebDB' unless $cacheName;
  my $this = bless($class->SUPER::new($web, $cacheName), $class);
  return $this;
}

###############################################################################
# called by superclass when one or more topics had
# to be reloaded from disc.
sub onReload {
  my ($this, $topics) = @_;

  #print STDERR "DEBUG: BlogPlugin::WebDB - called onReload(@_)\n";

  $this->SUPER::onReload($topics);

  foreach my $topicName (@$topics) {
    my $topic = $this->fastget($topicName);

    # override the createdate with the Date formfield
    my $form = $topic->fastget('form');
    if ($form) {
      $form = $topic->fastget($form);
      my $dateField = $form->fastget('Date');
      if ($dateField) {
        my $createDate = parseTime($dateField);
        $topic->set('createdate', $createDate);
      }
    }
  }

  #print STDERR "DEBUG: BlogPlugin::WebDB - done onReload()\n";
}

###############################################################################
sub parseTime {
  my $date = shift;

  # try "31 Dec 2001 - 23:59"  (Foswiki date)
  if ($date =~ /([0-9]+)\s+([A-Za-z]+)\s+([0-9]+)[\s\-]+([0-9]+)\:([0-9]+)/) {
    my $year = $3;
    $year -= 1900 if ($year > 1900);

    # The ($2) will look up the constant so named
    return timelocal(0, $5, $4, $1, $MON2NUM{$2}, $year);
  }

  return 0;
}

###############################################################################
1;
