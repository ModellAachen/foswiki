use strict;
use TDB_File;

package PluginTests;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use TWiki::Plugins::WebDAVPlugin;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

my $tmpdir;
my $testdb;
my $twiki;
my $testweb = "TemporaryDAVPluginTestsWeb";
my $query;

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $query = new CGI("");
    $query->path_info("/$testweb/WebPreferences");
    $twiki = new TWiki( "TestUser1", $query );
    $TWiki::Plugins::SESSION = $twiki;

    $tmpdir = "/tmp/$$";
    $testdb = "$tmpdir/TWiki";
    mkdir($tmpdir);
}

my $dv     = "   IdiotChild";
my $dvtest = "|IdiotChild|";
my $av     = "SpawnOfAsses,  SonOfSwine,MadGroup        ";
my $avtest = "|SpawnOfAsses|SonOfSwine|MadGroup|";
my $dt     = "   BrainlessGit,   Thicko         ";
my $dttest = "|BrainlessGit|Thicko|";

sub test__bad_DB {
    my $this = shift;

    TWiki::Func::saveTopicText(
        $testweb, "WebPreferences", <<HERE
   * Set WEBDAVPLUGIN_LOCK_DB = *
HERE
    );
    $twiki = new TWiki( "TestUser1", $query );
    $TWiki::Plugins::SESSION = $twiki;

    TWiki::Plugins::WebDAVPlugin::initPlugin( "Topic", "Web", "dweeb" );
    TWiki::Plugins::WebDAVPlugin::beforeSaveHandler( "", "Web", "Topic" );

}

sub test__beforeSaveHandler {
    my $this = shift;

    TWiki::Func::saveTopicText(
        $testweb, "WebPreferences", <<HERE
   * Set WEBDAVPLUGIN_LOCK_DB = $tmpdir
HERE
    );
    $twiki = new TWiki( "TestUser1", $query );
    $TWiki::Plugins::SESSION = $twiki;

    TWiki::Plugins::WebDAVPlugin::initPlugin( "Topic", "Web", "dweeb" );
    TWiki::Plugins::WebDAVPlugin::beforeSaveHandler(
"\t* Set DENYTOPICVIEW = $dv\n\t* Set ALLOWTOPICVIEW = $av\n\t* Set DENYTOPICCHANGE = $dt",
        "Web", "Topic"
    );
}
