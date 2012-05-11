use strict;

package CReadTest;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use TWiki::Plugins::WebDAVPlugin;
use TWiki::Plugins::WebDAVPlugin::Permissions;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

use vars qw( $tmpdir );

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $tmpdir = "/tmp/$$";
    mkdir($tmpdir);
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    `rm -rf $tmpdir`;
}

my $dv     = "   IdiotChild";
my $dvtest = "|IdiotChild|";
my $av     = "SpawnOfAsses,  SonOfSwine,MadGroup        ";
my $avtest = "|SpawnOfAsses|SonOfSwine|MadGroup|";
my $dt     = "   BrainlessGit,   Thicko         ";
my $dttest = "|BrainlessGit|Thicko|";

# set to 4 for full DB dumps for debug
my $dbdump = 0;

sub check {
    my ( $this, $check, $exp ) = @_;
    my $status =
`export LD_LIBRARY_PATH=/usr/local/lib;./accesscheck $check $tmpdir/TWiki $dbdump`;
    if ( $status !~ /$exp\s*$/ ) {
        chop($status);
        $this->assert( 0,
            "Access '$check' is $status; should be $exp; called from "
              . join( ":", caller ) );
    }
}

sub dumpdb {
    my %hash;
    tie( %hash, 'TDB_File', "$tmpdir/TWiki", Fcntl::O_RDONLY, 0666 )
      || die "$!";
    print STDERR "DB DUMP:\n";
    foreach my $key ( keys %hash ) {
        print STDERR "$key => $hash{$key}\n";
    }
    untie(%hash);
}

sub test__open_access {
    my $this = shift;
    my $db   = new TWiki::Plugins::WebDAVPlugin::Permissions($tmpdir);

    $db->processText( "Web", "Topic", "" );
    $db = undef;
    $this->check( "- - - V atv1",    "permitted" );
    $this->check( "Web - - V atv1",  "permitted" );
    $this->check( "Web Topic - V -", "permitted" );
}

sub test__topic {
    my $this = shift;
    my $db   = new TWiki::Plugins::WebDAVPlugin::Permissions($tmpdir);

    $db->processText( "Web", "Topic",
            "\t* Set DENYTOPICVIEW = dtv\n"
          . "\t* Set ALLOWTOPICVIEW = atv1,atv2" );

    $db = undef;    # force close
    $this->check( "Web Topic - V atv1", "permitted" );
    $this->check( "Web Topic - V atv2", "permitted" );
    $this->check( "Web Topic - V dtv",  "denied" );
    $this->check( "Web Topic - V atv",  "denied" );
}

sub test__web_topic {
    my $this = shift;
    my $db   = new TWiki::Plugins::WebDAVPlugin::Permissions($tmpdir);

    $db->processText( "Web", "Topic",
            "\t* Set DENYTOPICVIEW = dtv\n"
          . "\t* Set ALLOWTOPICVIEW = atv1,atv2,atv3" );
    $db->processText( "Web", "WebPreferences", "\t* Set DENYWEBVIEW = atv1\n" );

    $db = undef;    # force close
    $this->check( " Web Topic - V atv1", "denied" );
    $this->check( " Web Topic - V atv2", "permitted" );
}

sub test__all_web_topic {
    my $this = shift;
    my $db   = new TWiki::Plugins::WebDAVPlugin::Permissions($tmpdir);

    $db->processText( "Web", "Topic",
            "\t* Set DENYTOPICVIEW = dtv\n"
          . "\t* Set ALLOWTOPICVIEW = atv1,atv2,atv3" );
    $db->processText( "Web", "WebPreferences", "\t* Set DENYWEBVIEW = atv1\n" );
    $db->processText( "TWiki", "DefaultPreferences",
        "\t* Set DENYWEBVIEW = atv2\n" );
    $db = undef;    # force close

    $this->check( "Web Topic - V atv1", "denied" );
    $this->check( "Web Topic - V atv2", "denied" );
    $this->check( "Web Topic - V atv3", "permitted" );
}

sub test__deny_global_group {
    my $this = shift;
    my $db   = new TWiki::Plugins::WebDAVPlugin::Permissions($tmpdir);

    $db->processText( "TWiki", "DefaultPreferences",
        "\t* Set DENYWEBVIEW = UsGroup\n" );
    $db->processText( "Main", "UsGroup", "\t* Set GROUP = me,us,ThemGroup\n" );
    $db->processText( "Main", "ThemGroup", "\t* Set GROUP = her,him\n" );
    $db = undef;    # force close
    $this->check( "Web Topic - V agent", "permitted" );
    $this->check( "Web Topic - V her",   "denied" );
    $this->check( "Web Topic - V him",   "denied" );
    $this->check( "Web Topic - V me",    "denied" );
    $this->check( "Web Topic - V us",    "denied" );
}

sub test__change_default {
    my $this = shift;
    my $db   = new TWiki::Plugins::WebDAVPlugin::Permissions($tmpdir);
    $db->processText( "Web", "Topic", "\t* Set DENYTOPICCHANGE = dtv\n" );
    $db = undef;    # force close

    $this->check( "- - file.dat C her",       "denied" );
    $this->check( "- Topic - C him",          "denied" );
    $this->check( "- Topic file.dat C her",   "denied" );
    $this->check( "Web - - C her",            "denied" );
    $this->check( "Web - file.dat C him",     "denied" );
    $this->check( "Web Topic - C him",        "denied" );
    $this->check( "Web Topic file.dat C him", "permitted" );
    $this->check( "Web Topic file.dat C dtv", "denied" );
}

1;
