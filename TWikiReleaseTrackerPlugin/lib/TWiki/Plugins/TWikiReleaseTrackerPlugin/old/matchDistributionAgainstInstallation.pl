#! /usr/bin/perl -w

use strict;

BEGIN {
    unless ( -d "test" ) { chdir ".." }
}

use Common;
use Cwd;

use DistributionWalker;

FileDigest::loadIndexes($Common::md5IndexDir);

sub matchFile {
    my ( $distribution, $distributionLocation, $pathname, $relativeFile,
        $digest )
      = @_;
    print $distribution. ": " . $relativeFile . " = $digest\n";

#    print FileDigest::retreiveStringForDigest($digest)."\n";
#    my @matches = FileDigest::retreiveDistributionsForDigest($digest, $relativeFile);

    #    print join(",", @matches)."\n";
}

DistributionWalker::match( "TWiki20040320beta", cwd() . "/../../../../../",
    $Common::excludeFilePattern, \&matchFile );

