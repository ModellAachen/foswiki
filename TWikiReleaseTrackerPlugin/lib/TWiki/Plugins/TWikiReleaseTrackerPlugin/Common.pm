#! /usr/bin/perl -w

use strict;

package TWiki::Plugins::TWikiReleaseTrackerPlugin::Common;
use TWiki::Plugins::TWikiReleaseTrackerPlugin::TRTConfig;
use Cwd;

#FIXME: needs tidying, especially this pub monstrosity.

my $pub;
if ( defined(&TWiki::Func::getPubDir) ) {
    $pub = TWiki::Func::getPubDir();
}
elsif ( -d "pub" ) {
    $pub = cwd() . "/pub";
}
else {
    $pub = cwd() . "/../../../../pub/";    #CodeSmell gross

}
unless ( -d $pub ) {
    die "Couldn't find the pub (directory) '$pub' (cwd=" . cwd();
}

unless ( defined $Common::md5IndexDir ) {
    setIndexTopic("System.TWikiReleaseTrackerPlugin");
}

unless ( -d $Common::md5IndexDir ) {
    die "Couldn't locate directory $Common::md5IndexDir - $!";
}

{
    no warnings;

    sub debug {
        my ($ans) = @_;

#    print STDERR $ans; # you really don't want to forget to recomment this in a live environment
    }

    sub relativeFromPathname {
        my ( $filename, $setpath ) = @_;
        my $ans = $filename;
        $ans =~ s!$setpath!!;
        return $ans;
    }

    sub setIndexTopic {
        my ($webTopic) = @_;
        my ( $web, $topic ) = ( $webTopic =~ m/(.+)\.(.+)/ );
        $Common::md5IndexDir = "$pub/$web/$topic/";
    }

    sub getPubDir {
        return $pub;
    }
}
1;
