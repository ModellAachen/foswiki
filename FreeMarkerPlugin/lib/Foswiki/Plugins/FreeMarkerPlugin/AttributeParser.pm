####################################################################
#
#    This file was generated using Parse::Yapp version 1.05.
#
#        Don't edit this file, use source file instead.
#
#             ANY CHANGE MADE HERE WILL BE LOST !
#
####################################################################
package Foswiki::Plugins::FreeMarkerPlugin::AttributeParser;
use vars qw ( @ISA );
use strict;

@ISA = qw ( Parse::Yapp::Driver::AttributeParser );

#Included Parse/Yapp/Driver.pm file----------------------------------------
{

    #
    # Module Parse::Yapp::Driver::AttributeParser
    #
    # This module is part of the Parse::Yapp package available on your
    # nearest CPAN
    #
    # Any use of this module in a standalone parser make the included
    # text under the same copyright as the Parse::Yapp module itself.
    #
    # This notice should remain unchanged.
    #
    # (c) Copyright 1998-2001 Francois Desarmenien, all rights reserved.
    # (see the pod text in Parse::Yapp module for use and distribution rights)
    #

    package Parse::Yapp::Driver::AttributeParser;

    require 5.004;

    use strict;

    use vars qw ( $VERSION $COMPATIBLE $FILENAME );

    $VERSION    = '1.05';
    $COMPATIBLE = '0.07';
    $FILENAME   = __FILE__;

    use Carp;

    #Known parameters, all starting with YY (leading YY will be discarded)
    my (%params) = (
        YYLEX     => 'CODE',
        'YYERROR' => 'CODE',
        YYVERSION => '',
        YYRULES   => 'ARRAY',
        YYSTATES  => 'ARRAY',
        YYDEBUG   => ''
    );

    #Mandatory parameters
    my (@params) = ( 'LEX', 'RULES', 'STATES' );

    sub new {
        my ($class) = shift;
        my ( $errst, $nberr, $token, $value, $check, $dotpos );
        my ($self) = {
            ERROR  => \&_Error,
            ERRST  => \$errst,
            NBERR  => \$nberr,
            TOKEN  => \$token,
            VALUE  => \$value,
            DOTPOS => \$dotpos,
            STACK  => [],
            DEBUG  => 0,
            CHECK  => \$check
        };

        _CheckParams( [], \%params, \@_, $self );

        exists( $$self{VERSION} )
          and $$self{VERSION} < $COMPATIBLE
          and croak "Yapp driver version $VERSION "
          . "incompatible with version $$self{VERSION}:\n"
          . "Please recompile parser module.";

        ref($class)
          and $class = ref($class);

        bless( $self, $class );
    }

    sub YYParse {
        my ($self) = shift;
        my ($retval);

        _CheckParams( \@params, \%params, \@_, $self );

        if ( $$self{DEBUG} ) {
            _DBLoad();
            $retval =
              eval '$self->_DBParse()';    #Do not create stab entry on compile
            $@ and die $@;
        }
        else {
            $retval = $self->_Parse();
        }
        $retval;
    }

    sub YYData {
        my ($self) = shift;

        exists( $$self{USER} )
          or $$self{USER} = {};

        $$self{USER};

    }

    sub YYErrok {
        my ($self) = shift;

        ${ $$self{ERRST} } = 0;
        undef;
    }

    sub YYNberr {
        my ($self) = shift;

        ${ $$self{NBERR} };
    }

    sub YYRecovering {
        my ($self) = shift;

        ${ $$self{ERRST} } != 0;
    }

    sub YYAbort {
        my ($self) = shift;

        ${ $$self{CHECK} } = 'ABORT';
        undef;
    }

    sub YYAccept {
        my ($self) = shift;

        ${ $$self{CHECK} } = 'ACCEPT';
        undef;
    }

    sub YYError {
        my ($self) = shift;

        ${ $$self{CHECK} } = 'ERROR';
        undef;
    }

    sub YYSemval {
        my ($self)  = shift;
        my ($index) = $_[0] - ${ $$self{DOTPOS} } - 1;

        $index < 0
          and -$index <= @{ $$self{STACK} }
          and return $$self{STACK}[$index][1];

        undef;    #Invalid index
    }

    sub YYCurtok {
        my ($self) = shift;

        @_
          and ${ $$self{TOKEN} } = $_[0];
        ${ $$self{TOKEN} };
    }

    sub YYCurval {
        my ($self) = shift;

        @_
          and ${ $$self{VALUE} } = $_[0];
        ${ $$self{VALUE} };
    }

    sub YYExpect {
        my ($self) = shift;

        keys %{ $self->{STATES}[ $self->{STACK}[-1][0] ]{ACTIONS} };
    }

    sub YYLexer {
        my ($self) = shift;

        $$self{LEX};
    }

#################
    # Private stuff #
#################

    sub _CheckParams {
        my ( $mandatory, $checklist, $inarray, $outhash ) = @_;
        my ( $prm, $value );
        my ($prmlst) = {};

        while ( ( $prm, $value ) = splice( @$inarray, 0, 2 ) ) {
            $prm = uc($prm);
            exists( $$checklist{$prm} )
              or croak("Unknow parameter '$prm'");
            ref($value) eq $$checklist{$prm}
              or croak("Invalid value for parameter '$prm'");
            $prm = unpack( '@2A*', $prm );
            $$outhash{$prm} = $value;
        }
        for (@$mandatory) {
            exists( $$outhash{$_} )
              or croak( "Missing mandatory parameter '" . lc($_) . "'" );
        }
    }

    sub _Error {
        print "Parse error.\n";
    }

    sub _DBLoad {
        {
            no strict 'refs';

            exists( ${ __PACKAGE__ . '::' }{_DBParse} )    #Already loaded ?
              and return;
        }
        my ($fname) = __FILE__;
        my (@drv);
        open( DRV, "<$fname" )
          or die "Report this as a BUG: Cannot open $fname";
        while (<DRV>) {
            /^\s*sub\s+_Parse\s*{\s*$/ .. /^\s*}\s*#\s*_Parse\s*$/
              and do {
                s/^#DBG>//;
                push( @drv, $_ );
              }
        }
        close(DRV);

        $drv[0] =~ s/_P/_DBP/;
        eval join( '', @drv );
    }

    #Note that for loading debugging version of the driver,
    #this file will be parsed from 'sub _Parse' up to '}#_Parse' inclusive.
    #So, DO NOT remove comment at end of sub !!!
    sub _Parse {
        my ($self) = shift;

        my ( $rules, $states, $lex, $error ) =
          @$self{ 'RULES', 'STATES', 'LEX', 'ERROR' };
        my ( $errstatus, $nberror, $token, $value, $stack, $check, $dotpos ) =
          @$self{ 'ERRST', 'NBERR', 'TOKEN', 'VALUE', 'STACK', 'CHECK',
            'DOTPOS' };

        #DBG>	my($debug)=$$self{DEBUG};
        #DBG>	my($dbgerror)=0;

        #DBG>	my($ShowCurToken) = sub {
        #DBG>		my($tok)='>';
        #DBG>		for (split('',$$token)) {
        #DBG>			$tok.=		(ord($_) < 32 or ord($_) > 126)
        #DBG>					?	sprintf('<%02X>',ord($_))
        #DBG>					:	$_;
        #DBG>		}
        #DBG>		$tok.='<';
        #DBG>	};

        $$errstatus = 0;
        $$nberror   = 0;
        ( $$token, $$value ) = ( undef, undef );
        @$stack = ( [ 0, undef ] );
        $$check = '';

        while (1) {
            my ( $actions, $act, $stateno );

            $stateno = $$stack[-1][0];
            $actions = $$states[$stateno];

            #DBG>	print STDERR ('-' x 40),"\n";
            #DBG>		$debug & 0x2
            #DBG>	and	print STDERR "In state $stateno:\n";
            #DBG>		$debug & 0x08
            #DBG>	and	print STDERR "Stack:[".
            #DBG>					 join(',',map { $$_[0] } @$stack).
            #DBG>					 "]\n";

            if ( exists( $$actions{ACTIONS} ) ) {

                defined($$token)
                  or do {
                    ( $$token, $$value ) = &$lex($self);

                #DBG>				$debug & 0x01
                #DBG>			and	print STDERR "Need token. Got ".&$ShowCurToken."\n";
                  };

                $act =
                  exists( $$actions{ACTIONS}{$$token} )
                  ? $$actions{ACTIONS}{$$token}
                  : exists( $$actions{DEFAULT} ) ? $$actions{DEFAULT}
                  :                                undef;
            }
            else {
                $act = $$actions{DEFAULT};

                #DBG>			$debug & 0x01
                #DBG>		and	print STDERR "Don't need token.\n";
            }

            defined($act)
              and do {

                $act > 0
                  and do {    #shift

                    #DBG>				$debug & 0x04
                    #DBG>			and	print STDERR "Shift and go to state $act.\n";

                    $$errstatus
                      and do {
                        --$$errstatus;

                        #DBG>					$debug & 0x10
                        #DBG>				and	$dbgerror
                        #DBG>				and	$$errstatus == 0
                        #DBG>				and	do {
                        #DBG>					print STDERR "**End of Error recovery.\n";
                        #DBG>					$dbgerror=0;
                        #DBG>				};
                      };

                    push( @$stack, [ $act, $$value ] );

                    $$token ne ''    #Don't eat the eof
                      and $$token = $$value = undef;
                    next;
                  };

                #reduce
                my ( $lhs, $len, $code, @sempar, $semval );
                ( $lhs, $len, $code ) = @{ $$rules[ -$act ] };

            #DBG>			$debug & 0x04
            #DBG>		and	$act
            #DBG>		and	print STDERR "Reduce using rule ".-$act." ($lhs,$len): ";

                $act
                  or $self->YYAccept();

                $$dotpos = $len;

                unpack( 'A1', $lhs ) eq '@'    #In line rule
                  and do {
                    $lhs =~ /^\@[0-9]+\-([0-9]+)$/
                      or die "In line rule name '$lhs' ill formed: "
                      . "report it as a BUG.\n";
                    $$dotpos = $1;
                  };

                @sempar =
                  $$dotpos
                  ? map { $$_[1] } @$stack[ -$$dotpos .. -1 ]
                  : ();

                $semval =
                    $code ? &$code( $self, @sempar )
                  : @sempar ? $sempar[0]
                  :           undef;

                splice( @$stack, -$len, $len );

                $$check eq 'ACCEPT'
                  and do {

                    #DBG>			$debug & 0x04
                    #DBG>		and	print STDERR "Accept.\n";

                    return ($semval);
                  };

                $$check eq 'ABORT'
                  and do {

                    #DBG>			$debug & 0x04
                    #DBG>		and	print STDERR "Abort.\n";

                    return (undef);

                  };

                #DBG>			$debug & 0x04
                #DBG>		and	print STDERR "Back to state $$stack[-1][0], then ";

                $$check eq 'ERROR'
                  or do {

            #DBG>				$debug & 0x04
            #DBG>			and	print STDERR
            #DBG>				    "go to state $$states[$$stack[-1][0]]{GOTOS}{$lhs}.\n";

                    #DBG>				$debug & 0x10
                    #DBG>			and	$dbgerror
                    #DBG>			and	$$errstatus == 0
                    #DBG>			and	do {
                    #DBG>				print STDERR "**End of Error recovery.\n";
                    #DBG>				$dbgerror=0;
                    #DBG>			};

                    push( @$stack,
                        [ $$states[ $$stack[-1][0] ]{GOTOS}{$lhs}, $semval ] );
                    $$check = '';
                    next;
                  };

                #DBG>			$debug & 0x04
                #DBG>		and	print STDERR "Forced Error recovery.\n";

                $$check = '';

              };

            #Error
            $$errstatus
              or do {

                $$errstatus = 1;
                &$error($self);
                $$errstatus    # if 0, then YYErrok has been called
                  or next;     # so continue parsing

                #DBG>			$debug & 0x10
                #DBG>		and	do {
                #DBG>			print STDERR "**Entering Error recovery.\n";
                #DBG>			++$dbgerror;
                #DBG>		};

                ++$$nberror;

              };

            $$errstatus == 3    #The next token is not valid: discard it
              and do {
                $$token eq ''    # End of input: no hope
                  and do {

                    #DBG>				$debug & 0x10
                    #DBG>			and	print STDERR "**At eof: aborting.\n";
                    return (undef);
                  };

         #DBG>			$debug & 0x10
         #DBG>		and	print STDERR "**Dicard invalid token ".&$ShowCurToken.".\n";

                $$token = $$value = undef;
              };

            $$errstatus = 3;

            while (
                @$stack
                and (  not exists( $$states[ $$stack[-1][0] ]{ACTIONS} )
                    or not exists( $$states[ $$stack[-1][0] ]{ACTIONS}{error} )
                    or $$states[ $$stack[-1][0] ]{ACTIONS}{error} <= 0 )
              )
            {

                #DBG>			$debug & 0x10
                #DBG>		and	print STDERR "**Pop state $$stack[-1][0].\n";

                pop(@$stack);
            }

            @$stack
              or do {

                #DBG>			$debug & 0x10
                #DBG>		and	print STDERR "**No state left on stack: aborting.\n";

                return (undef);
              };

            #shift the error token

            #DBG>			$debug & 0x10
            #DBG>		and	print STDERR "**Shift \$error token and go to state ".
            #DBG>						 $$states[$$stack[-1][0]]{ACTIONS}{error}.
            #DBG>						 ".\n";

            push( @$stack,
                [ $$states[ $$stack[-1][0] ]{ACTIONS}{error}, undef ] );

        }

        #never reached
        croak("Error in driver logic. Please, report it as a BUG");

    }    #_Parse

    #DO NOT remove comment

    1;

}

