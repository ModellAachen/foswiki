#
# Copyright (C) 2005 Thomas Hartkens <thomas@hartkens.de>
# Copyright (C) 2005 Thomas Weigert <thomas.weigert@motorola.com>
# Copyright (C) 2008 Crawford Currie http://c-dot.co.uk
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

#
# This object represents a workflow definition. It stores the preferences
# defined in the workflow topic, together with the state and transition
# tables defined therein.
#
package Foswiki::Plugins::WorkflowPlugin::Workflow;

use strict;

use Foswiki::Func    ();
use Foswiki::Plugins ();

sub new {
    my ( $class, $web, $topic ) = @_;

    if ( defined &Foswiki::Sandbox::untaint ) {
        $web = Foswiki::Sandbox::untaint( $web,
            \&Foswiki::Sandbox::validateWebName );
        $topic = Foswiki::Sandbox::untaint( $topic,
            \&Foswiki::Sandbox::validateTopicName );
    }

    return undef unless ( $web && $topic );

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    unless (
        Foswiki::Func::checkAccessPermission(
            'VIEW', $Foswiki::Plugins::SESSION->{user},
            $text, $topic, $web, $meta
        )
      )
    {
        return undef;
    }
    my $this = bless(
        {
            name        => "$web.$topic",
            preferences => {},
            states      => {},
            transitions => []
        },
        $class
    );
    my $inTable;
    my @fields;

    # Yet another table parser
    # State table:
    # | *State*       | *Allow Edit* | *Message* |
    # Transition table:
    # | *State* | *Action* | *Next state* | *Allowed* |
    foreach my $line ( split( /\n/, $text ) ) {
        if (
            $line =~ s/^\s*\|([\s*]*State[\s*]*\|
                           [\s*]*Action[\s*]*\|.*)\|$/$1/ix
          )
        {

            # Transition table header
            @fields = map { _cleanField($_) } split( /\s*\|\s*/, lc($line) );

            $inTable = 'TRANSITION';
        }
        elsif (
            $line =~ s/^\s*\|([\s*]*State[\s*]*\|
                              [\s*]*Allow\s*Edit[\s*]*\|.*)\|$/$1/ix
          )
        {

            # State table header
            @fields = map { _cleanField($_) } split( /\s*\|\s*/, lc($line) );

            $inTable = 'STATE';
        }
        elsif ( $line =~ /^(?:\t|   )+\*\sSet\s(\w+)\s=\s*(.*)$/ ) {

            # store preferences
            $this->{preferences}->{$1} = $2;
        }
        elsif ( defined($inTable) && $line =~ s/^\s*\|\s*(.*?)\s*\|$/$1/ ) {

            my %data;
            my $i = 0;
            foreach my $col ( split( /\s*\|\s*/, $line ) ) {
                $data{ $fields[ $i++ ] } = $col;
            }

            if ( $inTable eq 'TRANSITION' ) {
                push( @{ $this->{transitions} }, \%data );
            }
            elsif ( $inTable eq 'STATE' ) {

                # read row in STATE table
                $this->{defaultState} ||= $data{state};
                $this->{states}->{ $data{state} } = \%data;
            }
        }
        else {
            undef $inTable;
        }
    }
    die "Invalid state table in $web.$topic" unless $this->{defaultState};
    return $this;
}

# Get the possible actions associated with the given state
sub getActions {
    my ( $this, $topic ) = @_;
    my @actions      = ();
    my $currentState = $topic->getState();
    foreach my $t ( @{ $this->{transitions} } ) {
        my $allowed   = $topic->expandMacros( $t->{allowed} );
        my $nextState = $topic->expandMacros( $t->{nextstate} );
        if (   $t->{state} eq $currentState
            && _isAllowed($allowed)
            && $nextState )
        {
            push( @actions, $t->{action} );
        }
    }
    return @actions;
}

# Get the next state defined for the given current state and action
# (the first 2 columns of the transition table). The returned state
# will be undef if the transition doesn't exist, or is not allowed.
sub getNextState {
    my ( $this, $topic, $action ) = @_;
    my $currentState = $topic->getState();
    foreach my $t ( @{ $this->{transitions} } ) {
        my $allowed   = $topic->expandMacros( $t->{allowed} );
        my $nextState = $topic->expandMacros( $t->{nextstate} );
        if (   $t->{state} eq $currentState
            && $t->{action} eq $action
            && _isAllowed($allowed)
            && $nextState )
        {
            return $nextState;
        }
    }
    return undef;
}

