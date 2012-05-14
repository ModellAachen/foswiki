#! /usr/bin/perl -w

use strict;

BEGIN {
    unless ( -d "test" ) { chdir ".." }
}

use Common;
use Cwd;
use InstallationWalker;

FileDigest::loadIndexes($Common::md5IndexDir);

sub matchFile {
    my ( $distribution, $distributionLocation, $pathname, $relativeFile,
        $digest )
      = @_;
    print $distribution. ": " . $relativeFile . " = ";

    #    print FileDigest::retreiveStringForDigest($digest)."\n";
    my @matches =
      FileDigest::retreiveDistributionsForDigest( $digest, $relativeFile );

    print join( ",", @matches ) . "\n";
}

InstallationWalker::match( "", cwd() . "/../../../../../",
    $Common::excludeFilePattern, \&matchFile );

