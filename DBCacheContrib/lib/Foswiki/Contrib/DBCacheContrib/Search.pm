# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Contrib::DBCacheContrib::Search

Search operators work on the fields of a Foswiki::Contrib::DBCacheContrib::Map.

---++ Example
Get a list of attachments that have a date earlier than 1st January 2000
<verbatim>
  $db = new Foswiki::Contrib::DBCacheContrib::DBCache( $web ); # always done
  $db->load();
  my $search = new Foswiki::Contrib::DBCacheContrib::Search("date EARLIER_THAN '1st January 2000'");

  foreach my $topic ($db->getKeys()) {
     my $attachments = $topic->get("attachments");
     foreach my $val ($attachments->getValues()) {
       if ($search->matches($val)) {
          print $val->get("name") . "\n";
       }
     }
  }
</verbatim>

A search object implements the "matches" method as its general
contract with the rest of the world.

=cut

package Foswiki::Contrib::DBCacheContrib::Search;

use strict;
use Assert;

# Operator precedences
my %operators = (
    'lc'                 => { exec => \&OP_lc,                 prec => 5 },
    'uc'                 => { exec => \&OP_uc,                 prec => 5 },
    '='                  => { exec => \&OP_equal,              prec => 4 },
    '=~'                 => { exec => \&OP_match,              prec => 4 },
    '~'                  => { exec => \&OP_contains,           prec => 4 },
    '!='                 => { exec => \&OP_not_equal,          prec => 4 },
    '>='                 => { exec => \&OP_gtequal,            prec => 4 },
    '<='                 => { exec => \&OP_smequal,            prec => 4 },
    '>'                  => { exec => \&OP_greater,            prec => 4 },
    '<'                  => { exec => \&OP_smaller,            prec => 4 },
    'EARLIER_THAN'       => { exec => \&OP_earlier_than,       prec => 4 },
    'EARLIER_THAN_OR_ON' => { exec => \&OP_earlier_than_or_on, prec => 4 },
    'LATER_THAN'         => { exec => \&OP_later_than,         prec => 4 },
    'LATER_THAN_OR_ON'   => { exec => \&OP_later_than_or_on,   prec => 4 },
    'WITHIN_DAYS'        => { exec => \&OP_within_days,        prec => 4 },
    'IS_DATE'            => { exec => \&OP_is_date,            prec => 4 },
    '!'                  => { exec => \&OP_not,                prec => 3 },
    'AND'                => { exec => \&OP_and,                prec => 2 },
    'OR'                 => { exec => \&OP_or,                 prec => 1 },
    'FALSE'              => { exec => \&OP_false,              prec => 0 },
    'NODE'               => { exec => \&OP_node,               prec => 0 },
    'NUMBER'             => { exec => \&OP_string,             prec => 0 },
    'REF'                => { exec => \&OP_ref,                prec => 0 },
    'STRING'             => { exec => \&OP_string,             prec => 0 },
    'TRUE'               => { exec => \&OP_true,               prec => 0 },
    'd2n'                => { exec => \&OP_d2n,                prec => 5 },
    'length'             => { exec => \&OP_length,             prec => 5 },
    'defined'            => { exec => \&OP_defined,            prec => 5 },
);

my $bopRE =
"AND\\b|OR\\b|!=|=~?|~|<=?|>=?|LATER_THAN\\b|EARLIER_THAN\\b|LATER_THAN_OR_ON\\b|EARLIER_THAN_OR_ON\\b|WITHIN_DAYS\\b|IS_DATE\\b";
my $uopRE = "!|[lu]c\\b|d2n|length|defined";

my $now = time();

# PUBLIC STATIC used for testing only; force 'now' to be a particular
# time.
sub forceTime {
    my $t = shift;

    require Time::ParseDate;

    $now = Time::ParseDate::parsedate($t);
}

=begin TML

---+++ =new($string)=
   * =$string= - string containing an expression to parse
Construct a new search node by parsing the passed expression.

=cut

