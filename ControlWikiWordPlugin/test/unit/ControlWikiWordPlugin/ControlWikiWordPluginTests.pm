use strict;

package ControlWikiWordPluginTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

#use base qw(FoswikiTestCase);

use strict;

#use Foswiki::UI::Save;
use Error qw( :try );
use Foswiki::Plugins;
use Foswiki::Plugins::ControlWikiWordPlugin;

my $expected;
my $source;

#my $foswiki;

sub new {
    my $self = shift()->SUPER::new( 'ControlWikWordPluginFunctions', @_ );
    return $self;
}

sub setLocalSite {
    $Foswiki::cfg{Plugins}{ControlWikWordPlugin}{Enabled} = 1;
    $Foswiki::cfg{Plugins}{ControlWikiWordPlugin}{Module} =
      'Foswiki::Plugins::ControlWikiWordPlugin';
    $Foswiki::cfg{Plugins}{ControlWikiWordPlugin}{SingletonWords} = {
        '(?:Item[[:digit:]]{3,6})'                         => 'Tasks',
        '(?:Question[[:digit:]]{3,5}|FAQ[[:digit:]]{1,3})' => 'Support',
        '(?:Plugins)'                                      => ''
    };
}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig();
    setLocalSite();
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    my $query;
    eval {
        require Unit::Request;
        require Unit::Response;
        $query = new Unit::Request("");
    };
    if ($@) {
        $query = new CGI("");
    }
    $query->path_info( "/" . $this->{test_web} . "/TestTopic" );
    $this->{session}->finish() if ( defined( $this->{session} ) );
    $this->{session} = new Foswiki( undef, $query );
    $Foswiki::Plugins::SESSION = $this->{session};

    $Foswiki::cfg{LocalSitePreferences} = "$this->{users_web}.SitePreferences";

    Foswiki::Func::setPreferencesValue( 'CONTROLWIKIWORDPLUGIN_DEBUG', '1' );
}

sub doTest {
    my ( $this, $source, $expected, $assertFalse ) = @_;

    _trimSpaces($source);
    _trimSpaces($expected);

    #print " SOURCE = $source  EXPECTED = $expected \n";

    Foswiki::Plugins::ControlWikiWordPlugin::initPlugin( "TestTopic",
        $this->{test_web}, "MyUser", "System" );
    Foswiki::Plugins::ControlWikiWordPlugin::preRenderingHandler( $source,
        $this->{test_web} );

    #print " RENDERED = $source \n";
    if ($assertFalse) {
        $this->assert_str_not_equals( $expected, $source );
    }
    else {
        $this->assert_str_equals( $expected, $source );
    }
}

=pod

---++ .Singleton tests  

=cut

# ########################################################
# Verify that .Singleton can be enabled & disabled
# ########################################################
sub test_dotSingletonDisables {
    my $this = shift;

    Foswiki::Func::setPreferencesValue(
        'CONTROLWIKIWORDPLUGIN_DOTSINGLETONENABLE', "0" );
    Foswiki::Func::setPreferencesValue( 'NOAUTOLINK', '0' );

    $source = <<END_SOURCE;
Test .Singleton Word
END_SOURCE

    $expected = <<END_EXPECTED;
Test [[$this->{test_web}.Singleton][Singleton]] Word
END_EXPECTED

    $this->doTest( $source, $expected, 1 );

    Foswiki::Func::setPreferencesValue(
        'CONTROLWIKIWORDPLUGIN_DOTSINGLETONENABLE', "1" );

    $this->doTest( $source, $expected, 0 );

}

# ########################################################
# Verify that NOAUTOLINK and <noautolink> are  honored
# ########################################################

