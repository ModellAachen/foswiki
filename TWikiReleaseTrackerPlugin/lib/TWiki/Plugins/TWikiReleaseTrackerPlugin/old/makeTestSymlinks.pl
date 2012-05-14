#! /bin/perl -w
use strict;
use diagnostics;

chdir '/home/mrjc/cleaver.org/twiki/' || die "$! twiki dir";

my @liveFiles      = qw(localInstallation.md5 plugins.md5 releases.md5);
my @testSuiteFiles = qw(testDistros.md5 testInstallation.md5);

my $testDirRelativeToPubTWiki =
  '../../../lib/TWiki/Plugins/TWikiReleaseTrackerPlugin/test';
my $docAttachments     = 'pub/TWiki/TWikiReleaseTrackerPlugin';
my $testDocAttachments = 'pub/TWiki/TRTTestSuite';

chdir $docAttachments || die "can't cd to $docAttachments $!";

my $testmode = $ARGV[0];

die "$0 - test or untest" unless ($testmode);

if ( $testmode eq 'test' ) {
    foreach my $f (@liveFiles) {
        `mv $f $f-`;
    }
    linkFilesIntoDir( $docAttachments, $testDirRelativeToPubTWiki,
        @testSuiteFiles );
    print `ls`;
}
else {
    foreach my $f (@liveFiles) {
        `mv $f- $f`;
    }

    print "Removing "
      . join( ",", @testSuiteFiles )
      . " from $docAttachments\n";
    `rm testDistros.md5`;
    `rm testInstallation.md5`;
    print `ls`;
}

chdir $testDocAttachments || die "can't cd into $testDocAttachments";

print `ls -l`;
linkFilesIntoDir( $testDirRelativeToPubTWiki, $testDocAttachments,
    @testSuiteFiles );

sub linkFilesIntoDir {
    my ( $toDir, $fromDir, @files ) = @_;

    print "Linking from $fromDir to $toDir\n";
    chdir $toDir || die "Can't cd to $toDir$!\n";
    foreach my $f (@files) {
        print "linking $f\n";
        `ln -s $fromDir/testDistros.md5`;
    }

}
