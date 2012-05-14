use strict;

package TemplateToolkitPluginTests;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use strict;
use TWiki;
use CGI;

my $twiki;

my $tt_tag_on      = '%TEMPLATETOOLKIT{"on"}%';
my $tt_tag_ff      = '%TEMPLATETOOLKIT{"off"}%';
my $tt_tag_wrapper = '%TEMPLATETOOLKIT{"on" WRAPPER="testwrapper"}%';
my $tt_text        = '[% SET TTvar = "value"; TTvar %]';
my $tt_result      = 'value';

my %delimiter_judo = (
    '[[%TTvar%]]'              => '[[%TTvar%]]',
    '[[[%TTvar%]]]'            => '[[value]]',
    '[[%TTvar%/X][Y/%TTvar%]]' => '[[%TTvar%/X][Y/%TTvar%]]',
    '[[%TTvar%][%TTvar%]]'     => '[[%TTvar%][%TTvar%]]',
    '[[[%TTvar%]][[%TTvar%]]]' => '[[value][value]]',
);

# Dummy values needed by TWiki interfaces, but irrelevant to the tests
my $web        = 'TestWeb';
my $topic      = 'TestTopic';
my $user       = 'WikiGuest';
my $installWeb = 'TWiki';

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $twiki                   = TWiki->new();
    $TWiki::Plugins::SESSION = $twiki;
}

sub tear_down {
    my $this = shift;
    $twiki->finish();
    $this->SUPER::tear_down();
}

use TWiki::Plugins::TemplateToolkitPlugin;
use TWiki::Func;

sub test_TT_creation {
    my $this = shift;

    $TWiki::Plugins::TemplateToolkitPlugin::tt = undef;
    TWiki::Plugins::TemplateToolkitPlugin::_create_TT();
    $this->assert( $TWiki::Plugins::TemplateToolkitPlugin::tt,
        "failed to create the TT object" );
}

# ----------------------------------------------------------------------
# Purpose:          Test basic TT handling with TT switched on in config
# Verifies:         TT expansion
sub test_postRenderingHandler {
    my $this = shift;

    $TWiki::cfg{Plugins}{TemplateToolkitPlugin} = { UseTT => 1 };
    my $text = $tt_text;

    $twiki->enterContext('body_text');
    TWiki::Plugins::TemplateToolkitPlugin::initPlugin( $topic, $web, $user,
        $installWeb );
    TWiki::Plugins::TemplateToolkitPlugin::postRenderingHandler($text);
    $this->assert_str_equals( $tt_result, $text );
}

# ----------------------------------------------------------------------
# Purpose:          Test overriding a false config value by a tag
# Verifies:         * Elimination of TEMPLATETOOLKIT tag
#                   * TT expansion
sub test_tt_on {
    my $this = shift;

    # make sure to use module defaults
    delete $TWiki::cfg{Plugins}{TemplateToolkitPlugin};
    my $text = "$tt_tag_on$tt_text";

    $twiki->enterContext('body_text');
    TWiki::Plugins::TemplateToolkitPlugin::initPlugin( $topic, $web, $user,
        $installWeb );
    $twiki->_expandAllTags( \$text, $web, $topic );
    $this->assert_str_equals( $tt_text, $text );
    TWiki::Plugins::TemplateToolkitPlugin::postRenderingHandler($text);
    $this->assert_str_equals( $tt_result, $text );
}

# ----------------------------------------------------------------------
# Purpose:          Test DWIM on TT versus TWiki variables
# Verifies:         * Protection of TWiki forced links
#                   * Insertion into triple brackets
#                   * TTvar not defined as TWiki Var
sub test_delimiter_judo {
    my $this = shift;

    $TWiki::cfg{Plugins}{TemplateToolkitPlugin} = { UseTT => 1 };

    $twiki->enterContext('body_text');
    TWiki::Plugins::TemplateToolkitPlugin::initPlugin( $topic, $web, $user,
        $installWeb );

    while ( my ( $before, $after ) = each %delimiter_judo ) {
        my $text = "$tt_text$before";
        $twiki->_expandAllTags( \$text, $web, $topic );
        $this->assert_str_equals( "$tt_text$before", $text );
        TWiki::Plugins::TemplateToolkitPlugin::postRenderingHandler($text);
        $this->assert_str_equals( "$tt_result$after", $text );
    }
}

1;