sub test_dotSingletonNOAUTOLINK {
    my $this = shift;

    Foswiki::Func::setPreferencesValue(
        'CONTROLWIKIWORDPLUGIN_DOTSINGLETONENABLE', "1" );

    $source = <<END_SOURCE;
Test .Singleton Word
END_SOURCE

    $expected = <<END_EXPECTED;
Test [[$this->{test_web}.Singleton][Singleton]] Word
END_EXPECTED

    Foswiki::Func::setPreferencesValue( 'NOAUTOLINK', '1' );
    $this->doTest( $source, $expected, 1 );
    Foswiki::Func::setPreferencesValue( 'NOAUTOLINK', '0' );

    $source = <<END_SOURCE;
Test <noautolink>  .Singleton  </noautolink> Word
END_SOURCE
    $this->doTest( $source, $expected, 1 );

}

# ########################################################
# Verify that links are blocked by ! and <nop>
# ########################################################

sub test_dotSingletonBlockLink {
    my $this = shift;

    Foswiki::Func::setPreferencesValue(
        'CONTROLWIKIWORDPLUGIN_DOTSINGLETONENABLE', "1" );
    Foswiki::Func::setPreferencesValue( 'NOAUTOLINK', '0' );

    $source = <<END_SOURCE;
Test !.Singleton Word
END_SOURCE
    $expected = $source;

    $this->doTest( $source, $expected, 0 );

    $source = <<END_SOURCE;
Test <nop>.Singleton Word
END_SOURCE
    $expected = $source;

    $this->doTest( $source, $expected, 0 );

}

# ########################################################
# Verify that existing links are not modified
# ########################################################

sub test_dotSingletonExistingLinks {
    my $this = shift;

    Foswiki::Func::setPreferencesValue(
        'CONTROLWIKIWORDPLUGIN_DOTSINGLETONENABLE', "1" );
    Foswiki::Func::setPreferencesValue( 'NOAUTOLINK', '0' );

    $source = <<END_SOURCE;
Test [[MyLink][With .Singleton Word]]  Link
END_SOURCE
    $expected = $source;

    $this->doTest( $source, $expected, 0 );

    $source = <<END_SOURCE;
Test <a href=http://blah.com/asdf>Text with .Singleton Word</a> Test
END_SOURCE
    $expected = $source;

    $this->doTest( $source, $expected, 0 );

}

=pod

---++ Stop WikiWord Link tests  

=cut

# ########################################################
# Verify that WikiWords are blocked
# ########################################################
sub test_BlockWikiWordTest {
    my $this = shift;

    Foswiki::Func::setPreferencesValue( 'NOAUTOLINK', '0' );

    $source = <<END_SOURCE;
Test WikiWord, MacDonald Farm  Word FiSa/AML
END_SOURCE

    $expected = <<END_EXPECTED;
Test <nop>WikiWord, <nop>MacDonald Farm  Word <nop>FiSa/AML
END_EXPECTED

    # Verify blocks with plugin setting

    # Note that the short preference takes prescedence so need to clear.
    Foswiki::Func::setPreferencesValue( 'STOPWIKIWORDLINK', '' );
    Foswiki::Func::setPreferencesValue(
        'CONTROLWIKIWORDPLUGIN_STOPWIKIWORDLINK',
        'MacDonald, WikiWord, MyTest, FiSa',
    );
    $this->doTest( $source, $expected, 0 );

# Verify blocks with simple setting, and simple setting takes precedence over Plugin setting

    Foswiki::Func::setPreferencesValue(
        'CONTROLWIKIWORDPLUGIN_STOPWIKIWORDLINK', 'MacDonald' );
    Foswiki::Func::setPreferencesValue( 'STOPWIKIWORDLINK',
        'WikiWord, MyTest' );

    $expected = <<END_EXPECTED;
Test <nop>WikiWord, MacDonald Farm  Word FiSa/AML
END_EXPECTED

    $this->doTest( $source, $expected, 0 );

    # Verify blocks with setting from prior plugin

    Foswiki::Func::setPreferencesValue(
        'CONTROLWIKIWORDPLUGIN_STOPWIKIWORDLINK', '' );
    Foswiki::Func::setPreferencesValue( 'STOPWIKIWORDLINK', '' );
    Foswiki::Func::setPreferencesValue(
        'STOPWIKIWORDLINKPLUGIN_STOPWIKIWORDLINK',
        'WikiWord, MyTest' );

    $this->doTest( $source, $expected, 0 );

}

