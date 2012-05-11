use strict;

package ExplicitNumberingPluginTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

#use base qw(FoswikiTestCase);

use strict;

#use Foswiki::UI::Save;
use Error qw( :try );
use Foswiki::Plugins;
use Foswiki::Plugins::ExplicitNumberingPlugin;

my $expected;
my $source;
my $include = 0;

#my $foswiki;

sub new {
    my $self = shift()->SUPER::new( 'ExplicitNumberingPluginFunctions', @_ );
    return $self;
}

sub setLocalSite {
    $Foswiki::cfg{Plugins}{ControlWikWordPlugin}{Enabled} = 1;
    $Foswiki::cfg{Plugins}{ExplicitNumberingPlugin}{Module} =
      'Foswiki::Plugins::ExplicitNumberingPlugin';
    $Foswiki::cfg{Plugins}{ExplicitNumberingPlugin}{SingletonWords} = {
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

    Foswiki::Plugins::ExplicitNumberingPlugin::initPlugin( "TestTopic",
        $this->{test_web}, "MyUser", "System" );
    Foswiki::Plugins::ExplicitNumberingPlugin::commonTagsHandler( $source,
        $this->{test_web}, "TestTopic", $include );

    if ($assertFalse) {
        $this->assert_str_not_equals( $expected, $source );
    }
    else {
        $this->assert_str_equals( $expected, $source );
    }
}

# ########################################################
# Verify simple numbering numbering
# ########################################################
sub test_level1Numbering {
    my $this = shift;
    Foswiki::Func::getContext()->{'view'} = 1;
    $include = 0;

    $source = <<END_SOURCE;
Test ##.
Test ##.
Test ##..
Test ##...
Test ##....
Test ##.....
Test ##.....
Test ##......
Test ##.......
END_SOURCE

    $expected = <<END_EXPECTED;
Test 1
Test 2
Test 2.1
Test 2.1.1
Test 2.1.1.1
Test 2.1.1.1.1
Test 2.1.1.1.2
Test 2.1.1.1.2.1
Test 2.1.1.1.2.2
END_EXPECTED

    $this->doTest( $source, $expected, 0 );
}

# ########################################################
# Verify named sequences are independent, and zero for skipped levels
# ########################################################
sub test_NamedNumbering {
    my $this = shift;
    Foswiki::Func::getContext()->{'view'} = 1;
    $include = 0;

    $source = <<END_SOURCE;
Test ##alpha#.
Test ##beta#.
Test ##alpha#..
Test ##beta#...
Test ##alpha#....
Test ##beta#.....
Test ##alpha#.....
Test ##beta#......
Test ##alpha#.......
END_SOURCE

    $expected = <<END_EXPECTED;
Test 1
Test 1
Test 1.1
Test 1.0.1
Test 1.1.0.1
Test 1.0.1.0.1
Test 1.1.0.1.1
Test 1.0.1.0.1.1
Test 1.1.0.1.1.1
END_EXPECTED

    $this->doTest( $source, $expected, 0 );
}

# ########################################################
# Verify reset of number sequences
# ########################################################
sub test_ResetNumbering {
    my $this = shift;
    Foswiki::Func::getContext()->{'view'} = 1;
    $include = 0;

    $source = <<END_SOURCE;
Test ##3.
Test ##.
Test ##..
Test ##6.
Test ##.
Test ##..
Test ##...
Test ##0..
Test ##..
Test ##...
END_SOURCE

    $expected = <<END_EXPECTED;
Test 3
Test 4
Test 4.1
Test 6
Test 7
Test 7.1
Test 7.1.1
Test 7.0
Test 7.1
Test 7.1.1
END_EXPECTED

    $this->doTest( $source, $expected, 0 );
}

# ########################################################
# Verify simple heading numbering
# ########################################################
sub test_HeadingNumbering {
    my $this = shift;
    Foswiki::Func::getContext()->{'view'} = 1;
    $include = 0;

    $source = <<END_SOURCE;
---# Head
---# Head
---## Head
END_SOURCE

    $expected = <<END_EXPECTED;
---+1  Head
---+2  Head
---++2.1  Head
END_EXPECTED

    $this->doTest( $source, $expected, 0 );
}

# ########################################################
# Verify simple heading in diff context
# ########################################################
sub test_diff_context {
    my $this = shift;
    Foswiki::Func::getContext()->{'diff'} = 1;
    Foswiki::Func::getContext()->{'view'} = 0;
    $include = 0;

    $source = <<END_SOURCE;
---# Head
---# Head
---## Head
END_SOURCE

    $expected = <<END_EXPECTED;
---+1  Head
---+2  Head
---++2.1  Head
END_EXPECTED

    $this->doTest( $source, $expected, 0 );
}

# ########################################################
# Verify Bold heading numbering
# ########################################################
sub test_BoldNumbering {
    my $this = shift;
    Foswiki::Func::getContext()->{'view'} = 1;
    $include = 0;

    Foswiki::Func::setPreferencesValue( 'EXPLICITNUMBERINGPLUGIN_BOLD', "1" );

    $source = <<END_SOURCE;
Test ##.
Test ##..
END_SOURCE

    $expected = <<END_EXPECTED;
Test *1*
Test *1.1*
END_EXPECTED

    $this->doTest( $source, $expected, 0 );
}

# ########################################################
# Verify alpha numbering with wrap
# ########################################################
sub test_AlphaSequenceWrap {
    my $this = shift;
    Foswiki::Func::getContext()->{'view'} = 1;
    $include = 0;

    Foswiki::Func::setPreferencesValue( 'EXPLICITNUMBERINGPLUGIN_BOLD', "1" );

    Foswiki::Func::setPreferencesValue( 'EXPLICITNUMBERINGPLUGIN_ALPHASEQ',
        'a,b,c,d' );

    $source = <<END_SOURCE;
Test ##.A
Test ##.A
Test ##.A
Test ##.A
Test ##.A
END_SOURCE

    $expected = <<END_EXPECTED;
Test *A*
Test *B*
Test *C*
Test *D*
Test *A*
END_EXPECTED

    $this->doTest( $source, $expected, 0 );
}

# ########################################################
# Verify alpha numbering
# ########################################################
sub test_Alternate_AlphaSequence {
    my $this = shift;
    Foswiki::Func::getContext()->{'view'} = 1;
    $include = 0;

    Foswiki::Func::setPreferencesValue( 'EXPLICITNUMBERINGPLUGIN_BOLD', "1" );

    Foswiki::Func::setPreferencesValue( 'EXPLICITNUMBERINGPLUGIN_ALPHASEQ',
        'z,y,x,w' );

    $source = <<END_SOURCE;
Test ##.A
Test ##.A
END_SOURCE

    $expected = <<END_EXPECTED;
Test *Z*
Test *Y*
END_EXPECTED

    $this->doTest( $source, $expected, 0 );
}

# ########################################################
# Verify disabled if not view or diff
# ########################################################
sub test_disabled_not_view {
    my $this = shift;
    Foswiki::Func::getContext()->{'view'} = 0;
    Foswiki::Func::getContext()->{'diff'} = 0;
    $include = 0;

    Foswiki::Func::setPreferencesValue( 'EXPLICITNUMBERINGPLUGIN_BOLD', "1" );

    Foswiki::Func::setPreferencesValue( 'EXPLICITNUMBERINGPLUGIN_ALPHASEQ',
        'z,y,x,w' );

    $source = <<END_SOURCE;
Test ##.A
Test ##.A
END_SOURCE

    $expected = <<END_EXPECTED;
Test ##.A
Test ##.A
END_EXPECTED

    $this->doTest( $source, $expected, 0 );
}

# ########################################################
# Verify disabled if included topic
# ########################################################
sub test_disabled_include {
    my $this = shift;
    Foswiki::Func::getContext()->{'view'} = 1;
    Foswiki::Func::getContext()->{'diff'} = 0;
    $include = 1;

    Foswiki::Func::setPreferencesValue( 'EXPLICITNUMBERINGPLUGIN_BOLD', "1" );

    Foswiki::Func::setPreferencesValue( 'EXPLICITNUMBERINGPLUGIN_ALPHASEQ',
        'z,y,x,w' );

    $source = <<END_SOURCE;
Test ##.A
Test ##.A
END_SOURCE

    $expected = <<END_EXPECTED;
Test ##.A
Test ##.A
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
