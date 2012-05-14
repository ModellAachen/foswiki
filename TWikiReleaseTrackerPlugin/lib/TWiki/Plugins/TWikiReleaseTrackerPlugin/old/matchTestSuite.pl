#! /usr/bin/perl -w

use strict;

BEGIN {
    unless ( -d "test" ) { chdir ".." }
}

use Common;
use Cwd;

use DistributionWalker;

FileDigest::loadIndexes("test");

sub matchFile {
    my ( $distribution, $distributionLocation, $pathname, $relativeFile,
        $digest )
      = @_;
    print $distribution. ": " . $relativeFile . " = $digest\n";

#    print FileDigest::retreiveStringForDigest($digest)."\n";
#    my @matches = FileDigest::retreiveDistributionsForDigest($digest, $relativeFile);

    #    print join(",", @matches)."\n";
}

sub test {
    my ( $n, $distro ) = @_;
    print "\n\n======== Test $n = against $distro ================\n";
    DistributionWalker::match( "localInstallation", cwd() . "/../../../../../",
        $Common::excludeFilePattern, \&matchFile );
}

test( 1, "localInstallation" );
test( 2, "distro1" );
test( 3, "distro2" );