#End of include--------------------------------------------------

sub new {
    my ($class) = shift;
    ref($class)
      and $class = ref($class);

    my ($self) = $class->SUPER::new(
        yyversion => '1.05',
        yystates  => [
            {    #State 0
                ACTIONS => {
                    "-"        => 3,
                    ".."       => 1,
                    'DATA_KEY' => 6,
                    "+"        => 5,
                    "{"        => 14,
                    'string'   => 8,
                    "("        => 19,
                    'VAR'      => 20,
                    "false"    => 21,
                    "true"     => 9,
                    "["        => 10,
                    'NUMBER'   => 11
                },
                GOTOS => {
                    'exp'       => 12,
                    'array_str' => 2,
                    'hash_op'   => 13,
                    'array_pos' => 4,
                    'content'   => 7,
                    'data'      => 15,
                    'hash'      => 16,
                    'array_op'  => 17,
                    'string_op' => 18
                }
            },
            {    #State 1
                ACTIONS => {
                    'DATA_KEY' => 23,
                    'NUMBER'   => 24
                },
                GOTOS => { 'array_pos' => 22 }
            },
            {    #State 2
                DEFAULT => -44
            },
            {    #State 3
                ACTIONS => {
                    "-"      => 3,
                    "("      => 19,
                    'VAR'    => 20,
                    "+"      => 5,
                    "false"  => 21,
                    "true"   => 9,
                    'NUMBER' => 25
                },
                GOTOS => { 'exp' => 26 }
            },
            {    #State 4
                ACTIONS => { ".." => 27 }
            },
            {    #State 5
                ACTIONS => {
                    "-"      => 3,
                    "("      => 19,
                    'VAR'    => 20,
                    "+"      => 5,
                    "false"  => 21,
                    "true"   => 9,
                    'NUMBER' => 25
                },
                GOTOS => { 'exp' => 28 }
            },
            {    #State 6
                ACTIONS => { ".." => -48 },
                DEFAULT => -2
            },
            {    #State 7
                ACTIONS => { '' => 29 }
            },
            {    #State 8
                DEFAULT => -32
            },
            {    #State 9
                DEFAULT => -13
            },
            {    #State 10
                ACTIONS => {
                    "-"      => 3,
                    "+"      => 5,
                    "{"      => 14,
                    'string' => 32,
                    "("      => 19,
                    'VAR'    => 20,
                    "false"  => 21,
                    "true"   => 9,
                    "["      => 33,
                    'NUMBER' => 25,
                    "]"      => 34
                },
                GOTOS => {
                    'hash'          => 16,
                    'exp'           => 35,
                    'array_str'     => 30,
                    'sequence_item' => 37,
                    'hash_op'       => 36,
                    'sequence'      => 31,
                    'hashes'        => 38
                }
            },
            {    #State 11
                ACTIONS => { ".." => -47 },
                DEFAULT => -10
            },
            {    #State 12
                ACTIONS => {
                    "-" => 39,
                    "+" => 40,
                    "/" => 44,
                    "%" => 41,
                    "^" => 42,
                    "*" => 43
                },
                DEFAULT => -6
            },
            {    #State 13
                ACTIONS => { "+" => 45 },
                DEFAULT => -4
            },
            {    #State 14
                ACTIONS => { 'string' => 46 },
                GOTOS   => {
                    'hashvalue'  => 47,
                    'hashvalues' => 48
                }
            },
            {    #State 15
                DEFAULT => -1
            },
            {    #State 16
                DEFAULT => -38
            },
            {    #State 17
                DEFAULT => -5
            },
            {    #State 18
                ACTIONS => {
                    "+"      => 49,
                    'string' => 50
                },
                DEFAULT => -3
            },
            {    #State 19
                ACTIONS => {
                    "-"      => 3,
                    "("      => 19,
                    'VAR'    => 20,
                    "+"      => 5,
                    "false"  => 21,
                    "true"   => 9,
                    'NUMBER' => 25
                },
                GOTOS => { 'exp' => 51 }
            },
            {    #State 20
                ACTIONS => { "=" => 52 },
                DEFAULT => -11
            },
            {    #State 21
                DEFAULT => -14
            },
            {    #State 22
                DEFAULT => -46
            },
            {    #State 23
                DEFAULT => -48
            },
            {    #State 24
                DEFAULT => -47
            },
            {    #State 25
                DEFAULT => -10
            },
            {    #State 26
                ACTIONS => {
                    "-" => 39,
                    "+" => 40,
                    "/" => 44,
                    "%" => 41,
                    "^" => 42,
                    "*" => 43
                },
                DEFAULT => -19
            },
            {    #State 27
                ACTIONS => {
                    'DATA_KEY' => 23,
                    'NUMBER'   => 24
                },
                GOTOS => { 'array_pos' => 53 }
            },
            {    #State 28
                ACTIONS => {
                    "-" => 39,
                    "+" => 40,
                    "/" => 44,
                    "%" => 41,
                    "^" => 42,
                    "*" => 43
                },
                DEFAULT => -20
            },
            {    #State 29
                DEFAULT => 0
            },
            {    #State 30
                DEFAULT => -24
            },
            {    #State 31
                ACTIONS => { "]" => 54 }
            },
            {    #State 32
                DEFAULT => -26
            },
            {    #State 33
                ACTIONS => {
                    "-"      => 3,
                    "+"      => 5,
                    'string' => 32,
                    "("      => 19,
                    'VAR'    => 20,
                    "false"  => 21,
                    "true"   => 9,
                    "["      => 33,
                    'NUMBER' => 25,
                    "]"      => 34
                },
                GOTOS => {
                    'exp'           => 35,
                    'array_str'     => 30,
                    'sequence_item' => 37,
                    'sequence'      => 31
                }
            },
            {    #State 34
                DEFAULT => -29
            },
            {    #State 35
                ACTIONS => {
                    "-" => 39,
                    "+" => 40,
                    "/" => 44,
                    "%" => 41,
                    "^" => 42,
                    "*" => 43
                },
                DEFAULT => -25
            },
            {    #State 36
                ACTIONS => { "+" => 45 },
                DEFAULT => -36
            },
            {    #State 37
                ACTIONS => { "," => 55 },
                DEFAULT => -27
            },
            {    #State 38
                ACTIONS => {
                    "," => 56,
                    "]" => 57
                }
            },
            {    #State 39
                ACTIONS => {
                    "-"      => 3,
                    "("      => 19,
                    'VAR'    => 20,
                    "+"      => 5,
                    "false"  => 21,
                    "true"   => 9,
                    'NUMBER' => 25
                },
                GOTOS => { 'exp' => 58 }
            },
            {    #State 40
                ACTIONS => {
                    "-"      => 3,
                    "("      => 19,
                    'VAR'    => 20,
                    "+"      => 5,
                    "false"  => 21,
                    "true"   => 9,
                    'NUMBER' => 25
                },
                GOTOS => { 'exp' => 59 }
            },
            {    #State 41
                ACTIONS => {
                    "-"      => 3,
                    "("      => 19,
                    'VAR'    => 20,
                    "+"      => 5,
                    "false"  => 21,
                    "true"   => 9,
                    'NUMBER' => 25
                },
                GOTOS => { 'exp' => 60 }
            },
            {    #State 42
                ACTIONS => {
                    "-"      => 3,
                    "("      => 19,
                    'VAR'    => 20,
                    "+"      => 5,
                    "false"  => 21,
                    "true"   => 9,
                    'NUMBER' => 25
                },
                GOTOS => { 'exp' => 61 }
            },
            {    #State 43
                ACTIONS => {
                    "-"      => 3,
                    "("      => 19,
                    'VAR'    => 20,
                    "+"      => 5,
                    "false"  => 21,
                    "true"   => 9,
                    'NUMBER' => 25
                },
                GOTOS => { 'exp' => 62 }
            },
            {    #State 44
                ACTIONS => {
                    "-"      => 3,
                    "("      => 19,
                    'VAR'    => 20,
                    "+"      => 5,
                    "false"  => 21,
                    "true"   => 9,
                    'NUMBER' => 25
                },
                GOTOS => { 'exp' => 63 }
            },
            {    #State 45
                ACTIONS => { "{"    => 14 },
                GOTOS   => { 'hash' => 64 }
            },
            {    #State 46
                ACTIONS => { ":" => 65 }
            },
            {    #State 47
                DEFAULT => -41
            },
            {    #State 48
                ACTIONS => {
                    "}" => 66,
                    "," => 67
                }
            },
            {    #State 49
                ACTIONS => { 'string' => 68 }
            },
            {    #State 50
                DEFAULT => -33
            },
            {    #State 51
                ACTIONS => {
                    "-" => 39,
                    "^" => 42,
                    "*" => 43,
                    "+" => 40,
                    "/" => 44,
                    "%" => 41,
                    ")" => 69
                }
            },
            {    #State 52
                ACTIONS => {
                    "-"      => 3,
                    "("      => 19,
                    'VAR'    => 20,
                    "+"      => 5,
                    "false"  => 21,
                    "true"   => 9,
                    'NUMBER' => 25
                },
                GOTOS => { 'exp' => 70 }
            },
            {    #State 53
                DEFAULT => -45
            },
            {    #State 54
                ACTIONS => { "+" => 71 },
                DEFAULT => -30
            },
            {    #State 55
                ACTIONS => {
                    "-"      => 3,
                    "+"      => 5,
                    'string' => 32,
                    "("      => 19,
                    'VAR'    => 20,
                    "false"  => 21,
                    "true"   => 9,
                    "["      => 33,
                    'NUMBER' => 25
                },
                GOTOS => {
                    'exp'           => 35,
                    'array_str'     => 30,
                    'sequence_item' => 37,
                    'sequence'      => 72
                }
            },
            {    #State 56
                ACTIONS => { "{" => 14 },
                GOTOS   => {
                    'hash'    => 16,
                    'hash_op' => 73
                }
            },
            {    #State 57
                DEFAULT => -43
            },
            {    #State 58
                ACTIONS => {
                    "/" => 44,
                    "%" => 41,
                    "^" => 42,
                    "*" => 43
                },
                DEFAULT => -16
            },
            {    #State 59
                ACTIONS => {
                    "/" => 44,
                    "%" => 41,
                    "^" => 42,
                    "*" => 43
                },
                DEFAULT => -15
            },
            {    #State 60
                ACTIONS => { "^" => 42 },
                DEFAULT => -23
            },
            {    #State 61
                DEFAULT => -21
            },
            {    #State 62
                ACTIONS => { "^" => 42 },
                DEFAULT => -17
            },
            {    #State 63
                ACTIONS => { "^" => 42 },
                DEFAULT => -18
            },
            {    #State 64
                DEFAULT => -39
            },
            {    #State 65
                ACTIONS => {
                    "-"        => 3,
                    ".."       => 1,
                    "+"        => 5,
                    'DATA_KEY' => 23,
                    'string'   => 74,
                    "("        => 19,
                    'VAR'      => 20,
                    "false"    => 21,
                    "true"     => 9,
                    "["        => 10,
                    'NUMBER'   => 11
                },
                GOTOS => {
                    'array_op'  => 77,
                    'exp'       => 75,
                    'array_str' => 2,
                    'array_pos' => 4,
                    'value'     => 76
                }
            },
            {    #State 66
                DEFAULT => -35
            },
            {    #State 67
                ACTIONS => { 'string'    => 46 },
                GOTOS   => { 'hashvalue' => 78 }
            },
            {    #State 68
                DEFAULT => -34
            },
            {    #State 69
                DEFAULT => -22
            },
            {    #State 70
                DEFAULT => -12
            },
            {    #State 71
                ACTIONS => { "["         => 33 },
                GOTOS   => { 'array_str' => 79 }
            },
            {    #State 72
                DEFAULT => -28
            },
            {    #State 73
                ACTIONS => { "+" => 45 },
                DEFAULT => -37
            },
            {    #State 74
                DEFAULT => -9
            },
            {    #State 75
                ACTIONS => {
                    "-" => 39,
                    "+" => 40,
                    "/" => 44,
                    "%" => 41,
                    "^" => 42,
                    "*" => 43
                },
                DEFAULT => -8
            },
            {    #State 76
                DEFAULT => -40
            },
            {    #State 77
                DEFAULT => -7
            },
            {    #State 78
                DEFAULT => -42
            },
            {    #State 79
                DEFAULT => -31
            }
        ],
        yyrules => [
            [    #Rule 0
                '$start', 2, undef
            ],
            [    #Rule 1
                'content', 1,
                sub
#line 37 "AttributeParserGrammar.yp"
                {
                    $_[0]->{data} = $_[1];
                  }
            ],
            [    #Rule 2
                'data', 1,
                sub
#line 41 "AttributeParserGrammar.yp"
                {
                    $_[0]->_value( $_[1] );
                  }
            ],
            [    #Rule 3
                'data', 1, undef
            ],
            [    #Rule 4
                'data', 1, undef
            ],
            [    #Rule 5
                'data', 1, undef
            ],
            [    #Rule 6
                'data', 1, undef
            ],
            [    #Rule 7
                'value', 1,
                sub
#line 54 "AttributeParserGrammar.yp"
                {
                    $_[1];
                  }
            ],
            [    #Rule 8
                'value', 1, undef
            ],
            [    #Rule 9
                'value', 1,
                sub
#line 59 "AttributeParserGrammar.yp"
                {
                    $_[1];
                  }
            ],
            [    #Rule 10
                'exp', 1, undef
            ],
            [    #Rule 11
                'exp', 1,
                sub
#line 65 "AttributeParserGrammar.yp"
                {
                    $_[0]->{data}->{ $_[1] };
                  }
            ],
            [    #Rule 12
                'exp', 3,
                sub
#line 68 "AttributeParserGrammar.yp"
                {
                    $_[0]->{data}->{ $_[1] } = $_[3];
                  }
            ],
            [    #Rule 13
                'exp', 1,
                sub
#line 71 "AttributeParserGrammar.yp"
                {
                    1;
                  }
            ],
            [    #Rule 14
                'exp', 1,
                sub
#line 74 "AttributeParserGrammar.yp"
                {
                    0;
                  }
            ],
            [    #Rule 15
                'exp', 3,
                sub
#line 76 "AttributeParserGrammar.yp"
                {
                    $_[1] + $_[3];
                  }
            ],
            [    #Rule 16
                'exp', 3,
                sub
#line 78 "AttributeParserGrammar.yp"
                {
                    $_[1] - $_[3];
                  }
            ],
            [    #Rule 17
                'exp', 3,
                sub
#line 80 "AttributeParserGrammar.yp"
                {
                    $_[1] * $_[3];
                  }
            ],
            [    #Rule 18
                'exp', 3,
                sub
#line 82 "AttributeParserGrammar.yp"
                {
                    $_[1] / $_[3];
                  }
            ],
            [    #Rule 19
                'exp', 2,
                sub
#line 84 "AttributeParserGrammar.yp"
                {
                    -$_[2];
                  }
            ],
            [    #Rule 20
                'exp', 2,
                sub
#line 86 "AttributeParserGrammar.yp"
                {
                    $_[2];
                  }
            ],
            [    #Rule 21
                'exp', 3,
                sub
#line 88 "AttributeParserGrammar.yp"
                {
                    $_[1]**$_[3];
                  }
            ],
            [    #Rule 22
                'exp', 3,
                sub
#line 90 "AttributeParserGrammar.yp"
                {
                    $_[2];
                  }
            ],
            [    #Rule 23
                'exp', 3,
                sub
#line 92 "AttributeParserGrammar.yp"
                {
                    $_[1] % $_[3];
                  }
            ],
            [    #Rule 24
                'sequence_item', 1, undef
            ],
            [    #Rule 25
                'sequence_item', 1, undef
            ],
            [    #Rule 26
                'sequence_item', 1, undef
            ],
            [    #Rule 27
                'sequence', 1, undef
            ],
            [    #Rule 28
                'sequence', 3,
                sub
#line 105 "AttributeParserGrammar.yp"
                {
                    my $seq = '';
                    $seq .= $_[1] if defined $_[1];
                    $seq .= ', ' if defined $_[1] && defined $_[3];
                    $seq .= $_[3] if defined $_[3];
                    return $seq;
                  }
            ],
            [    #Rule 29
                'array_str', 2,
                sub
#line 114 "AttributeParserGrammar.yp"
                {
                    '';
                  }
            ],
            [    #Rule 30
                'array_str', 3,
                sub
#line 117 "AttributeParserGrammar.yp"
                {
                    "[$_[2]]";
                  }
            ],
            [    #Rule 31
                'array_str', 5,
                sub
#line 120 "AttributeParserGrammar.yp"
                {
                    ( my $items = $_[5] ) =~ s/^\[(.*)\]$/$1/;
                    return "[$_[2], $items]";
                  }
            ],
            [    #Rule 32
                'string_op', 1,
                sub
#line 127 "AttributeParserGrammar.yp"
                {
                    _unquote( $_[1] );
                  }
            ],
            [    #Rule 33
                'string_op', 2,
                sub
#line 130 "AttributeParserGrammar.yp"
                {
                    $_[1] . _unquote( $_[2] );
                  }
            ],
            [    #Rule 34
                'string_op', 3,
                sub
#line 133 "AttributeParserGrammar.yp"
                {
                    _unquote( $_[1] ) . _unquote( $_[3] );
                  }
            ],
            [    #Rule 35
                'hash', 3,
                sub
#line 137 "AttributeParserGrammar.yp"
                {
                    $_[2];
                  }
            ],
            [    #Rule 36
                'hashes', 1,
                sub
#line 140 "AttributeParserGrammar.yp"
                {
                    $_[0]->{workingData}->{'hashes'} ||= ();
                    push @{ $_[0]->{workingData}->{'hashes'} }, $_[1];
                  }
            ],
            [    #Rule 37
                'hashes', 3,
                sub
#line 146 "AttributeParserGrammar.yp"
                {
                    $_[0]->{workingData}->{'hashes'} ||= ();
                    push @{ $_[0]->{workingData}->{'hashes'} }, $_[3];
                  }
            ],
            [    #Rule 38
                'hash_op', 1, undef
            ],
            [    #Rule 39
                'hash_op', 3,
                sub
#line 154 "AttributeParserGrammar.yp"
                {
                    my %merged = ( %{ $_[1] }, %{ $_[3] } );
                    return \%merged;
                  }
            ],
            [    #Rule 40
                'hashvalue', 3,
                sub
#line 160 "AttributeParserGrammar.yp"
                {
                    my $local = { _unquote( $_[1] ) => _unquote( $_[3] ) };
                    return $local;
                  }
            ],
            [    #Rule 41
                'hashvalues', 1, undef
            ],
            [    #Rule 42
                'hashvalues', 3,
                sub
#line 170 "AttributeParserGrammar.yp"
                {
                    my %merged = ( %{ $_[1] }, %{ $_[3] } );
                    return \%merged;
                  }
            ],
            [    #Rule 43
                'array_op', 3,
                sub
#line 177 "AttributeParserGrammar.yp"
                {
                    my @list = @{ $_[0]->{workingData}->{'hashes'} };
                    undef $_[0]->{workingData}->{'hashes'};
                    return \@list;
                  }
            ],
            [    #Rule 44
                'array_op', 1,
                sub
#line 184 "AttributeParserGrammar.yp"
                {
                    _toList( $_[1] );
                  }
            ],
            [    #Rule 45
                'array_op', 3,
                sub
#line 187 "AttributeParserGrammar.yp"
                {
                    my @list;
                    if ( $_[1] > $_[3] ) {
                        @list = ( $_[3] .. $_[1] );
                        @list = reverse(@list);
                    }
                    else {
                        @list = ( $_[1] .. $_[3] );
                    }
                    return \@list;
                  }
            ],
            [    #Rule 46
                'array_op', 2,
                sub
#line 199 "AttributeParserGrammar.yp"
                {
                    my @list = ( 0 .. $_[2] );
                    return \@list;
                  }
            ],
            [    #Rule 47
                'array_pos', 1, undef
            ],
            [    #Rule 48
                'array_pos', 1,
                sub
#line 208 "AttributeParserGrammar.yp"
                {
                    $_[0]->_value( $_[1] );
                  }
            ]
        ],
        @_
    );
    bless( $self, $class );
}

