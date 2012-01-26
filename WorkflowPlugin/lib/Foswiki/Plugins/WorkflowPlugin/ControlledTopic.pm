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
package Foswiki::Plugins::WorkflowPlugin::ControlledTopic;

use strict;

use Foswiki ();         # for regexes
use Foswiki::Func ();

# Constructor
sub new {
    my ( $class, $workflow, $web, $topic, $meta, $text ) = @_;
    my $this = bless(
        {
            workflow => $workflow,
            web      => $web,
            topic    => $topic,
            meta     => $meta,
            text     => $text,
            state    => $meta->get('WORKFLOW'),
            history  => {
                data => [
                    sort { $a->{name} <=> $b->{name} }
                      grep { defined $_->{name} && $_->{name} ne 'legacy' }
                      $meta->find('WORKFLOWHISTORY')
                ]
            },
        },
        $class
    );

    # Compatibility with versions before 1.12.2
    # Look at Foswikitask:Item8002 for details.
    foreach my $v ( $meta->find('WORKFLOWHISTORY') ) {
        next if defined $v->{name} && $v->{name} ne 'legacy';

        if ( !defined $v->{name} ) {
            $this->{meta}->remove('WORKFLOWHISTORY');

            $this->{meta}->putAll(
                'WORKFLOWHISTORY',
                @{ $this->{history}->{data} },
                (
                    $v->{value}
                    ? { name => 'legacy', value => $v->{value} }
                    : ()
                ),
            );
        }

        $this->{history}->{legacy} = $v->{value} if $v->{value};
        last;
    }

    return $this;
}

# Return true if debug is enabled in the workflow
sub debugging {
    my $this = shift;
    return $this->{workflow}->{preferences}->{WORKFLOWDEBUG};
}

# Get the current state of the workflow in this topic
# If called without parameters returns state name, otherwise
# returns the value associated with the parameter.
sub getState {
    my $this = shift;
    my $key  = shift;

    return defined $key
      ? $this->{state}->{$key}
      : ( $this->{state}->{name} || $this->{workflow}->getDefaultState() );
}

# Get the available actions from the current state
sub getActions {
    my $this = shift;
    return $this->isLatestRev() ? $this->{workflow}->getActions($this) : ();
}

# Set the current state in the topic
sub setState {
    my ( $this, $state, $version ) = @_;
    return unless $this->isLatestRev();
    $this->{state}->{name} = $state;
    $this->{state}->{"LASTVERSION_$state"} = $version;
    $this->{state}->{"LASTTIME_$state"} =
      Foswiki::Func::formatTime( time(), undef, 'servertime' );
    $this->{meta}->put( "WORKFLOW", $this->{state} );
}

# Get the appropriate message for the current state
sub getStateMessage {
    my $this = shift;
    return $this->{workflow}->getMessage( $this->getState() );
}

# Get the history string for the topic
sub getHistoryText {
    my $this = shift;

    return ''
      unless @{ $this->{history}->{data} } || $this->{history}->{legacy};

    my $histStr =
      defined $this->{history}->{legacy}
      ? $this->{history}->{legacy}
      : '';

    my $fmt = Foswiki::Func::getPreferencesValue("WORKFLOWHISTORYFORMAT")
      || '<br>$state -- $date';
    foreach my $hist ( @{ $this->{history}->{data} } ) {
        if ( $hist->{forkto} ) {
            $histStr .=
                "<br>Forked to "
              . join( ', ', map { "[[$_]]" } split /\s*,\s*/, $hist->{forkto} )
              . " by $hist->{author} at "
              . Foswiki::Func::formatTime( $hist->{date}, undef, 'servertime' );
        }
        elsif ( $hist->{forkfrom} ) {
            $histStr .=
              "<br>Forked from [[$hist->{forkfrom}]] by $hist->{author} at "
              . Foswiki::Func::formatTime( $hist->{date}, undef, 'servertime' );
        }
        else {
            my $tmpl = $fmt;
            $tmpl =~ s/\$wikiusername/$hist->{author}/go;
            $tmpl =~ s/\$state/$hist->{state}/go;
            $tmpl =~
s/\$date/Foswiki::Func::formatTime($hist->{date}, undef, 'servertime')/geo;
            $tmpl =~ s/\$rev/$hist->{name}/go;
            if ( defined &Foswiki::Func::decodeFormatTokens ) {

                # Compatibility note: also expands $percnt etc.
                $tmpl = Foswiki::Func::decodeFormatTokens($tmpl);
            }
            else {
                my $mixedAlpha = $Foswiki::regex{mixedAlpha};
                $tmpl =~ s/\$quot/\"/go;
                $tmpl =~ s/\$n/\n/go;
                $tmpl =~ s/\$n\(\)/\n/go;
                $tmpl =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;
            }
            $histStr .= $tmpl;
        }
    }

    return $histStr;
}