# Get the form defined for the given current state and action
# (the first 2 columns of the transition table). The returned form
# will be undef if the transition doesn't exist, or is not allowed.
sub getNextForm {
    my ( $this, $topic, $action ) = @_;
    my $currentState = $topic->getState();
    foreach my $t ( @{ $this->{transitions} } ) {
        my $allowed = $topic->expandMacros( $t->{allowed} );
        if (   $t->{state} eq $currentState
            && $t->{action} eq $action
            && _isAllowed($allowed) )
        {
            return $t->{form};
        }
    }
    return undef;
}

# Get the notify column defined for the given current state and action
# (the first 2 columns of the transition table). The returned list
# will be undef if the transition doesn't exist, or is not allowed.
sub getNotifyList {
    my ( $this, $topic, $action ) = @_;
    my $currentState = $topic->getState();
    foreach my $t ( @{ $this->{transitions} } ) {
        my $allowed = $topic->expandMacros( $t->{allowed} );
        if (   $t->{state} eq $currentState
            && $t->{action} eq $action
            && _isAllowed($allowed) )
        {
            return $t->{notify};
        }
    }
    return undef;
}

# Get the default state for this workflow
sub getDefaultState {
    my $this = shift;
    return $this->{defaultState};
}

# Get the message associated with the given state
sub getMessage {
    my ( $this, $state ) = @_;

    return '' unless $this->{states}->{$state};
    $this->{states}->{$state}->{message};
}

# Determine if the current user is allowed to edit a topic that is in
# the given state.
sub allowEdit {
    my ( $this, $topic ) = @_;

    my $state = $topic->getState();
    return 0 unless $this->{states}->{$state};
    my $allowed =
      $topic->expandMacros( $this->{states}->{$state}->{allowedit} );
    return _isAllowed($allowed);
}

# finds out if the current user is allowed to do something.
# They are allowed if their wikiname is in the
# (comma,space)-separated list $allow, or they are a member
# of a group in the list.
sub _isAllowed {
    my ($allow) = @_;

    return 1 unless ($allow);

    # Always allow members of the admin group to edit
    if ( defined &Foswiki::Func::isAnAdmin ) {

        # Latest interface, post user objects
        return 1 if ( Foswiki::Func::isAnAdmin() );
    }
    elsif ( ref( $Foswiki::Plugins::SESSION->{user} )
        && $Foswiki::Plugins::SESSION->{user}->can("isAdmin") )
    {

        # User object
        return 1 if ( $Foswiki::Plugins::SESSION->{user}->isAdmin() );
    }

    return 0 if ( defined($allow) && $allow =~ /^\s*nobody\s*$/ );

    if ( ref( $Foswiki::Plugins::SESSION->{user} )
        && $Foswiki::Plugins::SESSION->{user}->can("isInList") )
    {
        return $Foswiki::Plugins::SESSION->{user}->isInList($allow);
    }
    elsif ( defined &Foswiki::Func::isGroup ) {
        my $thisUser = Foswiki::Func::getWikiName();
        foreach my $allowed ( split( /\s*,\s*/, $allow ) ) {
            ( my $waste, $allowed ) =
              Foswiki::Func::normalizeWebTopicName( undef, $allowed );
            if ( Foswiki::Func::isGroup($allowed) ) {
                return 1 if Foswiki::Func::isGroupMember( $allowed, $thisUser );
            }
            else {
                $allowed = Foswiki::Func::getWikiUserName($allowed);
                $allowed =~ s/^.*\.//;    # strip web
                return 1 if $thisUser eq $allowed;
            }
        }
    }

    return 0;
}

sub _cleanField {
    my ($text) = @_;
    $text ||= '';
    $text =~ s/[^\w.]//gi;
    return $text;
}

sub stringify {
    my $this = shift;

    my $t;
    my $s = "---+ Preferences\n";
    foreach $t ( keys %{ $this->{preferences} } ) {
        $s .= "| $t | $this->{preferences}->{$t} |\n";
    }
    $s .= "\n---+ States\n| *State*       | *Allow Edit* | *Message* |\n";
    foreach $t ( values %{ $this->{states} } ) {
        $s .= "| $t->{state} | $t->{allowedit} | $t->{message} |\n";
    }

    $s .=
      "\n---+ Transitions\n| *State* | *Action* | *Next State* | *Allowed* |\n";
    foreach $t ( @{ $this->{transitions} } ) {
        $s .=
          "| $t->{state} | $t->{action} | $t->{nextstate} |$t->{allowed} |\n";
    }
    return $s;
}

1;
