#! /usr/local/bin/perl -w

use strict;
use diagnostics;
use vars qw($testDir $twikiBin);
use Cwd;

BEGIN {
    unless ( -d "test" ) { chdir ".." }
    $testDir = cwd() . "/test" || die "Can't set \$testDir";
}
use TRTConfig;

BEGIN {
    $twikiBin = $Common::installationDir . "/twiki/bin";
    chdir $twikiBin || die "Can't find '$twikiBin' - $!";
}
use lib "../lib";
use TWiki;
use TWiki::Plugins;
use TWiki::Func;

unless ( eval "use TWiki::Plugins::TWikiReleaseTrackerPlugin" ) {
    print "$@\n";
}
TWiki::Plugins::TWikiReleaseTrackerPlugin::initPlugin( "TRTTestSuite", "TWiki",
    "Main.WikiGuest", "TWiki" );

# =======

sub symlinkFromInstallToTestDir {
    my @testSuiteFiles =
      qw(testDistros.md5 testInstallation.md5 test1.correctResults test2.correctResults test3.correctResults test4.correctResults test5.correctResults);
    my $testDocAttachments = Common::getPubDir() . '/TWiki/TRTTestSuite';
    unless ( -d $testDocAttachments ) {
        mkdir $testDocAttachments;
    }
    chdir $testDocAttachments || die "can't cd to $testDocAttachments $!";
    linkFilesIntoDir( $testDocAttachments, $testDir, @testSuiteFiles )
      ;    # would be more elegant to use relative links
    print `ls -l $testDocAttachments`;
}

sub linkFilesIntoDir {
    my ( $toDir, $fromDir, @files ) = @_;

    print "Linking from $fromDir to $toDir\n";
    chdir $toDir || die "Can't cd to $toDir$!\n";
    foreach my $f (@files) {
        print "linking $f\n";
        my $fromFile = "$fromDir/$f";
        my $toFile   = "$toDir/$f";
        if ( -l $toFile ) {
            print "  unlinking $toFile\n";
            unlink $toFile || die "not removing $fromFile - not symlink? - $!";
        }
        elsif ( -f $toFile ) {
            print "  $toFile is not a symlink - not removing\n";
        }
        `ln -s $fromFile`;
    }
}

sub saveResult {
    my ( $file, $testString ) = @_;
    use FileHandle;

    print "Running test $file\n";
    my $fh = new FileHandle( "$testDir/$file", "w" )
      || die "can't write to $file - $!\n";
    my $res =
      TWiki::Plugins::TWikiReleaseTrackerPlugin::handleDiffWiki($testString);
    print $fh $res;
    close $fh;
}

sub compareResult {
    my ($test) = @_;
    my ( $actual, $correct ) =
      ( "$testDir/$test.actualResults", "$testDir/$test.correctResults" );
    my $res = `diff $actual $correct`;

    print $res;
    if ( $res ne "" ) {
        return "fail";
    }
}

sub runTests {
    saveResult( "test1.actualResults",
'indexTopic="System.TRTTestSuite" from="localInstallation" statusFilter="all"'
    );
    compareResult("test1");
    saveResult( "test2.actualResults",
'from="distroNone" indexTopic="System.TRTTestSuite" to="distro1" statusFilter="all'
    );
    compareResult("test2");
    saveResult( "test3.actualResults",
'from="localInstallation" indexTopic="System.TRTTestSuite" to="distro1" statusFilter="all'
    );
    compareResult("test3");
    saveResult( "test4.actualResults",
'from="distro1" indexTopic="System.TRTTestSuite" to="localInstallation" statusFilter="all'
    );
    compareResult("test4");
    saveResult( "test5.actualResults",
'from="distro2" indexTopic="System.TRTTestSuite" to="localInstallation" statusFilter="all'
    );
    compareResult("test5");
}

runTests();

# NB. This really ought to create attachments, but there is no API to do so.
symlinkFromInstallToTestDir();
