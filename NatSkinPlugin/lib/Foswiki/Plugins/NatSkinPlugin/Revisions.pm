###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
# 
# Copyright (C) 2003-2012 MichaelDaum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatSkinPlugin::Revisions;
use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins::NatSkinPlugin::Utils ();

sub render {
  my ($session, $params) = @_;

  my $request = Foswiki::Func::getCgiQuery();

  #writeDebug("called renderRevisions");
  my $rev1;
  my $rev2;
  $rev1 = $request->param("rev1") if $request;
  $rev2 = $request->param("rev2") if $request;

  my $topicExists = Foswiki::Func::topicExists($baseWeb, $baseTopic);
  if ($topicExists) {
    
    $rev1 = 0 unless $rev1;
    $rev2 = 0 unless $rev2;
    $rev1 =~ s/r?1\.//go;  # cut 'r' and major
    $rev2 =~ s/r?1\.//go;  # cut 'r' and major

    my $maxRev = Foswiki::Plugins::NatSkinPlugin::Utils::getMaxRevision();
    $rev1 = $maxRev if $rev1 < 1;
    $rev1 = $maxRev if $rev1 > $maxRev;
    $rev2 = 1 if $rev2 < 1;
    $rev2 = $maxRev if $rev2 > $maxRev;

  } else {
    $rev1 = 1;
    $rev2 = 1;
  }

  my $revisions = '';
  my $nrrevs = $rev1 - $rev2;
  my $numberOfRevisions = $Foswiki::cfg{NumberOfRevisions};

  if ($nrrevs > $numberOfRevisions) {
    $nrrevs = $numberOfRevisions;
  }

  #writeDebug("rev1=$rev1, rev2=$rev2, nrrevs=$nrrevs");

  my $j = $rev1 - $nrrevs;
  for (my $i = $rev1; $i >= $j; $i -= 1) {
    $revisions .= '&nbsp; <a href="%SCRIPTURLPATH{"view"}%'.
      '/%WEB%/%TOPIC%?rev='.$i.'">r'.$i.'</a>';
    if ($i == $j) {
      my $torev = $j - $nrrevs;
      $torev = 1 if $torev < 0;
      if ($j != $torev) {
	$revisions = $revisions.
	  '&nbsp; <a href="%SCRIPTURLPATH{"rdiff"}%'.
	  '/%WEB%/%TOPIC%?rev1='.$j.'&amp;rev2='.$torev.'">...</a>';
      }
      last;
    } else {
      $revisions .= '&nbsp; <a href="%SCRIPTURLPATH{"rdiff"}%'.
	'/%WEB%/%TOPIC%?rev1='.$i.'&amp;rev2='.($i-1).'">&gt;</a>';
    }
  }

  return $revisions;
}
1;