# Return true if a new state is available using this action
sub haveNextState {
    my ( $this, $action ) = @_;
    return $this->{workflow}->getNextState( $this, $action );
}

sub isLatestRev {
    my $this = shift;
    return !defined $this->{meta}->getLoadedRev()
      || $this->{meta}->getLatestRev() == $this->{meta}->getLoadedRev();
}

# Some day we may handle the can... functions indepedently. For now,
# they all check editability thus....
sub _isModifiable {
    my ($this) = @_;
    my $meta = $this->{meta};

    return $this->{isEditable} if defined $this->{isEditable};

    # See if the workflow allows an edit
    # is the latest rev (or no rev) loaded?
    $this->{isEditable} = $this->isLatestRev();
    #print STDERR "Modify denied by isLatestRev\n" unless $this->{isEditable};

    # Does the workflow permit editing?
    if ($this->{isEditable}) {
	$this->{isEditable} = $this->{workflow}->allowEdit($this);
	#print STDERR "Modify denied by allowEdit\n" unless $this->{isEditable};
    }
    # Does Foswiki permit editing?
    if ($this->{isEditable}) {
	# DO NOT PASS $this->{meta}, because of Item11461
	$this->{isEditable} = Foswiki::Func::checkAccessPermission(
	    'CHANGE',      $Foswiki::Plugins::SESSION->{user},
	    $this->{text}, $this->{topic},
	    $this->{web} ) if $this->{isEditable};
	#print STDERR "Modify denied by checkAccessPermission\n" unless $this->{isEditable};
    }
    $this->{isEditable} ||= 0; # ensure defined

    return $this->{isEditable};
}

# Return tue if this topic is editable
sub canEdit {
    my $this = shift;
    return $this->_isModifiable();
}

# Return tue if this topic is editable
sub canSave {
    my $this = shift;
    return $this->_isModifiable();
}

# Return true if this topic is attachable to
sub canAttach {
    my $this = shift;
    return $this->_isModifiable();
}

# Return tue if this topic is forkable
sub canFork {
    my $this = shift;
    return $this->_isModifiable();
}

# Expand miscellaneous preferences defined in the workflow and topic
sub expandWorkflowPreferences {
    my $this = shift;
    my $url  = shift;
    my $key;
    foreach $key ( keys %{ $this->{workflow}->{preferences} } ) {
        if ( $key =~ /^WORKFLOW/ ) {
            $_[0] =~ s/%$key%/$this->{workflow}->{preferences}->{$key}/g;
        }
    }

    # show last version tags and last time tags
    while ( my ( $key, $val ) = each %{ $this->{state} } ) {
        $val ||= '';
        if ( $key =~ m/^LASTVERSION_/ ) {
            my $foo = CGI::a( { href => "$url?rev=$val" }, "revision $val" );
            $_[0] =~ s/%WORKFLOW$key%/$foo/g;

            # WORKFLOWLASTREV_
            $key  =~ s/VERSION/REV/;
            $_[0] =~ s/%WORKFLOW$key%/$val/g;
        }
        elsif ( $key =~ /^LASTTIME_/ ) {
            $_[0] =~ s/%WORKFLOW$key%/$val/g;
        }
    }

    # Clean down any states we have no info about
    $_[0] =~ s/%WORKFLOWLAST(TIME|VERSION)_\w+%//g unless $this->debugging();
}

# if the form employed in the state arrived after after applying $action
# is different to the form currently on the topic.
sub newForm {
    my ( $this, $action ) = @_;
    my $form = $this->{workflow}->getNextForm( $this, $action );
    my $oldForm = $this->{meta}->get('FORM');

    # If we want to have a form attached initially, we need to have
    # values in the topic, due to the form initialization
    # algorithm, or pass them here via URL parameters (take from
    # initialization topic)
    return ( $form && ( !$oldForm || $oldForm ne $form ) ) ? $form : undef;
}