sub new {
    my ( $class, $string, $left, $op, $right ) = @_;

    my $this;
    if ( defined($string) ) {
        if ( $string =~ m/^\s*$/o ) {
            $this = new Foswiki::Contrib::DBCacheContrib::Search( undef, undef,
                "TRUE", undef );
        }
        else {
            my $rest;
            ( $this, $rest ) = _parse($string);
        }
    }
    else {
        $this          = {};
        $this->{right} = $right;
        $this->{left}  = $left;
        $this->{op}    = $op;
        $this          = bless( $this, $class );
    }
    return $this;
}

sub DESTROY {
    my $this = shift;
    undef $this->{right};
    undef $this->{left};
    undef $this->{op};
}

# PRIVATE STATIC generate a Search by popping the top two operands
# and the top operator. Push the result back onto the operand stack.
sub _apply {
    my ( $opers, $opands ) = @_;
    my $o = pop(@$opers);
    my $r = pop(@$opands);
    ASSERT( defined $r ) if DEBUG;
    die "Bad search" unless defined($r);
    my $l = undef;
    if ( $o =~ /^$bopRE$/o ) {
        $l = pop(@$opands);
        die "Bad search" unless defined($l);
    }
    my $n = new Foswiki::Contrib::DBCacheContrib::Search( undef, $l, $o, $r );
    push( @$opands, $n );
}

