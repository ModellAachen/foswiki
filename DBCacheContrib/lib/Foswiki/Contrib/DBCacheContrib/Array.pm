# See bottom of file for license and copyright information

=begin TML

---++ package Foswiki::Contrib::DBCacheContrib::Array

This is an interface that is implemented by all back-end stores
(archivists). Objects of this class can be tied to perl arrays.

Objects of this class are created using the =newArray= interface defined
by =Foswiki::Contrib::DBCacheContrib::Archivist=. You can use references
in the content of an Array, but you can only refer to other objects that
were created using the same Archivist. If you point anywhere else, expect
fireworks. Note that all references stored in an Array are strong references
(see the doc on Foswiki::Contrib::DBCacheContrib::Map for more information
on what that means).

If you have an object ($obj) created this way, you can tie it to a perl array
like this:
<verbatim>
my @array;
tie(@array, ref($obj), $obj);
</verbatim>

=cut

package Foswiki::Contrib::DBCacheContrib::Array;

use strict;

use Tie::Array ();
# Mixin archivability
use Foswiki::Contrib::DBCacheContrib::Archivable ();

our @ISA = ('Tie::Array', 'Foswiki::Contrib::DBCacheContrib::Archivable');

use Assert;

use Foswiki::Contrib::DBCacheContrib::Search ();

# This is a virtual base class. See MemArray for an example implementation.
# To operate as a tie, subclasses must implement the methods of
# Tie::Array, except TIEARRAY, and must implement new(). Additional new()
# parameters are passed by name.

sub new {
    my $class = shift;
    my %args  = @_;
    my $this  = bless( {}, $class );
    return $this;
}

sub TIEARRAY {
    my $class = shift;
    my %args  = @_;
    return $class->new(@_);
}

# Synonym for FETCH, maintained for compatibility
sub fastget {
    my $this = shift;
    return $this->FETCH(@_);
}

sub equals {
    my ( $this, $that ) = @_;
    return $this == $that;
}

=begin TML

---+++ =find($object)= -> integer
   * $object datum of the same type as the content of the array
Uses =equals= to find the given element in the array and return its index

=cut

sub find {
    my ( $this, $obj ) = @_;
    my $n = $this->FETCHSIZE();
    for ( my $i = 0 ; $i < $n ; $i++ ) {
        my $nobj = $this->FETCH($i);
        return $i if ( $obj->equals($nobj) );
    }
    return -1;
}

=begin TML

---+++ =getValues() -> @values=
Overridable method that returns a list even when the object isn't tied.

=cut

sub getValues {
    my $this = shift;
    return @$this;
}

=begin TML

---+++ =add($object)=
   * =$object= any perl data type
Add an element to the end of the array

=cut

sub add {
    my $this = shift;
    return $this->PUSH(shift);
}

=begin TML

---+++ =remove($index)=
   * =$index= - integer index
Remove an entry at an index from the array.

=cut

sub remove {
    my ( $this, $i ) = @_;
    $this->SPLICE( $i, 1 );
}

=begin TML

---+++ =get($key, $root)= -> datum
   * =$k= - key
   * $root - what # refers to
*Subfield syntax*
   * =get("9", $r)= where $n is a number will get the 9th entry in the array
   * =get("[9]", $r)= will also get the 9th entry
   * =get(".9", $r)= will also get the 9th entry
   * =get(".X", $r)= will return the sum of the subfield =X= of each entry
   * =get("[?<i>search</i>]", $r)= will perform the given search over the entries in the array. Always returns an array result, even when there is only one result. For example: <code>[?name='Sam']</code> will return an array of all the entries that have their subfield =name= set to =Sam=.
   * =#= means "reset to root". So =get("#[3]", $r)= will return the 4th entry of $r (assuming $r is an array!).
   * =get("[*X]", $r)= will get a new array made from subfield X of each entry in this array.

Where the result of a subfield expansion is another object (a Map or an Array) then further subfield expansions can be used. For example,
<verbatim>
get("parent.UserTable[?SubTopic='ThisTopic'].UserName", $web);
</verbatim>

See also =Foswiki::Contrib::DBCacheContrib::Map= for syntax that applies to maps.

=cut