# change the state of the topic. Does *not* save the updated topic, but
# does notify the change to listeners.
sub changeState {
    my ( $this, $action ) = @_;

    return unless $this->isLatestRev();

    my $state = $this->{workflow}->getNextState( $this, $action );
    my $form = $this->{workflow}->getNextForm( $this, $action );
    my $notify = $this->{workflow}->getNotifyList( $this, $action );

    my ( $revdate, $revuser, $version ) = $this->{meta}->getRevisionInfo();
    if ( ref($revdate) eq 'HASH' ) {
        my $info = $revdate;
        ( $revdate, $revuser, $version ) =
          ( $info->{date}, $info->{author}, $info->{version} );
    }

    $this->setState( $state, $version );

    push @{ $this->{history}->{data} },
      {
        name   => -1,
        state  => $this->getState(),
        author => Foswiki::Func::getWikiUserName(),
        date   => $revdate,
      };
    $this->{meta}->putAll(
        "WORKFLOWHISTORY",
        @{ $this->{history}->{data} },
        (
            defined $this->{history}->{legacy}
            ? { name => 'legacy', value => $this->{history}->{legacy} }
            : ()
        )
    );
    if ($form) {
        $this->{meta}->put( "FORM", { name => $form } );
    }    # else leave the existing form in place

    if ($notify) {

        # Expand vars in the notify list. This supports picking up the
        # value of the notifees from the topic itself.
        $notify = $this->expandMacros($notify);

        # Dig up the bodies
        my @persons = split( /\s*,\s*/, $notify );
        my @emails;
        my @templates;
        my $templatetext        = undef;
        my $currenttemplatetext = undef;
        my $web                 = Foswiki::Func::expandCommonVariables('%WEB%');

        foreach my $who (@persons) {
            if ( $who =~ /^$Foswiki::regex{emailAddrRegex}$/ ) {
                push( @emails, $who );
            }
            elsif ( $who =~ /^template\((.*)\)$/ ) {

                # Read template topic if provided one
                my @webtopic = Foswiki::Func::normalizeWebTopicName( $web, $1 );
                if ( Foswiki::Func::topicExists( $webtopic[0], $webtopic[1] ) )
                {
                    ( undef, $currenttemplatetext ) =
                      Foswiki::Func::readTopic( $webtopic[0], $webtopic[1] );
                    push( @templates, $currenttemplatetext );
                }
                else {
                    Foswiki::Func::writeWarning( __PACKAGE__
                          . " cannot find topic '"
                          . $webtopic[0] . "."
                          . $webtopic[1] . "'"
                          . " - this template will not be executed!" );
                }
            }
            else {
                $who =~ s/^.*\.//;    # web name?
                my @list = Foswiki::Func::wikinameToEmails($who);
                if ( scalar(@list) ) {
                    push( @emails, @list );
                }
                else {
                    Foswiki::Func::writeWarning( __PACKAGE__
                          . " cannot send mail to '$who'"
                          . " - cannot determine an email address" );
                }
            }
        }
        if ( scalar(@emails) ) {

            # Have a list of recipients
            my $defaulttemplate = undef;
            my $text            = undef;
            my $currentweb      = undef;
            my $currenttopic    = undef;

            # See if this workflow has a custom default email template defined
            $defaulttemplate =
              $this->{workflow}->{preferences}->{WORKFLOWDEFAULTEMAILTEMPLATE};
            if ( $defaulttemplate && ( $defaulttemplate ne '' ) ) {
                ( $currentweb, $currenttopic ) =
                  Foswiki::Func::normalizeWebTopicName( $web,
                    $defaulttemplate );
                if ( Foswiki::Func::topicExists( $currentweb, $currenttopic ) )
                {
                    ( undef, $text ) =
                      Foswiki::Func::readTopic( $currentweb, $currenttopic );
                }
                else {
                    Foswiki::Func::writeWarning( __PACKAGE__
                          . " cannot find topic '$currentweb.$currenttopic'"
                          . " - falling back to default email template" );
                }

            }

            # Otherwise, use the shipped default template
            if ( !$text || ( $text eq '' ) ) {
                $text = Foswiki::Func::loadTemplate('mailworkflowtransition');
            }

            my $tofield = join( ', ', @emails );

            Foswiki::Func::setPreferencesValue( 'EMAILTO', $tofield );
            Foswiki::Func::setPreferencesValue( 'TARGET_STATE',
                $this->getState() );
            $text = $this->expandMacros($text);
            my $errors = Foswiki::Func::sendEmail( $text, 5 );
            if ($errors) {
                Foswiki::Func::writeWarning(
                    'Failed to send transition mails: ' . $errors );
            }
        }

        if ( scalar(@templates) ) {
            foreach my $template (@templates) {
                Foswiki::Func::setPreferencesValue( 'TARGET_STATE',
                    $this->getState() );
                $template = $this->expandMacros($template);
                my $errors = Foswiki::Func::sendEmail( $template, 5 );
                if ($errors) {
                    Foswiki::Func::writeWarning(
                        'Failed to send transition mails: ' . $errors );
                }
            }
        }

    }    #end notify

    return undef;
}

# Save the topic to the store
sub save {
    my $this = shift;

    return unless $this->isLatestRev();

    Foswiki::Func::saveTopic( $this->{web}, $this->{topic}, $this->{meta},
        $this->{text}, { forcenewrevision => 1 } );
}

sub expandMacros {
    my ( $this, $text ) = @_;
    my $c = Foswiki::Func::getContext();

    # Workaround for Item1071
    my $memory = $c->{can_render_meta};
    $c->{can_render_meta} = $this->{meta};
    $text =
      Foswiki::Func::expandCommonVariables( $text, $this->{topic}, $this->{web},
        $this->{meta} );
    $c->{can_render_meta} = $memory;
    return $text;
}

1;
