package FreeMarkerParserTests;
use base qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser;

my $DEBUG              = 0;
my $PARSER_DEBUG       = $DEBUG ? 0x1F : 0;
my $PARSER_DEBUG_LEVEL = $DEBUG ? 0x1F : 0;

my $DEFAULT_TEST_DATA = {
    level1 => 'one!',
    level2 => {
        nested_a => 'abc',
        nested_b => 'def',
        nested_c => { name => 'miriam' }
    },
    list       => [ 'item1', 'item2', 'item3' ],
    nestedlist => [
        {
            name => 'mary',
            ages => [ 10, 20, 30 ]
        },
        {
            name => 'john',
            age  => 32
        }
    ],
    count => -5.013
};

my $COMPLEX_TEST_DATA = {
    pageSummary => {
        memberList => {
            'showHideSummaries' => {
                'hideSummaries' => 'Hide summaries',
                'showSummaries' => 'Show summaries'
            },
            'showHideTypeInfo' => {
                'hideTypeInfo' => 'Hide type info',
                'showTypeInfo' => 'Show type info'
            },
            memberSummaryPart => [
                {
                    '-private' => '0',
                    'item'     => [
                        {
                            '-private' => '',
                            'typeInfo' => {
                                'typeInfoString' => '(inObjects:Array = null)',
                                'summary' => 'Creates a new array enumerator. ',
                                '-member' => ''
                            },
                            'id'    => 'ArrayEnumerator',
                            'title' => 'ArrayEnumerator'
                        }
                    ],
                    'title' => 'Constructor'
                },
                {
                    '-private' => '0',
                    'item'     => [
                        {
                            '-private' => '',
                            'typeInfo' => {
                                'typeInfoString' => '(inObjects:Array) : void',
                                'summary' =>
                                  'Stores a pointer to array inArray.',
                                '-member' => ''
                            },
                            'id'    => 'setObjects',
                            'title' => 'setObjects'
                        },
                        {
                            '-private' => '',
                            'typeInfo' => {
                                'typeInfoString' => '() : *',
                                'summary' =>
'Retrieves the object from the array at the current pointer location.',
                                '-member' => ''
                            },
                            'id'    => 'getCurrentObject',
                            'title' => 'getCurrentObject'
                        },
                        {
                            '-private' => '',
                            'typeInfo' => {
                                'typeInfoString' => '() : *',
                                'summary' =>
'Increments the location pointer by one and returns the object from the array at that location.',
                                '-member' => ''
                            },
                            'id'    => 'getNextObject',
                            'title' => 'getNextObject'
                        },
                        {
                            '-private' => '',
                            'typeInfo' => {
                                'typeInfoString' => '() : Array',
                                'summary'        => 'Retrieves all objects.',
                                '-member'        => ''
                            },
                            'id'    => 'getAllObjects',
                            'title' => 'getAllObjects'
                        },
                        {
                            '-private' => '',
                            'typeInfo' => {
                                'typeInfoString' => '() : void',
                                'summary' =>
'Puts the enumerator just before the first array item. ',
                                '-member' => ''
                            },
                            'id'    => 'reset',
                            'title' => 'reset'
                        },
                        {
                            '-private' => '',
                            'typeInfo' => {
                                'typeInfoString' => '() : int',
                                '-member'        => ''
                            },
                            'id'    => 'getCurrentLocation',
                            'title' => 'getCurrentLocation'
                        },
                        {
                            '-private' => '',
                            'typeInfo' => {
                                'typeInfoString' => '(inLocation:int) : void',
                                'summary' =>
'Sets the location pointer to a new position.',
                                '-member' => ''
                            },
                            'id'    => 'setCurrentLocation',
                            'title' => 'setCurrentLocation'
                        },
                        {
                            '-private' => '',
                            'typeInfo' => {
                                'typeInfoString' => '(inObject:Object) : void',
                                'summary' =>
'Sets the location pointer to the location (in the array) of inObject.',
                                '-member' => ''
                            },
                            'id'    => 'setCurrentObject',
                            'title' => 'setCurrentObject'
                        }
                    ],
                    'title' => 'Instance methods'
                }
            ]
        }
    }
};

$DEFAULT_TEST_DATA->{book}->{author}->{name} = 'Shakespeare';

