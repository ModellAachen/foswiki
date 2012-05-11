# See bottom of file for notices

package Foswiki::Plugins::SafeWikiPlugin::Parser;
use strict;
use Assert;
use HTML::Parser ();
our @ISA = ('HTML::Parser');

use Foswiki::Plugins::SafeWikiPlugin::Node        ();
use Foswiki::Plugins::SafeWikiPlugin::Leaf        ();
use Foswiki::Plugins::SafeWikiPlugin::Declaration ();

use constant TRACE_OPEN_CLOSE => 0;

# Support autoclose of the tags that are most typically incorrectly
# nested. Autoclose triggers when a second tag of the same type is
# seen without the first tag being closed.
my %openautoclose = map { ( $_, 1 ) } qw( li td th tr);
# Support silent autoclose of tags that are open when another close
# tag is seen that doesn't match
my %closeautoclose = map { ( $_, 1 ) } qw( img input );

sub new {
    my ($class) = @_;

    my $this = $class->SUPER::new(
        start_h       => [ \&_openTag,     'self,tagname,attr' ],
        end_h         => [ \&_closeTag,    'self,tagname' ],
        declaration_h => [ \&_declaration, 'self,text' ],
        default_h     => [ \&_text,        'self,text' ],
        comment_h     => [ \&_comment,     'self,text' ]
    );
    $this->attr_encoded(1);
    $this->empty_element_tags(1);
    if ( $Foswiki::cfg{Plugins}{SafeWikiPlugin}{CheckPurity} ) {
        $this->strict_end(1);
        $this->strict_names(1);
    }
    return $this;
}

sub parseHTML {
    my $this = $_[0];
    $this->_resetStack();
    $this->utf8_mode() if $Foswiki::cfg{Site}{CharSet} =~ /^utf-8$/i;

    # Text still contains <nop> - ignore it
    $this->ignore_tags('nop');
    $this->parse( $_[1] );
    $this->eof();
    $this->_apply(undef);
    return $this->{stackTop};
}

sub stringify {
    my $this = shift;
    my $s;

    if ( $this->{stackTop} ) {
        $s = "0: " . $this->{stackTop}->stringify();
        my $n = 1;
        foreach my $entry ( reverse @{ $this->{stack} } ) {
            $s .= "\n" . ( $n++ ) . ': ' . $entry->stringify();
        }
    }
    else {
        $s = 'empty stack';
    }
    return $s;
}

sub _resetStack {
    my $this = shift;

    $this->{stackTop} = undef;
    $this->{stack}    = [];
}

sub _openTag {
    my ( $this, $tag, $attrs ) = @_;
    if (   $openautoclose{$tag}
        && $this->{stackTop}
        && defined $this->{stackTop}->{tag}
        && $this->{stackTop}->{tag} eq $tag )
    {
        $this->_apply($tag);
    }
    print STDERR ( ' ' x scalar( @{ $this->{stack} } ) ) 
      . "open: "
      . ( $tag || 'unknown' ) . "\n"
      if TRACE_OPEN_CLOSE;
    push( @{ $this->{stack} }, $this->{stackTop} ) if $this->{stackTop};
    $this->{stackTop} =
      new Foswiki::Plugins::SafeWikiPlugin::Node( $tag, $attrs );
}

sub _closeTag {
    my ( $this, $tag ) = @_;

    print STDERR ( ' ' x ( scalar @{ $this->{stack} } - 1) )
      . "close: "
      . ( $tag || 'unknown' ) . "\n"
      if TRACE_OPEN_CLOSE;
    while ( $this->{stackTop} && $this->{stackTop}->{tag} ne $tag
	&& $closeautoclose{$this->{stackTop}->{tag}} ) {
        $this->_apply($this->{stackTop}->{tag});
    }
    if ( $this->{stackTop} && $this->{stackTop}->{tag} eq $tag ) {
        $this->_apply($tag);
    }
    elsif ( $Foswiki::cfg{Plugins}{SafeWikiPlugin}{CheckPurity} ) {
        die "SafeWikiPlugin: HTML syntax error: Unclosed <$this->{stackTop}->{tag} at </$tag\n"
          . $this->stringify();
    }
    else {
        print STDERR "ignoring unmatched close tag: $tag\n";
    }
}

sub _declaration {
    my ( $this, $text ) = @_;
    my $l = new Foswiki::Plugins::SafeWikiPlugin::Declaration($text);
    if ( defined $this->{stackTop} ) {
        $l->addChild( $this->{stackTop} );
    }
    $this->{stackTop} = $l;
}

sub _text {
    my ( $this, $text ) = @_;
    return unless length($text);
    my $l = new Foswiki::Plugins::SafeWikiPlugin::Leaf($text);
    if ( defined $this->{stackTop} ) {
        die "Unexpected leaf: " . $this->stringify()
          if $this->{stackTop}->isLeaf();
        $this->{stackTop}->addChild($l);
    }
    else {
        $this->{stackTop} = $l;
    }
}

sub _comment {
    my ( $this, $text ) = @_;
    if ($text =~ /(<!--\[if [^]]*\]>)|<!\[endif\]-->/) {
	die $text;
    }
}

sub _ignore {
}

sub _apply {
    my ( $this, $tag ) = @_;

    while ( $this->{stack} && scalar( @{ $this->{stack} } ) ) {
        my $top = $this->{stackTop};
        $this->{stackTop} = pop( @{ $this->{stack} } );
        die 'Stack underflow: ' . $this->stringify()
          unless $this->{stackTop};
        die 'Stack top is leaf: ' . $this->stringify()
          if $this->{stackTop}->isLeaf();
        $this->{stackTop}->addChild($top);
        last if ( $tag && $top->{tag} eq $tag );
    }
}

1;
__DATA__

Copyright (C) 2007-2009 C-Dot Consultants http://c-dot.co.uk
All rights reserved
Author: Crawford Currie

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html

This notice must be retained in all copies or derivatives of this
code.
