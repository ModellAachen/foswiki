package Foswiki::Plugins::TocPlugin::test::FakeWikiIF;

use strict;
use integer;

use Foswiki::Plugins::TocPlugin::TOC   ();
use Foswiki::Plugins::TocPlugin::TOCIF ();

# Subclass of wiki interface for testing
our @ISA = qw(Foswiki::Plugins::TocPlugin::TOCIF);

my $dataDir;

sub getInterface {
    my ( $class, $web, $topic ) = @_;
    $ENV{PATH} = "/usr/local/bin:/usr/bin:/bin";
    `rm -rf testdata`;
    mkdir "testdata";
    $dataDir = "testdata/data.$web";
    mkdir $dataDir;
    return $class->SUPER::getInterface( $web, $topic );
}

sub topicExists {
    my ( $this, $name ) = @_;
    return -e "$dataDir/$name.txt";
}

sub webDirList {
    my $fl = `cd $dataDir && ls *.txt`;
    $fl =~ s/\.txt//go;
    return split( /\n/, $fl );
}

sub _readFile {
    my ($name) = @_;
    my $data = "";
    undef $/;    # set to read to EOF
    open( IN_FILE, "<$name" ) || die "Failed to open $name";
    $data = <IN_FILE>;
    $/    = "\n";
    close(IN_FILE);
    return $data;
}

sub readTopic {
    my ( $this, $topic ) = @_;
    return _readFile("$dataDir/$topic.txt");
}

sub writeTopic {
    my ( $name, $text ) = @_;
    open( WF, ">$dataDir/$name.txt" ) || die;
    print WF $text;
    close(WF);
}

1;