# PRIVATE STATIC simple stack parser for grabbing boolean expressions
sub _parse {
    my $string = shift;

    $string .= " ";
    my @opands;
    my @opers;
    while ( $string !~ m/^\s*$/o ) {
        if ( $string =~ s/^\s*($bopRE)//o ) {

            # Binary comparison op
            my $op = $1;
            while ( scalar(@opers) > 0
                && $operators{$op}->{prec} <
                $operators{ $opers[$#opers] }->{prec} )
            {
                _apply( \@opers, \@opands );
            }
            push( @opers, $op );
        }
        elsif ( $string =~ s/^\s*($uopRE)//o ) {

            # unary op
            push( @opers, $1 );
        }
        elsif ( $string =~ s/^\s*\'(.*?)(?<!\\)\'//o ) {
            push(
                @opands,
                new Foswiki::Contrib::DBCacheContrib::Search(
                    undef, undef, "STRING", $1
                )
            );
        }
        elsif ( $string =~ s/^\s*(-?\d+(\.\d*)?(e-?\d+)?)//io ) {
            push(
                @opands,
                new Foswiki::Contrib::DBCacheContrib::Search(
                    undef, undef, "NUMBER", $1
                )
            );
        }
        elsif ( $string =~ s/^\s*(\@\w+(?:\.\w+)+)//o ) {
            push(
                @opands,
                new Foswiki::Contrib::DBCacheContrib::Search(
                    undef, undef, "REF", $1
                )
            );
        }
        elsif ( $string =~ s/^\s*([\w\.]+)//o ) {
            push(
                @opands,
                new Foswiki::Contrib::DBCacheContrib::Search(
                    undef, undef, "NODE", $1
                )
            );
        }
        elsif ( $string =~ s/^\s*\(//o ) {
            my $oa;
            ( $oa, $string ) = _parse($string);
            push( @opands, $oa );
        }
        elsif ( $string =~ s/^\s*\)//o ) {
            last;
        }
        else {
            return ( undef, "Parser stuck at $string" );
        }
    }
    while ( scalar(@opers) > 0 ) {
        _apply( \@opers, \@opands );
    }
    ASSERT( scalar(@opands) == 1 ) if DEBUG;
    die "Bad search" unless ( scalar(@opands) == 1 );
    return ( pop(@opands), $string );
}

sub matches {
    my ( $this, $map ) = @_;

    my $handler = $operators{ $this->{op} };
    return 0 unless $handler;
    return $handler->{exec}( $this->{right}, $this->{left}, $map );
}

sub OP_true { return 1; }

sub OP_false { return 0; }

sub OP_string { return $_[0]; }

sub OP_number { return $_[0]; }

sub OP_or {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $l;

    my $lval = $l->matches($map);
    return 1 if $lval;

    return undef unless defined $r;

    my $rval = $r->matches($map);
    return 1 if $rval;

    return 0;
}

sub OP_and {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $l;

    my $lval = $l->matches($map);
    return 0 unless $lval;

    return undef unless defined $r;

    my $rval = $r->matches($map);
    return 1 if $rval;

    return 0;
}

sub OP_not {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $r;

    return ( $r->matches($map) ) ? 0 : 1;
}

sub OP_lc {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $r;

    my $rval = $r->matches($map);
    return undef unless defined $rval;

    return lc( $rval );
}

sub OP_uc {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $r;

    my $rval = $r->matches($map);
    return undef unless defined $rval;

    return uc( $rval );
}

sub OP_i2d {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $r;

    my $rval = $r->matches($map);
    return undef unless defined $rval;

    return Foswiki::Time::formatTime( $rval, '$email', 'gmtime' );
}

sub OP_d2n {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $r;

    my $rval = $r->matches($map);
    return undef unless defined $rval;

    return $rval if $rval =~ /^\d+$/;
    require Foswiki::Time;
    return Foswiki::Time::parseTime( $rval, 1 );
}

sub OP_length {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $r;

    my $rval = $r->matches($map);
    return undef unless defined $rval;

    if ( ref($rval) eq 'ARRAY' ) {
        return scalar(@$rval);
    }
    elsif ( ref($rval) eq 'HASH' ) {
        return scalar( keys %$rval );
    }
    else {
        return length($rval);
    }
}

sub OP_defined {
    my ( $r, $l, $map ) = @_;

    return 0 unless defined $r;

    my $rval = $r->matches($map);
    return 0 unless defined $rval;

    return 1;
}

sub OP_node {
    my ( $r, $l, $map ) = @_;

    return undef unless ( $map && defined $r );

    # Only reference the hash if the contained form does not
    # define the field
    my $form = $map->get("form");
    my $val;
    $form = $map->get($form) if $form;
    $val  = $form->get($r) if $form;
    $val = $map->get($r) unless defined $val;

    return $val;
}

sub OP_ref {
    my ( $r, $l, $map ) = @_;

    return undef unless ( $map && defined $r );

    # get web db
    my $web = $map->FETCH('_web');

    # parse reference chain
    my %seen;
    while ( $r =~ /^\@(\w+)\.(.*)$/ ) {
        my $ref = $1;
        $r = $2;

        # protect against infinite loops
        return undef if $seen{$ref};    # outch
        $seen{$ref} = 1;

        # get form
        my $form = $map->FETCH('form');
        return undef unless $form;      # no form

        # get refered topic
        $form = $map->FETCH($form);
        $ref  = $form->FETCH($ref);
        return undef unless $ref;       # unknown field

        # get topic object
        $map = $web->FETCH($ref);
        return undef unless $map;       # unknown ref
    }

    # the tail is a property of the referenced topic
    my $val = $map->get( $map->get("form") )->get($r);
    unless ($val) {
        $val = $map->get($r);
    }
    return $val;
}

sub OP_equal {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $l && defined $r;

    my $lval = $l->matches($map);
    my $rval = $r->matches($map);

    return 1 if !defined($lval) && !defined($rval);
    return 0 if !defined $lval || !defined($rval);

    return ( $lval =~ m/^$rval$/ ) ? 1 : 0;
}

sub OP_not_equal {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $l && defined $r;

    my $lval = $l->matches($map);
    my $rval = $r->matches($map);

    return 0 if !defined($lval) && !defined($rval);
    return 1 if !defined $lval || !defined($rval);

    return ( $lval =~ m/^$rval$/ ) ? 0 : 1;
}

sub OP_match {
    my ( $r, $l, $map ) = @_;
    
    return undef unless defined $l;

    my $lval = $l->matches($map);
    return 0 unless defined $lval;

    return undef unless defined $r;

    my $rval = $r->matches($map);
    return 0 unless defined $rval;

    return ( $lval =~ m/$rval/ ) ? 1 : 0;
}

sub OP_contains {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $l && defined $r;

    my $lval = $l->matches($map);
    return 0 unless defined $lval;

    my $rval = $r->matches($map);
    return undef unless defined $rval;

    $rval =~ s/\./\\./g;
    $rval =~ s/\?/./g;
    $rval =~ s/\*/.*/g;

    return ( $lval =~ m/$rval/ ) ? 1 : 0;
}

sub OP_greater {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $l && defined $r;

    my $lval = $l->matches($map);
    return undef unless defined $lval;

    my $rval = $r->matches($map);
    return undef unless defined $rval;

    return ( $lval > $rval ) ? 1 : 0;
}

sub OP_smaller {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $l && defined $r;

    my $lval = $l->matches($map);
    return undef unless defined $lval;

    my $rval = $r->matches($map);
    return undef unless defined $rval;

    return ( $lval < $rval ) ? 1 : 0;
}

sub OP_gtequal {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $l && defined $r;

    my $lval = $l->matches($map);
    return undef unless defined $lval;

    my $rval = $r->matches($map);
    return undef unless defined $rval;

    return ( $lval >= $rval ) ? 1 : 0;
}

sub OP_smequal {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $l && defined $r;

    my $lval = $l->matches($map);
    return undef unless defined $lval;

    my $rval = $r->matches($map);
    return undef unless defined $rval;

    return ( $lval <= $rval ) ? 1 : 0;
}

sub OP_within_days {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $l && defined $r;

    my $lval = $l->matches($map);
    return undef unless defined $lval;

    if ( $lval && $lval !~ /^-?\d+$/ ) {
        require Time::ParseDate;
        $lval = Time::ParseDate::parsedate($lval);
    }
    return undef unless defined $lval;

    my $rval = $r->matches($map);
    return undef unless defined $rval;

    return ( $lval >= $now && workingDays( $now, $lval ) <= $rval ) ? 1 : 0;
}

sub OP_later_than {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $l && defined $r;

    my $lval = $l->matches($map);
    return undef unless defined $lval;

    if ( $lval && $lval !~ /^-?\d+$/ ) {
        require Time::ParseDate;
        $lval = Time::ParseDate::parsedate($lval);
    }
    return undef unless defined $lval;
    return undef if $lval !~ /^[+-]?\d+$/;

    my $rval = $r->matches($map);
    return undef unless defined $rval;

    if ( $rval && $rval !~ /^-?\d+$/ ) {
        require Time::ParseDate;
        $rval = Time::ParseDate::parsedate($rval);
    }
    return undef unless defined $rval;
    return undef if $rval !~ /^[+-]?\d+$/;

    return ( $lval > $rval ) ? 1 : 0;
}

sub OP_later_than_or_on {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $l && defined $r;

    my $lval = $l->matches($map);
    return undef unless defined $lval;

    if ( $lval && $lval !~ /^-?\d+$/ ) {
        require Time::ParseDate;
        $lval = Time::ParseDate::parsedate($lval);
    }
    return undef unless defined $lval;
    return undef if $lval !~ /^[+-]?\d+$/;

    my $rval = $r->matches($map);
    return undef unless defined $rval;
    if ( $rval && $rval !~ /^-?\d+$/ ) {
        require Time::ParseDate;
        $rval = Time::ParseDate::parsedate($rval);
    }
    return undef unless defined $rval;
    return undef if $rval !~ /^[+-]?\d+$/;

    return ( $lval >= $rval ) ? 1 : 0;
}

sub OP_earlier_than {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $l && defined $r;

    my $lval = $l->matches($map);
    return undef unless defined $lval;

    if ( $lval && $lval !~ /^-?\d+$/ ) {
        require Time::ParseDate;
        $lval = Time::ParseDate::parsedate($lval);
    }
    return undef unless defined $lval;
    return undef if $lval !~ /^[+-]?\d+$/;

    my $rval = $r->matches($map);
    return undef unless defined $rval;
    if ( $rval && $rval !~ /^-?\d+$/ ) {
        require Time::ParseDate;
        $rval = Time::ParseDate::parsedate($rval);
    }
    return undef unless defined $rval;
    return undef if $rval !~ /^[+-]?\d+$/;

    return ( $lval < $rval ) ? 1 : 0;
}

sub OP_earlier_than_or_on {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $l && defined $r;

    my $lval = $l->matches($map);
    return undef unless defined $lval;

    if ( $lval && $lval !~ /^-?\d+$/ ) {
        require Time::ParseDate;
        $lval = Time::ParseDate::parsedate($lval);
    }
    return undef unless defined $lval;
    return undef if $lval !~ /^[+-]?\d+$/;

    my $rval = $r->matches($map);
    return undef unless defined $rval;
    if ( $rval && $rval !~ /^-?\d+$/ ) {
        require Time::ParseDate;
        $rval = Time::ParseDate::parsedate($rval);
    }
    return undef unless defined $rval;
    return undef if $rval !~ /^[+-]?\d+$/;

    return ( $lval <= $rval ) ? 1 : 0;
}

sub OP_is_date {
    my ( $r, $l, $map ) = @_;

    return undef unless defined $l && $r;

    my $lval = $l->matches($map);
    return undef unless defined $lval;
    if ( $lval && $lval !~ /^-?\d+$/ ) {
        require Time::ParseDate;
        $lval = Time::ParseDate::parsedate($lval);
    }
    return 0 unless ( defined($lval) );

    my $rval = $r->matches($map);
    return undef unless defined $rval;
    if ( $rval && $rval !~ /^-?\d+$/ ) {
        require Time::ParseDate;
        $rval = Time::ParseDate::parsedate($rval);
    }
    return undef unless defined $rval;

    return ( $lval == $rval ) ? 1 : 0;
}

# PUBLIC STATIC calculate working days between two times
# Published because it's useful elsewhere
sub workingDays {
    my ( $start, $end ) = @_;

    use integer;
    my $elapsed_days = ( $end - $start ) / ( 60 * 60 * 24 );

    # total number of elapsed 7-day weeks
    my $whole_weeks = $elapsed_days / 7;
    my $extra_days = $elapsed_days - ( $whole_weeks * 7 );
    if ( $extra_days > 0 ) {
        my @lt   = localtime($start);
        my $wday = $lt[6];              # weekday, 0 is sunday

        if ( $wday == 0 ) {
            $extra_days-- if ( $extra_days > 0 );
        }
        else {
            $extra_days-- if ( $extra_days > ( 6 - $wday ) );
            $extra_days-- if ( $extra_days > ( 6 - $wday ) );
        }
    }
    return $whole_weeks * 5 + $extra_days;
}

=begin TML

---+++ =toString()= -> string
Generates a string representation of the object.

=cut

sub toString {
    my $this = shift;

    my $text = "";
    if ( defined( $this->{left} ) ) {
        if ( !ref( $this->{left} ) ) {
            $text .= $this->{left};
        }
        else {
            $text .= "(" . $this->{left}->toString() . ")";
        }
        $text .= " ";
    }
    $text .= $this->{op};
    if ( defined $this->{right} ) {
        $text .= " ";
        if ( !ref( $this->{right} ) ) {
            $text .= "'" . $this->{right} . "'";
        }
        else {
            $text .= "(" . $this->{right}->toString() . ")";
        }
    }
    return $text;
}

=begin TML

--+++ =addOperator(%oper)
Add an operator to the parser

=%oper= is a hash, containing the following fields:
   * =name= - operator string
   * =prec= - operator precedence, positive non-zero integer.
     Larger number => higher precedence.
   * =arity= - set to 1 if this operator is unary, 2 for binary. Arity 0
     is legal, should you ever need it.
   * =exec= - the handler to implement the new operator

=cut

sub addOperator {
    my %oper = @_;

    my $name = $oper{name};
    die "illegal operator definition" unless $name;

    $operators{$name} = \%oper;

    if ( $oper{arity} == 2 ) {
        $bopRE .= "|\\b$name\\b";
    }
    elsif ( $oper{arity} == 1 ) {
        $uopRE .= "|\\b$name\\b";
    }
    else {
        die "illegal operator definition";
    }
}

1;
__END__

Copyright (C) Crawford Currie 2004-2009, http://c-dot.co.uk
and Foswiki Contributors. Foswiki Contributors are listed in the
AUTHORS file in the root of this distribution. NOTE: Please extend
that file, not this notice.

Additional copyrights apply to some or all of the code in this module
as follows:
   * Copyright (C) Motorola 2003 - All rights reserved

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
