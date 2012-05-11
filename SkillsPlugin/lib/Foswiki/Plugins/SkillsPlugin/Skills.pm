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

package Foswiki::Plugins::SkillsPlugin::Skills;
use strict;
use Foswiki::Plugins::SkillsPlugin::SkillNode ();
our @ISA = ('Foswiki::Plugins::SkillsPlugin::SkillNode');

use strict;

# Object that handles interaction with the skills data
sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    $this->_load();
    return $this;
}

# Children are of a different type
sub newChild {
    my $this = shift;
    return new Foswiki::Plugins::SkillsPlugin::SkillNode(@_);
}

# Test if the skill is known to this skills DB
sub isKnownSkill {
    my ( $this, $category, $skill ) = @_;
    my @path = split( '/', $category );
    push( @path, $skill );
    my $node = $this;
  FRONT:
    while ( my $front = shift(@path) ) {
        foreach my $subnode ( @{ $node->{childNodes} } ) {
            if ( $subnode->{name} eq $front ) {
                $node = $subnode;
                next FRONT;
            }
        }
        return 0;
    }
    return 1;
}

# Deprecated: read skills from file in work area
sub _getSkillsFromWorking {
    my $this = shift;

    my $file = Foswiki::Func::getWorkArea('SkillsPlugin') . '/skills.txt';

    my $fh;
    unless ( open( $fh, '<', $file ) ) {

        # file could not be opened
        Foswiki::Func::writeDebug(
            'skills.txt can not be opened. Maybe it does not exist?');
        return 1;
    }

    local $/ = "\n";

    while ( my $line = <$fh> ) {

        next if $line =~ /^#/;    # skip any comments

        if ( $line =~ s/(.*):(.*?)\s*$//s ) {
            my $node = new Foswiki::Plugins::SkillsPlugin::SkillNode($1);
            $this->appendChild($node);

            foreach my $skill ( split( ',', $line ) ) {
                $node->appendChild(
                    new Foswiki::Plugins::SkillsPlugin::SkillNode($skill) );
            }
        }
    }

    close($fh);
}

# loads the categories and skills from the topic (or file)
sub _load {
    my $self = shift;

    return if $self->{nodes};

    my $topic = Foswiki::Func::getPreferencesValue('SKILLSPLUGIN_SKILLSTOPIC');

    if ( !$topic ) {
        $self->_getSkillsFromWorking();
    }
    else {

        ( my $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( undef, $topic );

        if ( !Foswiki::Func::topicExists( $web, $topic ) ) {
            print STDERR "Cannot find SKILLSPLUGIN_SKILLSTOPIC $web.$topic";
            _getSkillsFromWorking();
        }
        my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
        unless (
            Foswiki::Func::checkAccessPermission(
                'VIEW', Foswiki::Func::getWikiName(),
                $text, $topic, $web, $meta
            )
          )
        {
            die "Cannot view SKILLSPLUGIN_SKILLSTOPIC $web.$topic";
        }

        my $curLevel = $self;

        foreach my $line ( split( /\r?\n/, $text ) ) {

            # ---+ Category
            # Description
            # ---++ Subcategory
            # Description
            # ---+++ Skill
            # Description
            # -or-
            # ---+ Category
            # Description
            # ---++ Skill
            # Description
            if ( $line =~ /^---(\++)\s*(.*)$/ ) {
                my $level = length($1);
                my $name  = $2;

                # Pop up to the level above the new level
                while ( $curLevel->getDepth() >= $level ) {
                    $curLevel = $curLevel->{parent};
                }

                # Push down to the level above the new level (should
                # not happen)
                while ( $curLevel->getDepth() < $level - 1 ) {
                    my $subNode =
                      new Foswiki::Plugins::SkillsPlugin::SkillNode('Unknown');
                    $curLevel->appendChild($subNode);
                    $curLevel = $subNode;
                }
                my $subNode =
                  new Foswiki::Plugins::SkillsPlugin::SkillNode($name);
                $curLevel->appendChild($subNode);
                $curLevel = $subNode;
            }
            elsif ( $line =~ /^\s*(\S+.*)$/ ) {

                # Add text to the current cat
                if ( $curLevel->{text} ) {
                    $curLevel->{text} .= " $1";
                }
                else {
                    $curLevel->{text} = $1;
                }
            }
        }
    }
}

# sorted iterator of category objects
sub eachChild {
    my $self = shift;

    $self->_load();

    my @sorted = sort { $a->name cmp $b->name } @{ $self->{childNodes} };

    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@sorted );
}

# saves the skills to file
sub _saveSkillsToWorking {
    my $self = shift;

    my $out = <<JUNK;
# This file is generated. Do NOT edit unless you are sure what you're doing!
JUNK

    foreach my $cat ( @{ $self->{childNodes} } ) {
        $out .=
          $cat->name() . ':'
          . join( ',', map { $_->name() } @{ $cat->{childNodes} } ) . "\n";
    }

    my $workArea = Foswiki::Func::getWorkArea('SkillsPlugin');
    Foswiki::Func::saveFile( $workArea . '/skills.txt', $out );
}

sub save {
    my $self = shift;

    my $topic = Foswiki::Func::getPreferencesValue('SKILLSPLUGIN_SKILLSTOPIC');

    if ( !$topic ) {
        _saveSkillsToWorking();
    }
    else {
        ( my $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( undef, $topic );

        unless (
            Foswiki::Func::checkAccessPermission(
                'CHANGE', Foswiki::Func::getWikiName(),
                undef, $topic, $web
            )
          )
        {
            die "Cannot change SKILLSPLUGIN_SKILLSTOPIC $web.$topic";
        }

        my $text = $self->toString();

        # Add standard header if the topic is new
        if ( !Foswiki::Func::topicExists( $web, $topic ) ) {
            $text = <<HERE . $text;
This topic is maintained by the %SYSTEMWEB%.SkillsPlugin, and will be
rewritten by the plugin if the set of skills changes.

Each category is defined by a top-level heading, followed by any number of
skills in second-level headings. Both categories and skills can be followed
by a block of text that describes the category/skill.

HERE
        }

        Foswiki::Func::saveTopic( $web, $topic, undef, $text );
    }
    return 1;
}

1;
