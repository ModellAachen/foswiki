use strict;

package MacrosTest;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use TWiki::Store;
use TWiki::Func;

use TWiki::Plugins::MacrosPlugin;

use CGI;

my $testweb  = "TemporaryTestMacrosPlugin";
my $testweb2 = "TemporaryTestMacrosPluginTwo";
my $twiki;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $twiki = new TWiki("TestUser1");

    $twiki->{store}->createWeb( $twiki->{user}, $testweb );
    $twiki->{store}->createWeb( $twiki->{user}, $testweb2 );
    $TWiki::Plugins::SESSION = $twiki;

    TWiki::Func::saveTopicText( $testweb, "MacroA",
        'A%CALLMACRO{topic=%t%,x="0",y=1}%A' );
    TWiki::Func::saveTopicText( $testweb, "MacroB",
        'B%CALLMACRO{topic=%t%,x="%x%%y%",y=2}%' );
    TWiki::Func::saveTopicText( $testweb,  "MacroC", 'C%x%C%y%C' );
    TWiki::Func::saveTopicText( $testweb2, "MacroD", "D%x%\nD\n%y%D\n%STRIP%" );
    $twiki->{webName} = $testweb;
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $twiki->{store}->removeWeb( $twiki->{user}, $testweb );
    $twiki->{store}->removeWeb( $twiki->{user}, $testweb2 );
}

sub testSimple {
    my $this = shift;
    my $tst;

    $tst = "%CALLMACRO{topic=$testweb2.MacroD,x=1,y=2}%";
    TWiki::Plugins::MacrosPlugin::commonTagsHandler( $tst, "T", $testweb );
    $this->assert_str_equals( "D1D2D", $tst );

    $tst = "%CALLMACRO{topic=$testweb2/MacroD,x=1,y=2}%";
    TWiki::Plugins::MacrosPlugin::commonTagsHandler( $tst, "T", $testweb );
    $this->assert_str_equals( "D1D2D", $tst );

    $tst = "%CALLMACRO{topic=MacroC,x=1,y=2}%";
    TWiki::Plugins::MacrosPlugin::commonTagsHandler( $tst, "T", $testweb );
    $this->assert_str_equals( "C1C2C", $tst );
}

sub testPassthrough {
    my $this = shift;
    my $tst;

    $tst = "%CALLMACRO{topic=MacroA,t=MacroC}%";
    TWiki::Plugins::MacrosPlugin::commonTagsHandler( $tst, "T", $testweb );
    $this->assert_str_equals( "AC0C1CA", $tst );

    $tst = "%CALLMACRO{topic=MacroA,t=$testweb2.MacroD}%";
    TWiki::Plugins::MacrosPlugin::commonTagsHandler( $tst, "T", $testweb );
    $this->assert_str_equals( "AD0D1DA", $tst );
}

sub testNoSuchMacro {
    my $this = shift;
    my $tst  = "%CALLMACRO{topic=MacroA}%";
    TWiki::Plugins::MacrosPlugin::commonTagsHandler( $tst, "T", $testweb );
    $this->assert_matches(
qr/^A <font color=red> No such macro %t% in CALLMACRO{topic=%t%,x="0",y=1} <\/font> A/,
        $tst
    );
}

sub testSimpleSet {
    my $this = shift;

    my $tst = "X\n%SET Y = 10\nY\n%Y%\n";
    TWiki::Plugins::MacrosPlugin::commonTagsHandler( $tst, "T", $testweb );
    $this->assert_str_equals( "XY\n10\n", $tst );

    $tst = "%SET Y = 10\nY\n%Y%\n";
    TWiki::Plugins::MacrosPlugin::commonTagsHandler( $tst, "T", $testweb );
    $this->assert_str_equals( "Y\n10\n", $tst );

    $tst = "X\n%SET Y = 10\n";
    TWiki::Plugins::MacrosPlugin::commonTagsHandler( $tst, "T", $testweb );
    $this->assert_str_equals( "X", $tst );
}

1;