=pod

---++ Stop WikiWord Link - prefix test (Item8720)

=cut

# ########################################################
# Verify that WikiWords are blocked
# ########################################################
sub test_PrefixStop_Item8720 {
    my $this = shift;

    Foswiki::Func::setPreferencesValue( 'NOAUTOLINK', '0' );

    $source = <<END_SOURCE;
Test MacDonald but not MacDonalds Farm 
END_SOURCE

    $expected = <<END_EXPECTED;
Test <nop>MacDonald but not MacDonalds Farm 
END_EXPECTED

    # Verify blocks with plugin setting

    Foswiki::Func::setPreferencesValue(
        'CONTROLWIKIWORDPLUGIN_STOPWIKIWORDLINK',
        'MacDonald, WikiWord, MyTest' );
    $this->doTest( $source, $expected, 0 );

    # Verify blocks with simple punctuation

    $source = <<END_SOURCE;
Test (MacDonald) and MacDonald, but not MacDonalds Farm 
END_SOURCE

    $expected = <<END_EXPECTED;
Test (<nop>MacDonald) and <nop>MacDonald, but not MacDonalds Farm 
END_EXPECTED

    $this->doTest( $source, $expected, 0 );

}

# ########################################################
# Verify that rules based wikiwords are linked
# ########################################################

sub test_RulesBasedWikiWords {
    my $this = shift;

    Foswiki::Func::setPreferencesValue(
        'CONTROLWIKIWORDPLUGIN_STOPWIKIWORDLINK', '' );
    Foswiki::Func::setPreferencesValue( 'STOPWIKIWORDLINK', '' );
    Foswiki::Func::setPreferencesValue(
        'STOPWIKIWORDLINKPLUGIN_STOPWIKIWORDLINK', '' );

    setLocalSite();

    $source = <<END_SOURCE;
Test Item123 and FAQ23 Test
Test Plugins
END_SOURCE

    $expected = <<END_EXPECTED;
Test [[Tasks.Item123][Item123]] and [[Support.FAQ23][FAQ23]] Test
Test [[$this->{test_web}.Plugins][Plugins]]
END_EXPECTED

    $this->doTest( $source, $expected, 0 );

    # And verify that ! and <nop> are honored

    $source = <<END_SOURCE;
Test !Item123 and <nop>FAQ23 Test
END_SOURCE
    $expected = $source;

    $this->doTest( $source, $expected, 0 );
}

# ########################################################
# Verify that Acronym linking can be controlled
# ########################################################

sub test_AcronymLimits {
    my $this = shift;

    Foswiki::Func::setPreferencesValue( 'CONTROLWIKIWORDPLUGIN_LIMITACRONYMS',
        '1' );

    setLocalSite();

    # Create the topic named HTML to verify 2nd Acronym link.
    Foswiki::Func::saveTopicText( $this->{test_web}, "HTML", <<NONNY );
  TESTING 1 2 3 4 
NONNY

    $source = <<END_SOURCE;
Test HTML, HTTP  and HTML and [[HTML]] Test
END_SOURCE

    $expected = <<END_EXPECTED;
Test HTML, HTTP  and <nop>HTML and [[HTML]] Test
END_EXPECTED

    $this->doTest( $source, $expected, 0 );

}

# ####################
# Utility Functions ##
# ####################

sub _trimSpaces {

    #my $text = $_[0]

    $_[0] =~ s/^[[:space:]]+//s;    # trim at start
    $_[0] =~ s/[[:space:]]+$//s;    # trim at end
}

1;
