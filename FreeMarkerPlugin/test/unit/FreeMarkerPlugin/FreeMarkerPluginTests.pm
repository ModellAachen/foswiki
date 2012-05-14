package FreeMarkerPluginTests;
use base qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Foswiki::Func;

my $DEBUG = 0;

sub new {
    my $self = shift()->SUPER::new( 'FreeMarkerPluginTests', @_ );
    return $self;
}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig();

    $Foswiki::cfg{Plugins}{FreeMarkerPlugin}{Enabled} = 1;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
}

=pod

=cut

sub test_empty {
    my ($this) = @_;

    my $text;
    my $actual;
    my $expected;

    $text = '%STARTFREEMARKER{}%%ENDFREEMARKER%';

    $actual =
      Foswiki::Func::expandCommonVariables( $text, $this->{test_topic},
        $this->{test_web} );
    $actual =
      Foswiki::Func::renderText( $actual, $this->{test_web},
        $this->{test_topic} );

    $expected = '';

    print("RES=$actual.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;

    $this->assert( $actual eq $expected );
}

=pod

=cut

sub test_assign_no_input {
    my ($this) = @_;

    my $text;
    my $actual;
    my $expected;

    $text = '%STARTFREEMARKER{}%<#assign name>John</#assign>
${name}
%ENDFREEMARKER%';

    $actual =
      Foswiki::Func::expandCommonVariables( $text, $this->{test_topic},
        $this->{test_web} );
    $actual =
      Foswiki::Func::renderText( $actual, $this->{test_web},
        $this->{test_topic} );

    $expected = 'John';

    print("RES=$actual.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;

    $this->assert( $actual eq $expected );
}

=pod

=cut

sub test_substitute_with_input {
    my ($this) = @_;

    my $text;
    my $actual;
    my $expected;

    $text = '%STARTFREEMARKER{name="John"}%${name}
%ENDFREEMARKER%';

    $actual =
      Foswiki::Func::expandCommonVariables( $text, $this->{test_topic},
        $this->{test_web} );
    $actual =
      Foswiki::Func::renderText( $actual, $this->{test_web},
        $this->{test_topic} );

    $expected = 'John';

    print("RES=$actual.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;

    $this->assert( $actual eq $expected );
}

=pod

=cut

sub test_substitute_with_input_more_complex {
    my ($this) = @_;

    my $text;
    my $actual;
    my $expected;

    $text =
'%STARTFREEMARKER{headline="Welcome!" depth="4" class="foswikiHelp"}%<#if headline??>
<h${depth} class="${class}">${headline}</h${depth}>
</#if>
%ENDFREEMARKER%';

    $actual =
      Foswiki::Func::expandCommonVariables( $text, $this->{test_topic},
        $this->{test_web} );
    $actual =
      Foswiki::Func::renderText( $actual, $this->{test_web},
        $this->{test_topic} );

    $expected = '<h4 class="foswikiHelp">Welcome!</h4>';

    print("RES=$actual.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;

    $this->assert( $actual eq $expected );
}

=pod

=cut

sub test_input_list {
    my ($this) = @_;

    my $text;
    my $actual;
    my $expected;

    $text = '%STARTFREEMARKER{users="[Ashton, Bonny, Zeta]"}%<#list users as x>
- ${x}
</#list>
%ENDFREEMARKER%';

    $actual =
      Foswiki::Func::expandCommonVariables( $text, $this->{test_topic},
        $this->{test_web} );
    $actual =
      Foswiki::Func::renderText( $actual, $this->{test_web},
        $this->{test_topic} );
    $expected = '- Ashton
- Bonny
- Zeta';

    print("RES=$actual.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;

    $this->assert( $actual eq $expected );
}

=pod

=cut

sub test_input_hash {
    my ($this) = @_;

    my $text;
    my $actual;
    my $expected;

    $text = '%STARTFREEMARKER{
vars="[{color:red, value:255},{color:green, value:100}]"}%${vars[1].color}
%ENDFREEMARKER%';

    $actual =
      Foswiki::Func::expandCommonVariables( $text, $this->{test_topic},
        $this->{test_web} );
    $actual =
      Foswiki::Func::renderText( $actual, $this->{test_web},
        $this->{test_topic} );

    $expected = 'green';

    print("RES=$actual.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;

    $this->assert( $actual eq $expected );
}

=pod

=cut

sub test_input_hash_with_arrays {
    my ($this) = @_;

    my $text;
    my $actual;
    my $expected;

    $text = '%STARTFREEMARKER{
vars="{
	users    : [ Joe,    Fred ],
	admins   : [ Julia,  Kate ],
	children : [ Mickey, Rooney ]
}"}%<#list vars.users + vars.admins + vars.children as person>
- ${person}
</#list>
%ENDFREEMARKER%';

    $actual =
      Foswiki::Func::expandCommonVariables( $text, $this->{test_topic},
        $this->{test_web} );
    $actual =
      Foswiki::Func::renderText( $actual, $this->{test_web},
        $this->{test_topic} );

    $expected = '- Joe
- Fred
- Julia
- Kate
- Mickey
- Rooney';

    print("RES=$actual.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;

    $this->assert( $actual eq $expected );
}

=pod

=cut

=pod
sub _test_example {
    my ($this) = @_;

	my $text;
	my $actual;
	my $expected;
	
	$text = '%STARTFREEMARKER{topics="[$percntSEARCH{$quot*$quot web=$quotSystem$quot format=$quot$topic$quot nonoise=$quoton$quot separator=$quot,$quot limit=$quot20$quot}$percnt]"}%
<noautolink>
<#list topics as topic>
- ${topic}
</#list>
</noautolink>
%ENDFREEMARKER%';
	
   	$actual =
      Foswiki::Func::expandCommonVariables( $text, $this->{test_topic}, $this->{test_web} );
    $actual = Foswiki::Func::renderText( $actual, $this->{test_web}, $this->{test_topic} );

    $expected = 'ZZ';

    print("RES=$actual.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;

    $this->assert( $actual eq $expected );
}
=cut

# HELPER FUNCTIONS

sub _trimSpaces {

    #my $parsed = $_[0]

    $_[0] =~ s/^[[:space:]]+//s;    # trim at start
    $_[0] =~ s/[[:space:]]+$//s;    # trim at end
}

sub _dump {
    my ($data) = @_;

    use Data::Dumper;
    print "data=" . Dumper($data);
}

1;