#line 211 "AttributeParserGrammar.yp"

use strict;
use warnings;

use Text::Balanced qw (
  gen_delimited_pat
);
my $p_quotes                = gen_delimited_pat(q{'"});    # generates regex
my $PATTERN_PRESERVE_QUOTES = qr/($p_quotes)/;
my $p_number =
'(?:(?i)(?:[+-]?)(?:(?=[0123456789]|[.])(?:[0123456789]*)(?:(?:[.])(?:[0123456789]{0,}))?)(?:(?:[E])(?:(?:[+-]?)(?:[0123456789]+))|))'
  ; #created with: use Regexp::Common 'RE_ALL'; $PATTERN_NUMBER = $RE{num}{real};
my $PATTERN_NUMBER = qr/($p_number)/;

sub _value {
    my ( $this, $key ) = @_;

    my $value = $this->{data}->{$key};
    if ( defined $value ) {
        if ( UNIVERSAL::isa( $value, "ARRAY" ) ) {
            $this->{workingData}->{tmpData} = \@{$value};
            return \@{$value};
        }
        else {
            $this->{workingData}->{tmpData} = $value;
            return $value;
        }
    }
    my $d = $this->{workingData}->{tmpData};
    $d                              = $this->{data} if !defined $d;
    $value                          = $d->{$key};
    $this->{workingData}->{tmpData} = $value;
    return $value;
}

=pod

Takes a string and returns an array ref.

For example:
	my $str = '["whale", "Barbara", "zeppelin", "aardvark", "beetroot"]';
	my $listref = _toList($str);
	
=cut

sub _toList {
    my ($listString) = @_;

    my @list = @{ eval $listString };
    return \@list;
}

# UTIL FUNCTIONS

sub _unquote {
    my ($string) = @_;

    return '' if !defined $string;

    $string =~ s/^(\"|\')(.*)(\1)$/$2/s;
    return $string;
}

=pod

=cut

sub _interpolateEscapes {
    my ($string) = @_;

    # escaped string: \"
    $string =~ s/\\"/"/go;

    # escaped string: \'
    $string =~ s/\\'/'/go;

    # escaped newline: \n
    $string =~ s/\\n/\n/go;

    # escaped carriage return: \r
    $string =~ s/\\r/\n/go;

    # escaped tab: \t
    $string =~ s/\\t/\t/go;

    # backspace at end of string: \b
    $string =~ s/\\b$/\b /go;

    # backspace: \b
    $string =~ s/\\b/\b/go;

    # form feed: \f
    $string =~ s/\\f/\f/go;

    # less than: \l
    $string =~ s/\\l/</go;

    # greater than: \g
    $string =~ s/\\g/>/go;

    # ampersand: \a
    $string =~ s/\\a/&/go;

    # unicode - not yet supported
    $string =~ s/\\x([0-9a-fA-FX]+)/\\x{$1}/go;

    # escaped backslash: \\
    $string =~ s/\\\\/\\/go;

    return $string;
}

=pod

=cut

sub _lexer {

    #	my ( $parser ) = shift;

    return ( '', undef )
      if !defined $_[0]->YYData->{DATA} || $_[0]->YYData->{DATA} eq '';

    for ( $_[0]->YYData->{DATA} ) {

        print STDERR "_lexer input=$_.\n"
          if ( $_[0]->{debug} || $_[0]->{debugLevel} );

        $_ =~ s/^\s+//;

        return ( '..',     $1 ) if (s/^(\.\.)\s*//);
        return ( '.',      $1 ) if (s/^(\.)\s*//);
        return ( '+',      $1 ) if (s/^(\+)\s*//);
        return ( '-',      $1 ) if (s/^(\-)\s*//);
        return ( '*',      $1 ) if (s/^(\*)\s*//);
        return ( '/',      $1 ) if (s/^(\/)\s*//);
        return ( '%',      $1 ) if (s/^(%)\s*//);
        return ( '?',      $1 ) if (s/^(\?)\s*//);
        return ( 'true',   $1 ) if (s/^(\"*true\"*)\s*//);
        return ( 'false',  $1 ) if (s/^(\"*false\"*)\s*//);
        return ( 'NUMBER', $1 ) if (s/^$PATTERN_NUMBER//);

        return ( 'string', _interpolateEscapes($1) )
          if (s/^$PATTERN_PRESERVE_QUOTES//);

        return ( '=', $1 ) if (s/^(\=)\s*//);
        return ( '[', $1 ) if (s/^(\[)\s*//);
        return ( ']', $1 ) if (s/^(\])\s*//);
        return ( '(', $1 ) if (s/^(\()\s*//);
        return ( ')', $1 ) if (s/^(\))\s*//);
        return ( '{', $1 ) if (s/^(\{)\s*//);
        return ( '}', $1 ) if (s/^(\})//);
        return ( ':', $1 ) if (s/^(:)\s*//);
        return ( ',', $1 ) if (s/^(,)\s*//);

        return ( 'string', "'$1'" ) if (s/^(\w+)//);

        return ( 'string', $1 ) if (s/^(.*)$//s);
    }
}

sub _error {
    exists $_[0]->YYData->{ERRMSG}
      and do {
        print STDERR $_[0]->YYData->{ERRMSG};
        delete $_[0]->YYData->{ERRMSG};
        return;
      };
    print STDERR "Syntax error\n";
}

=pod

parse ($input, \%vars)  -> \%data

=cut

sub parse {

    #my ( $this, $input ) = @_;

    return {} if !defined $_[1] || $_[1] eq '';

    $_[0]->{data} = {};
    $_[0]->{debug}      ||= 0;
    $_[0]->{debugLevel} ||= 0;

    print STDERR "parse:input=$_[1]\n"
      if ( $_[0]->{debug} || $_[0]->{debugLevel} );

    $_[0]->YYData->{DATA} = $_[1];
    $_[0]->YYParse(
        yylex   => \&_lexer,
        yyerror => \&_error,
        yydebug => $_[0]->{debugLevel}
    );

    use Data::Dumper;
    print STDERR "parse:data=" . Dumper( $_[0]->{data} ) . "\n"
      if ( $_[0]->{debug} || $_[0]->{debugLevel} );

    undef $_[0]->{workingData};
    return $_[0]->{data};
}

sub setDebugLevel {
    my ( $this, $debug, $debugLevel ) = @_;

    $this->{debug}      = $debug;
    $this->{debugLevel} = $debugLevel;
}

1;
