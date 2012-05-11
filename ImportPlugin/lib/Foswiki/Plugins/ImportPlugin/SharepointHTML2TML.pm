# See bottom of file for license and copyright information

=pod

---+ package Foswiki::Plugins::ImportPlugin::SharepointHTML2TML;

Convertor for translating HTML into TML (Topic Meta Language)

The conversion is done by parsing the HTML and generating a parse
tree, and then converting that parse tree into TML.

The class is a subclass of HTML::Parser, run in XML mode, so it
should be tolerant to many syntax errors, and will also handle
XHTML syntax.

The translator tries hard to make good use of newlines in the
HTML, in order to maintain text level formating that isn't
reflected in the HTML. So the parser retains newlines and
spaces, rather than throwing them away, and uses various
heuristics to determine which to keep when generating
the final TML.

=cut

package Foswiki::Plugins::ImportPlugin::SharepointHTML2TML;

use Foswiki::Plugins::WysiwygPlugin::HTML2TML;
our @ISA = qw( Foswiki::Plugins::WysiwygPlugin::HTML2TML );

my %discardTag  = map { $_ => 1 } qw {font strong};
my %discardAttr = map { $_ => 1 } qw {span p div};

sub _openTag {
    my ( $this, $tag, $attrs ) = @_;

    $tag = lc($tag);

    if ( $discardTag{$tag} ) {
        print STDERR "discard $tag\n";
        return;
    }
    if ( $discardAttr{$tag} ) {
        print STDERR "discard attr $tag\n";
        $attrs = '';
    }
    if (   $closeOnRepeat{$tag}
        && $this->{stackTop}
        && $this->{stackTop}->{tag} eq $tag )
    {

        print STDERR "Close on repeat $tag\n";
        $this->_apply($tag);
    }

    push( @{ $this->{stack} }, $this->{stackTop} ) if $this->{stackTop};
    $this->{stackTop} =
      new Foswiki::Plugins::WysiwygPlugin::HTML2TML::Node( $this->{opts}, $tag,
        $attrs );

    if ( $autoClose{$tag} ) {

        print STDERR "Autoclose $tag\n";
        $this->_apply($tag);
    }
}

sub _closeTag {
    my ( $this, $tag ) = @_;

    $tag = lc($tag);

    if ( $discardTag{$tag} ) {
        print STDERR "discard $tag\n";
        return;
    }

    while ($this->{stackTop}
        && $this->{stackTop}->{tag} ne $tag
        && $autoClose{ $this->{stackTop}->{tag} } )
    {

        print STDERR "Close mismatched $this->{stackTop}->{tag}\n";
        $this->_apply( $this->{stackTop}->{tag} );
    }
    if (   $this->{stackTop}
        && $this->{stackTop}->{tag} eq $tag )
    {

        print STDERR "Closing $tag\n";
        $this->_apply($tag);
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2011 SvenDowideit@fosiki.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
