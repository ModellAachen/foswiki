#! /usr/bin/perl -w

use strict;
use Digest::MD5;
use FileHandle;
use TWiki::Plugins::TWikiReleaseTrackerPlugin::IndexDistributions;
use TWiki::Plugins::TWikiReleaseTrackerPlugin::FileDigest;
use TWiki::Plugins::TWikiReleaseTrackerPlugin::Common;

package TWiki::Plugins::TWikiReleaseTrackerPlugin::DistributionWalker;

sub match {

=pod
    For the named distribution, progressively call matchCallback 
    with every file that does not match the excludeFilePattern

    matchCallBack is called with params:
      $matchCallback($distribution, $location, $pathname, $relativeFile, $digest);

    where:
        distribution is the name of the distribution (passed in)
	location is where it is stored on disk (passed in)
	pathname is the absolute path to the file
	relativeFile is its name key
	digest is its content (signature) key
	
=cut

    my ( $distribution, $location, $excludeFilePattern, $matchCallback ) = @_;
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
        my ( $relativeFile, $digest ) = @_;
        my $pathname;
        if ( $distribution eq 'localInstallation' ) {
            $pathname = $Common::installationDir . "/" . $relativeFile;
        }
        else {
            $pathname =
              $Common::downloadDir . "/" . $distribution . "/" . $relativeFile;
        }

        &$matchCallback( $distribution, $location, $pathname, $relativeFile,
            $digest );
    };

    my @occurances =
      TWiki::Plugins::TWikiReleaseTrackerPlugin::FileDigest::retreiveOccurancesForDistribution(
        $distribution);
    foreach my $occurance (@occurances) {
        my ( $filename, $digest ) = @{$occurance};
        &$findCallback( $filename, $digest );
    }
    return $#occurances;
}

1;
