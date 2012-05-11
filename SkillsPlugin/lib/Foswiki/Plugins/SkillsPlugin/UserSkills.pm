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

package Foswiki::Plugins::SkillsPlugin::UserSkills;

use strict;

require Foswiki::Plugins::SkillsPlugin::UserSkill;

my %_userSkills;    # contains an array of UserSkill objects keyed by user

# Object that handles interaction with the user data (currently stored in the meta or the users topic)
# $skillset is an optional Skills object that lets us filter on those skills
sub new {
    my ( $class, $skillset ) = @_;

    #my ($class, $name, $cat, $rating, $comment) = @_;

    my $self = bless( { skillset => $skillset }, $class );

    return $self;
}

# loads the skills for a particular user
# gets it from the meta of the topic and stores in global hash
sub _loadUserSkills {
    my ( $self, $user ) = @_;

    my $mainWeb = Foswiki::Func::getMainWebname();
    my ( $meta, undef ) = Foswiki::Func::readTopic( $mainWeb, $user );
    my @skillsMeta = $meta->find('SKILLS');
    my $userSkills = new Foswiki::Plugins::SkillsPlugin::UserSkill($user);
    foreach my $skillMeta (@skillsMeta) {

        # Skip skills not in the skill set, if we have been given one
        next
          if ( $self->{skillset}
            && !$self->{skillset}
            ->isKnownSkill( $skillMeta->{category}, $skillMeta->{name} ) );
        my $skill =
          new Foswiki::Plugins::SkillsPlugin::UserSkill( $skillMeta->{name} );
        $skill->{rating} = $skillMeta->{rating}  || -1;
        $skill->{text}   = $skillMeta->{comment} || '';

        my @path = split( '/', $skillMeta->{category} );
        $userSkills->addByPath( $skill, @path );
    }

    $_userSkills{$user} = $userSkills;
}

sub getUser {
    my ( $this, $user ) = @_;
    if ( !$_userSkills{$user} ) {
        $this->_loadUserSkills($user);
    }
    return $_userSkills{$user};
}

# saves the skills for a particular user
sub save {
    my ( $self, $user ) = @_;

    my $mainWeb = Foswiki::Func::getMainWebname();

    my ( $meta, $text ) = Foswiki::Func::readTopic( $mainWeb, $user->{name} );

    $meta->remove('SKILLS');
    $user->saveToMeta($meta);

    Foswiki::Func::saveTopic( $meta->web(), $meta->topic(), $meta, $text,
        { dontlog => 1, comment => 'SkillsPlugin', minor => 1 } );
}

1;
