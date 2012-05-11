use strict;
use TDB_File;

package WriteReadTest;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use TWiki::Plugins::WebDAVPlugin;
use TWiki::Plugins::WebDAVPlugin::Permissions;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

my $tmpdir;
my $testdb;
my $testweb = "TemporaryWriteReadTestWeb";
my $twiki;

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $twiki                   = new TWiki("TestUser1");
    $TWiki::Plugins::SESSION = $twiki;
    $twiki->{store}->createWeb( $twiki->{user}, $testweb );

    $this->SUPER::set_up();
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

sub checkdb {
    my $this = shift;

    #  $this->assert(-f "$testdb.dir", `ls $testdb*`);
    #  $this->assert(-f "$testdb.pag", `ls $testdb*`);
    $this->assert( -f $testdb, `ls $testdb*` );
}

sub test__topic_controls {
    my $this = shift;

    my $db = new TWiki::Plugins::WebDAVPlugin::Permissions($tmpdir);

    $db->processText( $testweb, "Topic", <<HERE);
   * Set DENYTOPICVIEW = $dv
   * Set ALLOWTOPICVIEW = $av
   * Set DENYTOPICCHANGE = $dt
HERE
    $db = undef;    # force close
    $this->checkdb();

    my %hash;
    tie( %hash, 'TDB_File', $testdb, TDB_File::TDB_DEFAULT, Fcntl::O_RDONLY,
        0666 )
      || die "$testdb $!";
    $this->assert_str_equals( $dvtest, $hash{"P:/$testweb/Topic:V:D"} );
    $this->assert_str_equals( $avtest, $hash{"P:/$testweb/Topic:V:A"} );
    $this->assert_str_equals( $dttest, $hash{"P:/$testweb/Topic:C:D"} );
    untie(%hash);

    $db = new TWiki::Plugins::WebDAVPlugin::Permissions($tmpdir);
    $db->processText( "$testweb", "Topic", "" );
    $db = undef;    # force close
    tie( %hash, 'TDB_File', $testdb, TDB_File::TDB_DEFAULT, Fcntl::O_RDONLY,
        0666 )
      || die "$testdb $!";
    $this->assert_null( $hash{"P:/$testweb/Topic:V:D"} );
    $this->assert_null( $hash{"P:/$testweb/Topic:V:A"} );
    $this->assert_null( $hash{"P:/$testweb/Topic:C:D"} );
}

sub test__web_preferences {
    my $this = shift;
    my $db   = new TWiki::Plugins::WebDAVPlugin::Permissions($tmpdir);

    $db->processText( "$testweb", "WebPreferences", <<HERE);
   * Set DENYWEBVIEW = $dv
      * Set ALLOWWEBVIEW = $av
         * Set DENYTOPICCHANGE = $dt
HERE
    $db = undef;    # force close
    $this->checkdb();

    my %hash;
    tie( %hash, 'TDB_File', $testdb, TDB_File::TDB_DEFAULT, Fcntl::O_RDONLY,
        0666 )
      || die "$testdb $!";
    $this->assert_str_equals( $dvtest, $hash{"P:/$testweb/:V:D"} );
    $this->assert_str_equals( $avtest, $hash{"P:/$testweb/:V:A"} );
    $this->assert_str_equals( $dttest,
        $hash{"P:/$testweb/WebPreferences:C:D"} );
    untie(%hash);

    $db = new TWiki::Plugins::WebDAVPlugin::Permissions($tmpdir);
    $db->processText( "$testweb", "WebPreferences", "" );
    $db = undef;    # force close
    tie( %hash, 'TDB_File', $testdb, TDB_File::TDB_DEFAULT, Fcntl::O_RDONLY,
        0666 )
      || die "$testdb $!";
    $this->assert_null( $hash{"P:/$testweb/:V:D"} );
    $this->assert_null( $hash{"P:/$testweb/:V:A"} );
    $this->assert_null( $hash{"P:/$testweb/WebPreferences:C:D"} );
    untie(%hash);
}

