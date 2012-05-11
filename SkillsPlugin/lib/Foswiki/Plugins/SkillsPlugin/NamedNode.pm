package Foswiki::Plugins::SkillsPlugin::NamedNode;

use strict;

sub new {
    my ( $class, $name, $parent ) = @_;
    my $this = bless(
        {
            name       => $name,
            parent     => undef,
            childNodes => [],
        },
        $class
    );
    return $this;
}

# By default children are the same type as the parent
sub newChild {
    my $this  = shift;
    my $class = ref($this);
    return $class->new(@_);
}

sub serializable {
    my ( $this, $field ) = @_;
    return $field eq 'name';
}

sub getDepth {
    my $node  = shift;
    my $depth = 0;
    while ( $node->{parent} ) {
        $depth++;
        $node = $node->{parent};
    }
    return $depth;
}

sub appendChild {
    my ( $this, $child ) = @_;

    $child->{parent} = $this;
    push( @{ $this->{childNodes} }, $child );
}

sub getChild {
    my ( $this, $name ) = @_;
    foreach my $child ( @{ $this->{childNodes} } ) {
        return $child if $child->{name} eq $name;
    }
    return undef;
}

sub remove {
    my $this   = shift;
    my $parent = $this->{parent};
    die "Cannot remove root" unless $parent;

    my $i = 0;
    foreach my $child ( @{ $parent->{childNodes} } ) {
        last if ( $child == $this );
        $i++;
    }
    die "Child node not in parent"
      if ( $i > scalar( @{ $parent->{childNodes} } ) );
    splice( @{ $parent->{childNodes} }, $i, 1 );
    undef $this->{parent};
}

sub finish {
    my $this = shift;
    undef $this->{parent};
    undef $this->{childNodes};
}

# Given a path, get the node. The path is passed as a list of names
# for each level in the tree.
#our $MON;
sub getByPath {
    my $this = shift;
    return $this unless scalar(@_);
    my $child = shift;

    #$MON="$child in [" if $MON;
    foreach my $kid ( @{ $this->{childNodes} } ) {

        #$MON .="$kid->{name}, " if $MON;
        return $kid->getByPath(@_) if ( $kid->{name} eq $child );
    }

    #$MON .= "]" if $MON;
    # Not found
    return undef;
}

# Get the path to this node as an array
sub getPathArray {
    my $this = shift;

    my $node = $this;
    my @path = ();
    while ( $node->{parent} ) {
        unshift( @path, $node->{name} );
        $node = $node->{parent};
    }
    return @path;
}

# Get the path to this node as a string
sub getPath {
    my $this = shift;
    return join( '/', $this->getPathArray() );
}

# Get a legal HTML ID, unique in this hierarchy
sub getID {
    my $this = shift;
    my $id   = $this->getPath();

    # Use : (legal in IDs) as an escape char
    $id =~ s#([^0-9a-zA-Z-_.])#':'.sprintf('%02x',ord($1))#ge;
    $id = "i$id" if $id =~ /^[^a-z]/i;
    return $id;
}

sub addByPath {
    my $this = shift;
    my $node = shift;

    if ( !scalar(@_) ) {
        $this->appendChild($node);
    }
    else {
        my $child = shift;
        foreach my $kid ( @{ $this->{childNodes} } ) {
            if ( $kid->{name} eq $child ) {
                return $kid->addByPath( $node, @_ );
            }
        }
        my $intermediate = $this->newChild($child);
        $this->appendChild($intermediate);
        $intermediate->addByPath( $node, @_ );
    }
}

# eliminate uplinks and useless fields, and merge two trees
sub _simplify {
    my ( $this, $pal ) = @_;
    my %shadow = ();
    foreach my $field ( keys %$this ) {
        next unless $this->serializable($field);
        $shadow{$field} = $this->{$field};
    }
    if ($pal) {
        foreach my $field ( keys %$pal ) {
            next unless $pal->serializable($field);
            $shadow{$field} = $pal->{$field};
        }
    }
    my @kids;
    foreach my $child ( @{ $this->{childNodes} } ) {
        my $playpal;
        if ($pal) {
            $playpal = $pal->getChild( $child->{name} );
        }
        push( @kids, $child->_simplify($playpal) );
    }
    $shadow{childNodes} = \@kids;
    return \%shadow;
}

# Generate JSON for the tree, optionally mergeing in 1:1 nodes
# from another tree
sub toJSON {
    my ( $this, $pal ) = @_;
    my $simple = $this->_simplify($pal);
    return JSON::to_json($simple);
}

sub visit {
    my $this = shift;
    my $pre  = shift;
    my $post = shift;

    # remaining params are passed to the visitor functions

    if ($pre) {
        &$pre( $this, @_ );
    }
    foreach my $kid ( @{ $this->{childNodes} } ) {
        $kid->visit( $pre, $post, @_ );
    }
    if ($post) {
        &$post( $this, @_ );
    }
}

sub hasChildren {
    my $this = shift;
    return scalar( @{ $this->{childNodes} } );
}

sub stringify {
    my $this = shift;
    my $out = ( $this->{name} || 'unnamed' ) . '(' . ref($this) . ')';
    if ( $this->hasChildren() ) {
        my @kids;
        foreach my $kid ( @{ $this->{childNodes} } ) {
            push( @kids, $kid->stringify() );
        }
        $out .= '[' . join( ',', @kids ) . ']';
    }
    return $out;
}

1;

