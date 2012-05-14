# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 - 2009 Andrew Jones, andrewjones86@googlemail.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.

package Foswiki::Plugins::SkillsPlugin::UserSkill;
use strict;

use Foswiki::Plugins::SkillsPlugin::SkillNode ();
our @ISA = ('Foswiki::Plugins::SkillsPlugin::SkillNode');

# Object to represent the skill as stored in users meta data
sub new {

    my ( $class, $name, $rating ) = @_;

    my $self = $class->SUPER::new($name);

    $self->{rating} = $rating;
    return $self;
}

sub serializable {
    my ( $this, $field ) = @_;
    return 1 if $field eq 'rating';
    return $this->SUPER::serializable($field);
}

# Debug
sub toMeta {
    my $this = shift;
    my $out;

    if ( $this->hasChildren() ) {
        $out = '';
        foreach my $kid ( @{ $this->{childNodes} } ) {
            $out .= $kid->toMeta();
        }
    }
    else {
        $out = "%META:USERSKILL{name=\"$this->{name}\"";
        $out .= ' rating="'
          . ( defined $this->{rating} ? $this->{rating} : '' ) . '"';
        $out .= ' path="' . $this->{parent}->getPath() . '"';
        $out .= " comment=\"$this->{text}\"" if $this->{text};
        $out .= "}%\n";
    }
    return $out;
}

# Add leaf skill nodes to Foswiki::Meta
sub saveToMeta {
    my ( $this, $meta ) = @_;
    my $out;

    if ( $this->hasChildren() ) {
        $out = '';
        foreach my $kid ( @{ $this->{childNodes} } ) {
            $out .= $kid->saveToMeta($meta);
        }
    }
    elsif ( defined $this->{rating} && $this->{name} ) {
        my @path = $this->getPathArray();
        pop(@path);    # get rid of the skill off the path
        $meta->putKeyed(
            'SKILLS',
            {
                name     => $this->{name},
                category => join( '/', @path ),
                rating   => $this->{rating},
                comment  => $this->{text}
            }
        );
    }
}

sub stringify {
    my $this = shift;
    if ( !$this->hasChildren() ) {
        return $this->toMeta();
    }
    else {
        return $this->SUPER::stringify();
    }
}

1;
