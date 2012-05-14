#! /usr/local/bin/perl -w

use strict;

package TWiki::Plugins::TWikiReleaseTrackerPlugin::TRTConfig;

BEGIN {
    $Common::excludeFilePattern =
      'DEADJOE|.svn|\~$|\,v|.changes|.mailnotify|.session';
    $Common::websToIndex = 'Main|TWiki|Know|Trash';

#    $Common::installationDir = "/home/mrjc/beijingtwiki.mrjc.com/"; #NB. assumes below, e.g. twiki/bin/view, not bin/view

    my $twiki_home = $ENV{TWIKI_HOME};
    if ($twiki_home) {
        $Common::installationDir = "$twiki_home"
          ; # Uncomment for distro; #NB. assumes below, e.g. twiki/bin/view, not bin/view
    }

    unless ($Common::installationDir)
    {       #CodeSmell - need to determine where used
        if ( defined(&TWiki::Func::getPubDir) ) {
            $Common::installationDir = TWiki::Func::getPubDir() . "/..";
        }
    }

    $Common::downloadDir = "/home/mrjc/twikireleasetracker.mrjc.com/download/";
}

1;