sub test__rewrite {
    my $this = shift;
    my $db   = new TWiki::Plugins::WebDAVPlugin::Permissions($tmpdir);
    $db->processText( "$testweb", "WebPreferences", <<HERE);
   * Set DENYWEBVIEW = $dt
   * Set ALLOWWEBVIEW = $dv
   * Set DENYTOPICCHANGE = $av
HERE

    $db->processText( "$testweb", "WebPreferences", <<HERE);
   * Set DENYWEBVIEW = $dv
   * Set ALLOWWEBVIEW = $av
   * Set DENYTOPICCHANGE = $dt
HERE

    $db = undef;    # force close
    $this->checkdb();

    my %hash;
    tie( %hash, 'TDB_File', $testdb, TDB_File::TDB_DEFAULT, Fcntl::O_RDONLY,
        0666 )
      || die "$testdb $!";
    $this->assert_str_equals( $dvtest, $hash{"P:/$testweb/:V:D"} );
    $this->assert_str_equals( $avtest, $hash{"P:/$testweb/:V:A"} );
    $this->assert_str_equals( $dttest,
        $hash{"P:/$testweb/WebPreferences:C:D"} );
}

sub test__twiki_preferences {
    my $this = shift;
    my $db   = new TWiki::Plugins::WebDAVPlugin::Permissions($tmpdir);

    $db->processText( "TWiki", "DefaultPreferences",
"\t* Set DENYWEBVIEW = $dv\n\t* Set ALLOWWEBVIEW = $av\n\t* Set DENYTOPICCHANGE = $dt"
    );
    $db = undef;    # force close
    $this->checkdb();

    my %hash;
    tie( %hash, 'TDB_File', $testdb, TDB_File::TDB_DEFAULT, Fcntl::O_RDONLY,
        0666 )
      || die "$testdb $!";
    $this->assert_str_equals( $dvtest, $hash{"P:/:V:D"} );
    $this->assert_str_equals( $avtest, $hash{"P:/:V:A"} );
    $this->assert_str_equals( $dttest,
        $hash{"P:/TWiki/DefaultPreferences:C:D"} );
    untie(%hash);

    $db = new TWiki::Plugins::WebDAVPlugin::Permissions($tmpdir);
    $db->processText( "TWiki", "DefaultPreferences", "" );
    $db = undef;    # force close

    tie( %hash, 'TDB_File', $testdb, TDB_File::TDB_DEFAULT, Fcntl::O_RDONLY,
        0666 )
      || die "$testdb $!";
    $this->assert_null( $hash{"P:/:V:D"} );
    $this->assert_null( $hash{"P:/:V:A"} );
    $this->assert_null( $hash{"P:/TWiki/DefaultPreferences:C:D"} );
    untie(%hash);
}

sub test__group {
    my $this = shift;
    my $db   = new TWiki::Plugins::WebDAVPlugin::Permissions($tmpdir);

    $db->processText( "TWiki", "DefaultPreferences",
"\t* Set DENYWEBVIEW = TurfGroup\n\t* Set ALLOWWEBVIEW = Main.SodGroup\n"
    );
    $db->processText( "Main", "SodGroup", "\t* Set GROUP = $av\n" );

    $db = undef;    # force close
    $this->checkdb();

    my %hash;
    tie( %hash, 'TDB_File', $testdb, TDB_File::TDB_DEFAULT, Fcntl::O_RDONLY,
        0666 )
      || die "$testdb $!";
    $this->assert_str_equals( "|Main.SodGroup|", $hash{"P:/:V:A"} );
    $this->assert_str_equals( "|TurfGroup|",     $hash{"P:/:V:D"} );
    $this->assert_str_equals( $avtest,           $hash{"G:SodGroup"} );
}

sub test__open_nonexistent {
    my $this = shift;

    # use illegal pathname
    my $db = new TWiki::Plugins::WebDAVPlugin::Permissions("*");

    eval { $db->processText( $testweb, "Topic", "empty" ); };

    $this->assert_not_null($@);
}

1;
