#! /usr/bin/perl -w

use strict;
use Digest::MD5;
use FileHandle;
use TWiki::Plugins::TWikiReleaseTrackerPlugin::IndexDistributions;
use TWiki::Plugins::TWikiReleaseTrackerPlugin::FileDigest;
use TWiki::Plugins::TWikiReleaseTrackerPlugin::Common;

package TWiki::Plugins::TWikiReleaseTrackerPlugin::InstallationWalker;

sub match {
    my (
        $distribution,       $distributionLocation,
        $excludeFilePattern, $matchCallback
    ) = @_;
    use File::Find;

    unless ($matchCallback) {
        die(
            "You must define matchCallback as a sub to call for each file found"
        );
    }

    # exclude files that are known junk
    # exclude dirs if
    my $preprocessCallback = sub {
        return grep { !/$excludeFilePattern/ } @_;
    };

    my $findCallback = sub {
        my $pathname = $File::Find::name;    #  complete pathname to the file.
        return unless -f $pathname;
        return if -z $pathname;
        Common::debug "$pathname\n";
        my $digest = IndexDistributions::digestForFile($pathname);
        Common::debug $digest. "\n";
        my $relativeFile =
          Common::relativeFromPathname( $pathname, $distributionLocation );

        &$matchCallback( $distribution, $distributionLocation, $pathname,
            $relativeFile, $digest );
    };
    find(
        {
            wanted       => $findCallback,
            preprocess   => $preprocessCallback,
            follow       => 0,
            untaint      => 1,
            untaint_skip => 1,
            no_chdir     => 1
        },
        $distributionLocation
    );
}

1;
