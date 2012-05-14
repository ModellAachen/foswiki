package AttributeParserTests;
use base qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Foswiki::Plugins::FreeMarkerPlugin::AttributeParser;

my $DEBUG              = 0;
my $PARSER_DEBUG       = $DEBUG ? 0x1F : 0;
my $PARSER_DEBUG_LEVEL = $DEBUG ? 0x1F : 0;

sub new {
    my $self = shift()->SUPER::new( 'AttributeParserTests', @_ );
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
}

=pod

=cut

sub test_empty {
    my ($this) = @_;

    my $template;
    my $parser;
    my $data;
    my $result;
    my $expected;

    $template = '';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::AttributeParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $data                 = $parser->parse($template);

    $result   = $data;
    $expected = {};

    $this->assert( scalar keys %{$result} == scalar keys %{$expected} );
}

=pod

=cut

sub test_string {
    my ($this) = @_;

    my $template;
    my $parser;
    my $data;
    my $result;
    my $expected;

    $template = '"hello"';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::AttributeParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $data                 = $parser->parse($template);

    $result   = $data;
    $expected = 'hello';

    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_string_no_quotes {
    my ($this) = @_;

    my $template;
    my $parser;
    my $data;
    my $result;
    my $expected;

    $template = 'a!';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::AttributeParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $data                 = $parser->parse($template);

    $result   = $data;
    $expected = 'a!';

    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_string_spaces {
    my ($this) = @_;

    my $template;
    my $parser;
    my $data;
    my $result;
    my $expected;

    $template = '   hello    ';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::AttributeParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $data                 = $parser->parse($template);

    $result   = $data;
    $expected = 'hello';

    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_string_addition {
    my ($this) = @_;

    my $template;
    my $parser;
    my $data;
    my $result;
    my $expected;

    $template = '"hello"+" "+"goodbye"';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::AttributeParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $data                 = $parser->parse($template);

    $result   = $data;
    $expected = 'hello goodbye';

    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_number {
    my ($this) = @_;

    my $template;
    my $parser;
    my $data;
    my $result;
    my $expected;

    $template = '-99.99';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::AttributeParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $data                 = $parser->parse($template);

    $result   = $data;
    $expected = -99.99;

    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_boolean {
    my ($this) = @_;

    my $template;
    my $parser;
    my $data;
    my $result;
    my $expected;

    $template = 'true';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::AttributeParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $data                 = $parser->parse($template);

    $result   = $data;
    $expected = 1;

    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    $template = 'false';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::AttributeParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $data                 = $parser->parse($template);

    $result   = $data;
    $expected = 0;

    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_array_strings {
    my ($this) = @_;

    my $template;
    my $parser;
    my $data;
    my $result;
    my $expected;

    $template = '["winter", "spring", "summer", "autumn"]';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::AttributeParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $data                 = $parser->parse($template);

    $result   = $data->[0];
    $expected = 'winter';

    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_array_strings_no_quotes {
    my ($this) = @_;

    my $template;
    my $parser;
    my $data;
    my $result;
    my $expected;

    $template = '[winter, spring, summer, autumn]';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::AttributeParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $data                 = $parser->parse($template);

    $result   = $data->[0];
    $expected = 'winter';

    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_array_mixed {
    my ($this) = @_;

    my $template;
    my $parser;
    my $data;
    my $result;
    my $expected;

    $template = '[10, spring, 10+10, "autumn"]';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::AttributeParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $data                 = $parser->parse($template);

    $result   = $data->[2];
    $expected = 20;

    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_hash {
    my ($this) = @_;

    my $template;
    my $parser;
    my $data;
    my $result;
    my $expected;

    $template = '{color:red, value:255}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::AttributeParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $data                 = $parser->parse($template);

    $result   = $data->{value};
    $expected = 255;

    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_list_of_hashes {
    my ($this) = @_;

    my $template;
    my $parser;
    my $data;
    my $result;
    my $expected;

    $template = '[{"color":"red", "value":255},{color:green, "value":100}]';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::AttributeParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $data                 = $parser->parse($template);

    $result   = $data->[1]->{color};
    $expected = 'green';

    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_hash_with_lists {
    my ($this) = @_;

    my $template;
    my $parser;
    my $data;
    my $result;
    my $expected;

    $template = '{colors:[red,blue,green], values:[-1,0,1]}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::AttributeParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $data                 = $parser->parse($template);

    $result   = $data->{colors}->[2];
    $expected = 'green';

    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_hash_with_lists2 {
    my ($this) = @_;

    my $template;
    my $parser;
    my $data;
    my $result;
    my $expected;

    $template =
"{ users: [ 'Joe',    'Fred' ], admins: [ 'Julia',  'Kate' ], children: [ 'Mickey', 'Rooney' ]}";
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::AttributeParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $data                 = $parser->parse($template);

    $result   = $data->{admins}->[1];
    $expected = 'Kate';

    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

# HELPER FUNCTIONS

sub _dump {
    my ($data) = @_;

    use Data::Dumper;
    print "data=" . Dumper($data);
}

1;