sub new {
    my $self = shift()->SUPER::new( 'FreeMarkerParserTests', @_ );
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
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '';

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_string_only {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '
A
';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '
A
';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_string_with_comment {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '
A
<#--this is a comment-->
B
';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '
A
B
';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_string_with_comment_and_html_comment {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '
A
<#--this is a comment-->
<!--this is an HTML comment-->
B
';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '
A
<!--this is an HTML comment-->
B
';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_assign_block {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '
<#assign x>blo</#assign>
${x}
';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parsed;
    $expected = '
blo
';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_assign_block_text_before_after {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '
ABC<#assign x>blo</#assign>XYZ
';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parsed;
    $expected = '
ABCXYZ
';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_assign_expression_array_1 {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '
<#assign seq = ["winter", "spring", "summer", "autumn"]>
${seq[0]}
';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parser->data('seq')->[0];
    $expected = 'winter';

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_assign_expression_array_2 {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '
<#assign seq=[2 * 2, [2 * 5, 20, ["a", "b", "c"]], "whatnot"]>
';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parser->{data}->{'seq'}[0];
    $expected = 4;
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $result   = $parser->{data}->{'seq'}[1][0];
    $expected = 10;
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $result   = $parser->{data}->{'seq'}[1][2][2];
    $expected = 'c';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $result   = $parser->{data}->{'seq'}[2];
    $expected = 'whatnot';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_assign_expression_sequence {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '
<#assign name1="john" name2="paul" name3="george" name4="ringo">
';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parser->{data}->{'name1'};
    $expected = 'john';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    $result   = $parser->{data}->{'name4'};
    $expected = 'ringo';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_assign_expression_number {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '
<#assign n=-9.99>
';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parser->data('n');
    $expected = '-9.99';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_assign_variable {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    my $tmpData = { user => 'Anthony' };
    $template = '<#assign x="Hello ${user}!">${x}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parsed   = $parser->parse( $template, $tmpData );

    $result   = $parsed;
    $expected = 'Hello Anthony!';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_assign_hash_manipulation {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#assign ages = {"Joe":23}>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parser->data()->{ages}->{Joe};
    $expected             = '23';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '<#assign ages = {"Joe":23, "Fred":25}>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parser->data()->{ages}->{Fred};
    $expected             = '25';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template =
      '<#assign ages = {"Joe":23, "Fred":25} + {"Joe":30, "Julia":18}>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parser->data()->{ages}->{Joe};
    $expected             = '30';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_assign_calculation {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#assign test = 10 + 2>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parser->{data}->{test};
    $expected             = '12';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '<#assign test = 10><#assign test = test * 2>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parser->{data}->{test};
    $expected             = '20';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_assign_multiple {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    my $tmpData = { test => 1 };
    $template = '<#assign seasons = ["winter", "spring", "summer", "autumn"]
test = test + 1
>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $tmpData );

    $result   = $parser->{data}->{seasons}->[0];
    $expected = 'winter';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $result   = $parser->{data}->{test};
    $expected = 2;
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_passed_data {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '
level1=${level1}
level2.nested_a=${level2.nested_a}
level2.nested_c.name=${level2.nested_c.name}
list[0]=${list[0]}
nestedlist[0].ages[0]=${nestedlist[0].ages[0]}
list[1-1]=${list[1-1]}
book.author.name=${book.author.name}
book["author"].name=${book["author"].name}
count=${count}
';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = '
level1=one!
level2.nested_a=abc
level2.nested_c.name=miriam
list[0]=item1
nestedlist[0].ages[0]=10
list[1-1]=item1
book.author.name=Shakespeare
book["author"].name=Shakespeare
count=-5.013
';

    _trimSpaces($result);
    _trimSpaces($expected);
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_passed_data_whitespace {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '
book.author.name=${
	book
	.author.
	name
	}
';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = '
book.author.name=Shakespeare
';

    _trimSpaces($result);
    _trimSpaces($expected);
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_assigned {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#assign x0>blo</#assign>${x0}';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parsed;
    $expected = 'blo';

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_assigned2 {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#if headline??>
<h${depth}>${headline}</h${depth}>
</#if>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse(
        $template,
        {
            headline => 'Welcome!',
            depth    => 4
        }
    );

    $result   = $parsed;
    $expected = '<h4>Welcome!</h4>';

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_assigned_inline {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#assign x="blo">${x}';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parsed;
    $expected = 'blo';

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_before_and_after {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = 'A ${"hello"} B';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parsed;
    $expected = 'A hello B';

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_multiple {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template =
'A ${"hello"}${10+2}<#assign x>blo</#assign><#assign y>zzz</#assign>${x}${y} C';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parsed;
    $expected = 'A hello12blozzz C';

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_number_0 {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${0}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parsed;
    $expected = '0';

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_string_simple {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${"hello"}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parsed;
    $expected = 'hello';

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_string_concatenation {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${"Free" + "Marker"}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 'FreeMarker';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_string_variable {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = 'A ${level1} ${"A ${level1}${level1}${level1}${level1} Z"}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = 'A one! A one!one!one!one! Z';

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

Test if a variable can have a string operation command in its name.

=cut

sub test_substitute_string_variable_operations_command {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $data = { htmlTitle => 'Documentation', };

    $template = '${htmlTitle}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $data );

    $result   = $parsed;
    $expected = 'Documentation';

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_sustitute_variable_missing {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = 'Welcome ${user.name!"Mouzer"}!';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = 'Welcome Mouzer!';

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_string_concatenation_with_variable {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = 'Hello ${level2.nested_c.name}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $DEFAULT_TEST_DATA );
    $result   = $parsed;
    $expected = 'Hello miriam';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_string_quoted_single {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = "
\${'It\\'s \"quoted\" and
this is a backslash:\\\\'}
";
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parsed;
    $expected = '
It\'s "quoted" and
this is a backslash:\
';
    _trimSpaces($result);
    _trimSpaces($expected);
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_string_quoted_double {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '
${"Its \"quoted\" and
this is a backslash: \\\"}
';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parsed;
    $expected = '
Its "quoted" and
this is a backslash: \
';
    _trimSpaces($result);
    _trimSpaces($expected);
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_string_escapes {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '
${"A newline \nand \ra carriage return and\n\ta tab and some more and a \l char and a \g char and a \a char and a unicode \x00A9 char"}
';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parsed;
    $expected = '
A newline 
and 
a carriage return and
	a tab and some more and a < char and a > char and a & char and a unicode \x{00A9} char
';
    _trimSpaces($result);
    _trimSpaces($expected);
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

sub TODO_test_substitute_string_escapes_backspace {

}

sub TODO_test_substitute_string_escapes_formfeed {

}

=pod

=cut

sub test_substitute_tag_raw_string {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

=pod
    $template = '
${ "${level1}" }
';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
	$parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug} = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = 'one!';
    _trimSpaces($result);
    _trimSpaces($expected);
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
=cut

    $template = '
${ r"${level1}" }
';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = '${level1}';
    _trimSpaces($result);
    _trimSpaces($expected);
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_calculation_statement {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${+10}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $DEFAULT_TEST_DATA );
    $result   = $parsed;
    $expected = '10';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${-10}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $DEFAULT_TEST_DATA );
    $result   = $parsed;
    $expected = '-10';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_calculation_multiplication_before_addition {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${10 + 2 * 3}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = '16';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_substitute_calculation_modulo {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${51 % 7}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = '2';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

Not implemented and not tested:
- #nested
- #return
- passing calculations: <@test foo="a" bar="b" baaz=5*5-2/>  
- text in between tags:
	<@do_thrice ; x>
		${x} Anything.
	</@do_thrice>
- assignments:
	<@repeat count=4 ; c, halfc, last>
	
=cut

sub test_tag_macro {
    my ($this) = @_;

    my $template;
    my $tmpData;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    # ------------------------------------------------
    # no call
    $template = '<#macro greet>
Hello Joe!
</#macro>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = '';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # call short notation
    $template = '<#macro greet>
Hello Joe!
</#macro>
<@greet/>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = 'Hello Joe!
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # params
    $template = '<#macro greet name call>
${call} ${name}!
</#macro>
<@greet call="Hello" name="Mary"/>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = 'Hello Mary!
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # in list
    $template = '<#macro season name>
The time of year: ${name}
</#macro>
<#list ["winter", "spring", "summer", "autumn"] as x><@season name="${x}"/></#list>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = 'The time of year: winter
The time of year: spring
The time of year: summer
The time of year: autumn
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # in list 2
    $tmpData = {
        seasons => [
            {
                name  => "winter",
                month => "December"
            },
            {
                name  => "spring",
                month => "March"
            },
            {
                name  => "summer",
                month => "June"
            },
            {
                name  => "autumn",
                month => "September"
            }
        ]
    };

    #print "QQQ season 1=" . $tmpData->{seasons}->[0]->{name} . "\n";

    $template = '<#macro season name>
The time of year: ${name}
</#macro>
<#assign showList>
<ul>
<#list seasons as x>
<li>
<@season name="${x.name}"/>
</li>
</#list>
</ul>
</#assign>
${showList}';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $tmpData );

    $result   = $parsed;
    $expected = '<ul>
<li>
The time of year: winter
</li>
<li>
The time of year: spring
</li>
<li>
The time of year: summer
</li>
<li>
The time of year: autumn
</li>
</ul>
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # in list with if
    $template =
      '<#ftl encoding="UTF-8" strip_whitespace="false"><#macro people name len>
<#if len gt 3>
Long name:${name}
<#else>
Short name:${name}
</#if>
</#macro>
<#list ["Bo", "Ann", "Mary", "Roger"] as x><@people name="${x}" len="${x?length}"/></#list>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = '

Short name:Bo
Short name:Ann
Long name:Mary
Long name:Roger';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # pass list
    $template = '<#macro mylist title items>
${title?cap_first}:
<#list items as x>
- ${x?cap_first}
</#list>
</#macro>
<@mylist items=["mouse", "elephant", "python"] title="Animals"/>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = 'Animals:
- Mouse
- Elephant
- Python
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # pass list param
    $tmpData = { animals => [ "mouse", "elephant", "python" ] };

    $template = '<#macro mylist title items>
${title?cap_first}:
<#list items as x>
- ${x?cap_first}
</#list>
</#macro>
<@mylist items=animals title="Animals"/>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $tmpData );

    $result   = $parsed;
    $expected = 'Animals:
- Mouse
- Elephant
- Python
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # pass list param nested
    $tmpData = { animals => { mammals => [ "mouse", "elephant", "cat" ] } };

    $template = '<#macro mylist title items>
${title?cap_first}:
<#list items as x>
- ${x?cap_first}
</#list>
</#macro>
<@mylist items=animals.mammals title="Animals"/>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $tmpData );

    $result   = $parsed;
    $expected = 'Animals:
- Mouse
- Elephant
- Cat
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # pass hash param nested
    $tmpData = {
        data => {
            field => {
                title => "Whole lotta luck",
                date  => 1969
            }
        }
    };

    $template = '<#macro myhash d>
title:${d.title}
</#macro>
<@myhash d=data.field/>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $tmpData );

    $result   = $parsed;
    $expected = 'title:Whole lotta luck
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

=not
    # ------------------------------------------------
	# invalid param
	$tmpData = {
		data => {
			field => {
				title => "Whole lotta luck",
				date => 1969
			}
		}
	};
	
	$template = '<#macro myhash d>
title:${d.title}
</#macro>
<@myhash dunno=data.field/>';
	
	$parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
	$parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
	$parser->{debug}      = $PARSER_DEBUG;
	$parsed = $parser->parse( $template, $tmpData );

	$result   = $parsed;
	$expected = '';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
    
    
    # ------------------------------------------------
	# call
    $template = '<#macro greet>
Hello Joe!
</#macro>
<@greet></@greet>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = 'Hello Joe!
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
=cut

}

=pod

Not implemented: <#break>

=cut

sub test_tag_list {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

=pod
	$template = '<#list ["winter", "spring", "summer", "autumn"] as x></#list>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = '';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
=cut

    # ---
    $template = '<ul>
<#list ["winter", "spring", "summer", "autumn"] as x>
<li>season = <b>${x}</b></li>
</#list>
</ul>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = '<ul>
<li>season = <b>winter</b></li>
<li>season = <b>spring</b></li>
<li>season = <b>summer</b></li>
<li>season = <b>autumn</b></li>
</ul>';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_list_nested {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template =
      '<#list ["winter", "spring", "summer", "autumn"] as x><#list 1..3 as y>
- ${x}, ${y}
</#list></#list>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = '- winter, 1
- winter, 2
- winter, 3
- spring, 1
- spring, 2
- spring, 3
- summer, 1
- summer, 2
- summer, 3
- autumn, 1
- autumn, 2
- autumn, 3
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ----------

    $template = '<#list ["winter", "spring", "summer", "autumn"] as x>
<#if x??>
<#list 1..3 as y>
<#if y??>
- ${x}, ${y}
</#if>
</#list>
</#if>
</#list>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = '- winter, 1- winter, 2- winter, 3
- spring, 1- spring, 2- spring, 3
- summer, 1- summer, 2- summer, 3
- autumn, 1- autumn, 2- autumn, 3
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_list_condensed_format {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#list [1,2,3,4] as x>${x}</#list>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $DEFAULT_TEST_DATA );

    $result   = $parsed;
    $expected = '1234';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_list_access {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    my @values = ( 'gorilla', 'zebra', 'elephant', 'shark' );
    $template = '${zoo[2]}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, { zoo => \@values, } );
    $result   = $parsed;
    $expected = 'elephant';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    my $gorilla;
    $gorilla->{skin} = 'hairy';
    my $zebra;
    $zebra->{skin} = 'striped';
    my $elephant;
    $elephant->{skin} = 'thick';
    my $shark;
    $shark->{skin} = 'smooth';
    my @animals = ( $gorilla, $zebra, $elephant, $shark );

    $template = '${zoo[2].skin}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, { zoo => \@animals, } );
    $result   = $parsed;
    $expected = 'thick';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_list_data_key {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    my $whatnot = { whatnot => { fruits => [ 'pear', 'apple', 'orange' ] } };

    $template = 'I love fruit:
<ul>
<#list whatnot.fruits as fruit>
<li>${fruit}</li>
</#list>
</ul>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $whatnot );
    $result   = $parsed;
    $expected = 'I love fruit:
<ul>
<li>pear</li>
<li>apple</li>
<li>orange</li>
</ul>';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '<#list zoo as animal>
<span>${animal.skin}</span>
</#list>';

    my $gorilla;
    $gorilla->{skin} = 'hairy';
    my $zebra;
    $zebra->{skin} = 'striped';
    my $elephant;
    $elephant->{skin} = 'thick';
    my $shark;
    $shark->{skin} = 'smooth';
    my @animals = ( $gorilla, $zebra, $elephant, $shark );

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, { zoo => \@animals, } );
    $result   = $parsed;
    $expected = '<span>hairy</span>
<span>striped</span>
<span>thick</span>
<span>smooth</span>
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    my $tmpData = { nestedlist => { people => { ages => [ 10, 20, 30 ] } } };

    $template = '<#list nestedlist.people.ages as age>
- ${age}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '- 10
- 20
- 30
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

sub test_list_data_keys_at_different_levels {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    my $tmpData = {
        title    => 'Bedtime Stories',
        chapters => [
            {
                title => 'One',
                page  => 3
            },
            {
                title => 'Two',
                page  => 12
            },
            {
                title => 'Three',
                page  => 19
            }
        ]
    };

    $template = '<#list chapters as chapter>
- ${chapter.title}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '- One
- Two
- Three
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

}

=pod

=cut

sub test_tag_list_array_concatenation {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template =
'<#list ["Joe", "Fred"] + ["Julia", "Kate"] + ["Mickey", "Rooney"] as user>
   * ${user}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parsed;
    $expected = '   * Joe
   * Fred
   * Julia
   * Kate
   * Mickey
   * Rooney
';

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_list_array_data_concatenation {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    my $testData = {
        vars => {
            users    => [ 'Joe',    'Fred' ],
            admins   => [ 'Julia',  'Kate' ],
            children => [ 'Mickey', 'Rooney' ]
        }
    };
    $template = '<#list vars.users + vars.admins + vars.children as person>
   * ${person}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, $testData );

    $result   = $parsed;
    $expected = '   * Joe
   * Fred
   * Julia
   * Kate
   * Mickey
   * Rooney
';

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_list_array_sequence {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    my $testData = { letters => [ 'a', 'b', 'c', 'd', 'e', 'f', 'g' ] };

    $template = '<#list letters[] as letter>
   * ${letter}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $testData );
    $result   = $parsed;
    $expected = '';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '<#list letters[0] as letter>
   * ${letter}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $testData );
    $result   = $parsed;
    $expected = '   * a
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '<#list letters[0..2] as letter>
   * ${letter}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $testData );
    $result   = $parsed;
    $expected = '   * a
   * b
   * c
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '<#list letters[2..0] as letter>
   * ${letter}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $testData );
    $result   = $parsed;
    $expected = '   * c
   * b
   * a
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '<#list letters[3..] as letter>
   * ${letter}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $testData );
    $result   = $parsed;
    $expected = '   * d
   * e
   * f
   * g
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    my $smallData = { letters => ['a'] };
    $template = '<#list letters[0..] as letter>
   * ${letter}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $smallData );
    $result   = $parsed;
    $expected = '   * a
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '<#list letters[..3] as letter>
   * ${letter}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $testData );
    $result   = $parsed;
    $expected = '   * a
   * b
   * c
   * d
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '<#list letters[..3][1] as letter>
   * ${letter}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $testData );
    $result   = $parsed;
    $expected = '   * b
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '<#list letters[3..6][1] as letter>
   * ${letter}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $testData );
    $result   = $parsed;
    $expected = '   * e
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_list_automatic_sequence {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#list 1..3 as n>
   * ${n}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '   * 1
   * 2
   * 3
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '<#list ..2 as n>
   * ${n}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '   * 0
   * 1
   * 2
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '<#list 5..3 as n>
   * ${n}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '   * 5
   * 4
   * 3
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

}

=pod

=cut

sub test_tag_assign_tag_list {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#assign x><#list 1..10 as n>${n}</#list></#assign>${x}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '12345678910';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_assign_tag_list_dynamic_number {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#assign x=3>
<#list 1..x as i>
- ${i}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '- 1
- 2
- 3
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_if {
    my ($this) = @_;

    my $tmpData = {
        x      => 1,
        color  => 'green',
        nested => {
            name  => 'mary',
            ages  => [ 10, 20, 30 ],
            empty => []
        }
    };

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    # ------------------------------------------------
    # ==
    $template = '<#if x == 1>
</#if>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # ==
    $template = '<#if x == 1>
x is 1
</#if>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = 'x is 1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # ==
    $template = '<#if nested.ages[0] == 10>
ok
</#if>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = 'ok';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # eq
    $template = '<#if x eq 1>
x is 1
</#if>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = 'x is 1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # >=
    $template = '<#if x >= 1>1</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # &gt;
    $template = '<#if x &gt; 0>1</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # gt
    $template = '<#if x gt 0>1</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # ( > )
    $template = '<#if (x > 0)>1</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # <
    $template = '<#if x < 2>1</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # lt
    $template = '<#if x lt 2>1</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # &lt;
    $template = '<#if x &lt; 2>1</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # <=
    $template = '<#if x <= 1>1</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # lte
    $template = '<#if x lte 1>1</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # &lte;
    $template = '<#if x &lte; 1>1</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # !=
    $template = '<#if x != 0>1</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # ne
    $template = '<#if x ne 0>1</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # = string
    $template = "<#if color = 'green'>1</#if>";
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # != string
    $template = "<#if color != 'red'>1</#if>";
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # != string
    $template = "A<#if color = 'red'>1</#if>B";
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = 'AB';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # ??
    $template = '<#if x??>
x exists
</#if>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = 'x exists';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # ??
    $template = '<#if q??>
q exists
</#if>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # ?? with empty array: returns exists
    $template = '<#if nested.empty??>
empty array exists
</#if>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = 'empty array exists';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # ?? with array
    $template = '<#if nested.ages??>
array exists
</#if>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = 'array exists';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # ?? with no array: returns missing
    $template = '<#if doesnotexist??>
x exists
</#if>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, { x => undef, } );
    $result   = $parsed;
    $expected = '';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # ?? ,2 conditions
    $template = '<#if xx?? || yy??>
yes
</#if>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse(
        $template,
        {
            xx => 1,
            yy => 1
        }
    );
    $result   = $parsed;
    $expected = 'yes';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # --
    # ??, nested
    $template = '<#if nested.name??>
ok
</#if>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = 'ok';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_if_logic {
    my ($this) = @_;

    my $tmpData = {
        x      => 1,
        color  => 'green',
        male   => 1,
        female => 0,
        nested => { x => 1 }
    };

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    # ------------------------------------------------
    # &&
    $template = "<#if x == 1 && color = 'green'>1</#if>";
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # &&
    $template = "<#if x?? && male??>1</#if>";
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # && with non existing var
    $template = "<#if x?? && y??>1<#else>0</#if>";
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '0';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # && with existing nested var
    $template = "<#if x?? && nested.x??>1<#else>0</#if>";
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # && with non existing nested var
    $template = "<#if x?? && nested.y??>1<#else>0</#if>";
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '0';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # ?? && !??
    $template = "<#if x?? && !nested.y??>1<#else>0</#if>";
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # ?? && !??
    $template = "<#if x?? && !nested.x??>1<#else>0</#if>";
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '0';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # !
    $template = "<#if male>1</#if>";
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # !
    $template = "<#if !female>1</#if>";
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # !
    $template = "<#if !male>1</#if>";
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # multiple &&
    $template = "<#if x && male && color = 'green'>1</#if>";
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # multiple &&
    $template = "<#if x && male && color = 'red'>1</#if>";
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # && ||
    $template = "<#if (x && male || female) && color = 'green'>1</#if>";
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

sub test_tag_if_compare_data {
    my ($this) = @_;

    my $tmpData = {
        selectedcolor => 'green',
        color         => 'green'
    };

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#if selectedcolor == color>1</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_if_else {
    my ($this) = @_;

    my $tmpData = {
        x => 1,
        z => 2,
    };

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#if x == 1>
<#assign y=2>
${y}
<#if y==2>
y=2
<#else>
not 2
</#if>
<#elseif z == 2>
x is 1
<#else>
else x is ...
</#if>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '2
y=2';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ===

    $template = '<#if x == 1>
<#assign y=2>
${y}
<#if y!=2>
y is not 2
<#else>
2
</#if>
<#elseif z == 2>
x is 1
<#else>
else x is ...
</#if>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '2
2';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ===

    $template = '<#if x != 1>
<#assign y=2>
${y}
<#if y==2>
y=2
<#else>
not 2
</#if>
<#elseif z == 2>
x is 1
<#else>
else x is ...
</#if>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = 'x is 1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ===

    $template = '<#if x != 1>
<#assign y=2>
${y}
<#if y==2>
y=2
<#else>
not 2
</#if>
<#elseif z != 2>
x is 1
<#else>
else x is ...
</#if>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = 'else x is ...';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tag_if_else_nested {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    my $tmpData = {
        x => 1,
        y => 2,
        z => 3,
    };

    $template = '<#if x == 1>
<#if y == 2>
<#if z == 3>
z is 3
<#else>
z is not 3
</#if>
<#else>
y is not 2
</#if>
<#else>
x is not 1
</#if>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = 'z is 3';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $tmpData = {
        x  => 1,
        yy => 2,
        z  => 0,
    };

    $template = '<#if x == 1>
<#if yy == 2>
<#if z == 3>
z is 3
<#else>
z is not 3
</#if>
<#else>
yy is not 2
</#if>
<#else>
x is not 1
</#if>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = 'z is not 3';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $tmpData = {
        a => 0,
        b => -1,
    };

    $template = '<#if a == 1>
a is 1
<#if b == 1>
and b is 1 too
<#else>
but b is not
</#if>
<#else>
a is not 1
<#if b lt 0>
and b is less than 0
</#if>
</#if>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = 'a is not 1
and b is less than 0';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

}

=pod

=cut

sub test_tmp_directive_ftl {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template =
'<#ftl encoding="UTF-8" strip_whitespace="false" strip_text=true attributes={"string":"a", "number":-99, "sequence":[0,"a"]}>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);

    $result   = $parser->{data}->{_ftlData}->{encoding};
    $expected = 'UTF-8';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    $result   = $parser->{data}->{_ftlData}->{strip_whitespace};
    $expected = 0;
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    $result   = $parser->{data}->{_ftlData}->{strip_text};
    $expected = 1;
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    $result   = $parser->{data}->{_ftlData}->{attributes}->{string};
    $expected = 'a';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    $result   = $parser->{data}->{_ftlData}->{attributes}->{number};
    $expected = -99;
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    $result   = $parser->{data}->{_ftlData}->{attributes}->{sequence}->[1];
    $expected = 'a';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_tmp_directive_ftl_strip_whitespace {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#ftl strip_whitespace=false>
<ul>
<#list ["winter", "spring", "summer", "autumn"] as x>
<li>season = ${x}</li>
</#list>
</ul>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '
<ul>

<li>season = winter</li>

<li>season = spring</li>

<li>season = summer</li>

<li>season = autumn</li>

</ul>
';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_string_substring {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${"abc"?substring(0)}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 'abc';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${"abc"?substring(2)}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 'c';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${"abc"?substring(3)}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${"abc"?substring(0, 0)}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${"abc"?substring(0, 1)}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 'a';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${"abcdef"?substring(2,3)}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 'c';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_string_cap_first {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${"   green mouse"?cap_first}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '   Green mouse';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${"GreEN mouse"?cap_first}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 'GreEN mouse';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${"- green mouse"?cap_first}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '- green mouse';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_string_uncap_first {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${"   Green mouse"?uncap_first}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '   green mouse';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${"GreEN mouse"?uncap_first}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 'greEN mouse';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${"- Green mouse"?uncap_first}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '- Green mouse';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_string_capitalize {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${"   green mouse"?capitalize}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '   Green Mouse';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${"greEN mouse"?capitalize}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 'GreEN Mouse';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_string_eval {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${"1+2"?eval}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '3';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${"x"?eval}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, { x => 'apple' } );
    $result   = $parsed;
    $expected = 'apple';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${("info" + x)?eval}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse(
        $template,
        {
            x         => 'apple',
            infoapple => "juicy"
        }
    );
    $result   = $parsed;
    $expected = 'juicy';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${("info" + y)?eval}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${("info" + "_" + col.name)?eval}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse(
        $template,
        {
            col => { name => 'lawsuits' },
            info_lawsuits =>
              'his lawyer filed a lawsuit against Los Angeles city.'
        }
    );
    $result   = $parsed;
    $expected = 'his lawyer filed a lawsuit against Los Angeles city.';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_string_html {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${"& <my> name is \"skath\""?html}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '&amp; &lt;my&gt; name is &quot;skath&quot;';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_string_xhtml {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${"& <my> name is \'skath\'"?xhtml}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '&amp; &lt;my&gt; name is &#39;skath&#39;';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_string_lowercase {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${"   GrEeN MoUsE"?lower_case}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '   green mouse';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_string_replace {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${"this is a car acarus"?replace("car", "bulldozer")}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 'this is a bulldozer abulldozerus';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${story?replace("good, morning", "\'Guten Morgen\'")}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    my $tmpData = { story =>
          'good, morning said Heinrich as he entered the swimming pool' };
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = "'Guten Morgen' said Heinrich as he entered the swimming pool";
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_string_string {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${"abc \"def\""?string}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 'abc "def"';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_string_uppercase {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${"   GrEeN MoUsE"?upper_case}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '   GREEN MOUSE';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_string_length {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

=pod
	$template = '${"   GrEeN MoUsE"?length}';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
	$parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug} = $PARSER_DEBUG;
    $parsed = $parser->parse($template);
    $result   = $parsed;
    $expected = 14;
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
=cut

    # --

    $template = '${""?length}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 0;
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_sequence_sort {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template =
'<#assign ls = ["whale", "Barbara", "zeppelin", "aardvark", "beetroot"]?sort>
<#list ls as i>${i} </#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 'aardvark Barbara beetroot whale zeppelin ';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_sequence_size {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template =
'<#assign s = ["whale", "Barbara", "zeppelin", "aardvark", "beetroot"]?size>
${s}';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 5;
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------
    # inside if

    $template = '<#if zoo?size == 4>TRUE</#if>';
    my @animals = ( 'gorilla', 'zebra', 'elephant', 'shark' );
    my $tmpData = { zoo => \@animals };
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = 'TRUE';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_sequence_join {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;
    my $tmpData;

    $template =
      '<#assign l = ["whale", "Barbara", "zeppelin", "aardvark", "beetroot"]>
${l?join(", ")}';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 'whale, Barbara, zeppelin, aardvark, beetroot';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${zoo?join(", ")}';
    my @values = ( 'gorilla', 'zebra', 'elephant', 'shark' );
    $tmpData = { zoo => \@values };
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = join( ', ', @values );
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = '${animals.sea?join(", ")}';
    my @seaAnimals  = ( 'shark',   'lobster', 'starfish' );
    my @landAnimals = ( 'gorilla', 'zebra',   'elephant' );
    $tmpData = {
        animals => {
            sea  => \@seaAnimals,
            land => \@landAnimals
        }
    };
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = 'shark, lobster, starfish';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_sequence_first {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template =
'<#assign s = ["whale", "Barbara", "zeppelin", "aardvark", "beetroot"]?first>
${s}';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 'whale';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_sequence_last {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template =
'<#assign s = ["whale", "Barbara", "zeppelin", "aardvark", "beetroot"]?last>
${s}';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 'beetroot';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_sequence_reverse {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template =
'<#assign s = ["whale", "Barbara", "zeppelin", "aardvark", "beetroot"]?reverse>
${s}';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parser->{data}->{'s'}->[0];
    $expected             = 'beetroot';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    $result   = $parser->{data}->{'s'}->[1];
    $expected = 'aardvark';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_sequence_seq_contains {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#assign x = ["red", 16, "blue", "cyan"]>
"blue": ${x?seq_contains("blue")?string("yes", "no")}
"yellow": ${x?seq_contains("yellow")?string("yes", "no")}
16: ${x?seq_contains(16)?string("yes", "no")}
"16": ${x?seq_contains("16")?string("yes", "no")}';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '"blue": yes
"yellow": no
16: yes
"16": no';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_builtin_sequence_seq_index_of {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#assign items = ["red", "green", 16, "8"]>
${items?seq_index_of(16)}
${items?seq_index_of("16")}
${items?seq_index_of(8)}
${items?seq_index_of("red")}
${items?seq_index_of("purple")}';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = '2
-1
-1
0
-1';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

sub test_builtin_sequence_seq_sort_by {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#assign ls = [
  {"name":"whale", "weight":2000},
  {"name":"Barbara", "weight":53},
  {"name":"zeppelin", "weight":-200},
  {"name":"aardvark", "weight":30},
  {"name":"beetroot", "weight":0.3}
]>
Order by name:
<#list ls?sort_by("name") as i>
- ${i.name}: ${i.weight}
</#list>

Order by weight:
<#list ls?sort_by("weight") as i>
- ${i.name}: ${i.weight}
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse($template);
    $result               = $parsed;
    $expected             = 'Order by name:
- aardvark: 30
- Barbara: 53
- beetroot: 0.3
- whale: 2000
- zeppelin: -200

Order by weight:
- zeppelin: -200
- beetroot: 0.3
- aardvark: 30
- Barbara: 53
- whale: 2000
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

Function calls

=cut

sub _func {
    my ($str) = @_;

    print("_func:$str.") if $DEBUG;
    return $str;
}

=pod

=cut

sub test_call_function {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;
    my $tmpData;

    $template = '${doFunc("hello!")}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, { doFunc => \&_func, } );
    $result   = $parsed;
    $expected = 'hello!';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ------------------------------------------------

    $template = "\${doFunc('\${zoo.elephant[1]}')}";
    my $animals = {};
    $animals->{elephant}->[0] = 'large';
    $animals->{elephant}->[1] = 'gray';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse(
        $template,
        {
            zoo    => $animals,
            doFunc => \&_func,
        }
    );
    $result   = $parsed;
    $expected = 'gray';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

# SPECIAL VARIABLES

sub test_special_variables_vars {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;
    my $tmpData;

    $template = '${.vars[A]}';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, { A => "a", } );
    $result   = $parsed;
    $expected = 'a';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

# CUSTOM TAGS

sub test_tag_dump {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;
    my $tmpData = {
        data => {
            colors => [
                "red",  "green",  "black", "gray",
                "blue", "purple", "brown", "yellow"
            ],
            selectedcolor => "green"
        }
    };

    $template = '<#dump data/>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = "\$VAR1 = {
          'selectedcolor' => 'green',
          'colors' => [
                        'red',
                        'green',
                        'black',
                        'gray',
                        'blue',
                        'purple',
                        'brown',
                        'yellow'
                      ]
        };
";
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    #----------

    $template = '<#dump data.colors />';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = "\$VAR1 = [
          'red',
          'green',
          'black',
          'gray',
          'blue',
          'purple',
          'brown',
          'yellow'
        ];
";
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

# COMBINED TESTS

sub test_combined_1 {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;
    my $tmpData;

    $template = '<#assign page0>
introduction: ${color}
</#assign>
<#assign page1>
this is the next step
</#assign>
<#assign selectedcolor="green">
<#if color=selectedcolor>${page0}</#if>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, { color => "green", } );
    $result   = $parsed;
    $expected = 'introduction: green
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_combined_2 {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;
    my $tmpData;

    $template = '<#list colors as color>
<#if selectedcolor==color>
- ${color} is selected
<#else>
- ${color}
</#if>
</#list>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse(
        $template,
        {
            colors => [
                "red",  "green",  "black", "gray",
                "blue", "purple", "brown", "yellow"
            ],
            selectedcolor => "green"
        }
    );
    $result   = $parsed;
    $expected = '- red
- green is selected
- black
- gray
- blue
- purple
- brown
- yellow
';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_complex_1 {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '${pageSummary.memberList.memberSummaryPart[0].title}';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $COMPLEX_TEST_DATA );
    $result   = $parsed;
    $expected = 'Constructor';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_complex_2 {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    # ---
    $template = '<#if pageSummary.memberList.memberSummaryPart??>
<div class="memberList">
<#list pageSummary.memberList.memberSummaryPart as part>
<div class="memberSummaryPart">
<#list part.item as item>
- ${item.title}
</#list>
</div>
</#list>
</div>
</#if>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $COMPLEX_TEST_DATA );
    $result   = $parsed;
    $expected = '<div class="memberList">
<div class="memberSummaryPart">
- ArrayEnumerator
</div>
<div class="memberSummaryPart">
- setObjects
- getCurrentObject
- getNextObject
- getAllObjects
- reset
- getCurrentLocation
- setCurrentLocation
- setCurrentObject
</div>
</div>';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_complex_3 {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    # ---
    $template = '<#macro iconButton class icon label>
<span class="${class}"><a href="#"><span class="icon">${icon}</span><span class="label">${label}</span></a></span>
</#macro>
<#if pageSummary?? && pageSummary.memberList??>
<div class="docNav">
<ul>
<#if pageSummary.memberList.showHideTypeInfo??>
	<li>
		<@iconButton class="typeInfoHide" icon="&times;" label="${pageSummary.memberList.showHideTypeInfo.hideTypeInfo}" />
		<@iconButton class="typeInfoShow" icon="+" label="${pageSummary.memberList.showHideTypeInfo.showTypeInfo}" />
	</li>
	</#if>
	<#if pageSummary.memberList.showHideSummaries??>
	<li>
		<@iconButton class="summariesHide" icon="&times;" label="${pageSummary.memberList.showHideSummaries.hideSummaries}" />
		<@iconButton class="summariesShow" icon="+" label="${pageSummary.memberList.showHideSummaries.showSummaries}" />
	</li>
</#if>
</ul>
<div class="clear"></div>
</div>
<#if pageSummary.memberList.memberSummaryPart??>
<div class="memberList">
<#list pageSummary.memberList.memberSummaryPart as part>
<div class="memberSummaryPart">
<#list part.item as item>
<#if item.typeInfo.summary??>
<ul class="summary">
	<li>${item.typeInfo.summary}</li>
</ul>
</#if>
</#list>
</div>
</#list>
</div>
</#if>
</#if>';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $COMPLEX_TEST_DATA );
    $result   = $parsed;
    $expected = '<div class="docNav">
<ul>
	<li>
		<span class="typeInfoHide"><a href="#"><span class="icon">&times;</span><span class="label">Hide type info</span></a></span>
		<span class="typeInfoShow"><a href="#"><span class="icon">+</span><span class="label">Show type info</span></a></span>
	</li>		<li>
		<span class="summariesHide"><a href="#"><span class="icon">&times;</span><span class="label">Hide summaries</span></a></span>
		<span class="summariesShow"><a href="#"><span class="icon">+</span><span class="label">Show summaries</span></a></span>
	</li></ul>
<div class="clear"></div>
</div>
<div class="memberList">
<div class="memberSummaryPart">
<ul class="summary">
	<li>Creates a new array enumerator. </li>
</ul></div>
<div class="memberSummaryPart">
<ul class="summary">
	<li>Stores a pointer to array inArray.</li>
</ul><ul class="summary">
	<li>Retrieves the object from the array at the current pointer location.</li>
</ul><ul class="summary">
	<li>Increments the location pointer by one and returns the object from the array at that location.</li>
</ul><ul class="summary">
	<li>Retrieves all objects.</li>
</ul><ul class="summary">
	<li>Puts the enumerator just before the first array item. </li>
</ul><ul class="summary">
	<li>Sets the location pointer to a new position.</li>
</ul><ul class="summary">
	<li>Sets the location pointer to the location (in the array) of inObject.</li>
</ul></div>
</div>';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_recursive {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    my $tmpData = {
        tree => {
            name  => 'root',
            child => {
                name  => 'child 1',
                child => {
                    name  => 'child 2',
                    child => {
                        name  => 'child 3',
                        child => {
                            name  => 'child 5',
                            child => { name => 'child 6' }
                        }
                    }
                }
            }
        }
    };

    $template = '<#macro treeMacro node>
<#if node.name??>
- ${node.name}
</#if>
<#if node.child??>
<@treeMacro node=node.child />
</#if>
</#macro>
<@treeMacro node=tree />';

    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, $tmpData );
    $result   = $parsed;
    $expected = '- root- child 1- child 2- child 3- child 5- child 6';
    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod
sub testest {
	my ($this) = @_;
	
	my $localData = {
		_keys => []
	};
	
	
	my $addLocalScope = sub {
		my $uniqueScopeKey = int(rand(10000000));
		push (@{$localData->{_keys}}, $uniqueScopeKey);
	};
	
	my $removeLocalScope = sub {
		my $scopeKey = pop(@{$localData->{_keys}});
		delete $localData->{$scopeKey};
	};
	
	my $storeLocalData = sub {
		my ($data) = @_;
		
		my $scopeKey = $localData->{_keys}[-1];
		while (my ($key, $value) = each %{$data}) {
			$localData->{$scopeKey}->{$key} = $value;
		}
	};
	
	my $getData = sub {
		my ($dataKey) = @_;
		
		my $data;
		foreach my $key (reverse @{$localData->{_keys}}) {
			print "key=$key\n";
			$data = $localData->{$key}->{$dataKey};
			last if defined $data;
		}
		return $data;
	};
	
	
	use Data::Dumper;
	
	&$addLocalScope();
	
	print "addLocalScope\n";
	print Dumper($localData);
	
	my $newData = {
		color => 'green',
		shape => 'circle',
		size => 10
	};
	&$storeLocalData($newData);
	
	print "storeLocalData\n";
	print Dumper($localData);
	
	&$addLocalScope();
	
	print "addLocalScope\n";
	print Dumper($localData);
	
	$newData = {
		color => 'red',
		shape => 'square',
	};
	&$storeLocalData($newData);
	
	print "storeLocalData\n";
	print Dumper($localData);
	
	print "color=" . &$getData('color') . "\n";
	print "size=" . &$getData('size') . "\n";
	
	&$removeLocalScope();
	
	print "removeLocalScope\n";
	print Dumper($localData);
	print "color=" . &$getData('color') . "\n";
	print "size=" . &$getData('size') . "\n";
}
=cut

# HELPER FUNCTIONS

sub _trimSpaces {

    #my $parsed = $_[0]
    return if !$_[0];
    $_[0] =~ s/^[[:space:]]+//s;    # trim at start
    $_[0] =~ s/[[:space:]]+$//s;    # trim at end
}

sub _dump {
    my ($data) = @_;

    use Data::Dumper;
    print "data=" . Dumper($data);
}

1;