sub get {
    my ( $this, $key, $root ) = @_;

    # Field
    my $res;
    if ( $key =~ m/^(\d+)(.*)/o ) {

        #print STDERR "Index shortcut $1\n";
        return undef unless ( $this->FETCHSIZE() > $1 );
        my $field = $this->FETCH($1);
        if ( $2 && ref($field) ) {

            #print STDERR "\t...$2\n";
            $res = $field->get( $2, $root );
        }
        else {
            $res = $field;
        }
    }
    elsif ( $key =~ m/^\.(.*)$/o ) {

        #print STDERR ".$1\n";
        $res = $this->get( $1, $root );
    }
    elsif ( $key =~ /^(\w+)$/o ) {

        #print STDERR "sum $1\n";
        $res = $this->sum($key);
    }
    elsif ( $key =~ m/^\[\*(.+)$/o ) {
        my ( $one, $two ) = mbrf( "[", "]", $1 );

        #print STDERR "All $one\n";
        require Foswiki::Contrib::DBCacheContrib::MemArray;
        $res = new Foswiki::Contrib::DBCacheContrib::MemArray();
        my $n = $this->FETCHSIZE();
        for ( my $i = 0 ; $i < $n ; $i++ ) {
            my $meta = $this->FETCH($i);
            if ( ref($meta) ) {
                my $fieldval = $meta->get( $one, $root );
                if ( defined($fieldval) ) {
                    $res->add($fieldval);
                }
            }
        }
    }
    elsif ( $key =~ m/^\[(\w+)\](.*)$/o ) {

        #print STDERR "[$1]\n";
        my $field = $this->get( $1, $root );
        if ( $2 && ref($field) ) {

            #print STDERR "\t...$2\n";
            $res = $field->get( $2, $root );
        }
        else {
            $res = $field;
        }
    }
    elsif ( $key =~ m/^\[\??(.+)$/o ) {
        my ( $one, $two ) = mbrf( "[", "]", $1 );

        #print STDERR "Search $one\n";
        $res =
          $this->search( new Foswiki::Contrib::DBCacheContrib::Search($one) );
        if ( $two && ref($res) ) {

            #print STDERR "\t...$two\n";
            $res = return $res->get($two);
        }
    }
    elsif ( $key =~ m/^#(.*)$/o ) {

        #print STDERR "#$1\n";
        $res = $root->get( $1, $root );
    }
    else {
        die "ERROR: bad Array expression at $key";
    }

    #print STDERR "\t-> $res\n";
    return $res;
}

=begin TML

---+++ =size()= -> integer
Get the size of the array

=cut

sub size {
    my $this = shift;
    return $this->FETCHSIZE();
}

=begin TML

---+++ =sum($field)= -> number
   * =$field= - name of a field in the class of objects stored by this array
Returns the sum of values of the given field in the objects stored in this array.

=cut

sub sum {
    my ( $this, $field ) = @_;
    return 0 if ( $this->FETCHSIZE() == 0 );

    my $sum = 0;
    my $subfields;

    if ( $field =~ s/(\w+)\.(.*)/$1/o ) {
        $subfields = $2;
    }

    my $n = $this->FETCHSIZE();
    for ( my $i = 0 ; $i < $n ; $i++ ) {
        my $meta = $this->FETCH($i);
        if ( ref($meta) ) {
            my $fieldval = $meta->get( $field, undef );
            next unless defined $fieldval;
            if ( defined($subfields) ) {
                die "$field has no subfield $subfields"
                  unless ( ref($fieldval) );
                $sum += $fieldval->sum($subfields);
            } elsif ( $fieldval =~
                        m/^\s*[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?/ ) {
                $sum += $fieldval;
            }
        }
    }

    return $sum;
}

=begin TML

---+++ =search($search)= -> search result
   * =$search= - Foswiki::Contrib::DBCacheContrib::Search object to use in the search
Search the array for matches with the given object.
values. Return a =Foswiki::Contrib::DBCacheContrib::Array= of matching entries.

=cut

sub search {
    my ( $this, $search ) = @_;
    ASSERT($search) if DEBUG;

    # Result set not created in the archive
    require Foswiki::Contrib::DBCacheContrib::MemArray;
    my $result = new Foswiki::Contrib::DBCacheContrib::MemArray();

    return $result unless ( $this->FETCHSIZE() > 0 );

    my $n = $this->FETCHSIZE();
    for ( my $i = 0 ; $i < $n ; $i++ ) {
        my $meta = $this->FETCH($i);
        if ( $search->matches($meta) ) {
            $result->add($meta);
        }
    }

    return $result;
}

=begin TML

---+++ =toString($limit, $level, $strung)= -> string
   * =$limit= - recursion limit for expansion of elements
   * =$level= - currentl recursion level
Generates an HTML string representation of the object.

=cut

sub toString {
    my ( $this, $limit, $level, $strung ) = @_;

    if ( !defined($strung) ) {
        $strung = {};
    }
    elsif ( $strung->{$this} ) {
        return $this;
    }
    $level = 0 unless ( defined($level) );
    $limit = 2 unless ( defined($limit) );
    if ( $level == $limit ) {
        return "$this.....";
    }
    $strung->{$this} = 1;
    my $ss = '';
    if ( $this->FETCHSIZE() > 0 ) {
        my $n  = 0;
        my $sz = $this->FETCHSIZE();
        for ( my $i = 0 ; $i < $sz ; $i++ ) {
            my $entry = $this->FETCH($i);
            my $item  = '';
            if ( ref($entry) ) {
                $item .= $entry->toString( $limit, $level + 1, $strung );
            }
            elsif ( defined($entry) ) {
                $item .= '"' . $entry . '"';
            }
            else {
                $item .= 'UNDEF';
            }
            $ss .= CGI::li($item);
            $n++;
        }
    }
    return CGI::ol( { start => 0 }, $ss );
}

# PUBLIC but not exported
# bracket-matching split of a string into ( $one, $two ) where $one
# matches the section before the closing bracket and $two matches
# the section after. throws if the closing bracket isn't found.
sub mbrf {
    my ( $ob, $cb, $s ) = @_;

    my @a   = reverse( split( / */, $s ) );
    my $pre = "";
    my $d   = 0;

    while ( $#a >= 0 ) {
        my $c = pop(@a);
        if ( $c eq $cb ) {
            if ( !$d ) {
                return ( $pre, join( "", reverse(@a) ) );
            }
            else {
                $d--;
            }
        }
        elsif ( $c eq $ob ) {
            $d++;
        }
        $pre .= $c;
    }
    die "ERROR: mismatched $ob$cb at $s";
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
