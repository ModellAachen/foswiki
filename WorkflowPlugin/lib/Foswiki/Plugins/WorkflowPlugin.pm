# See bottom of file for license and copyright information

# TODO
# 1. Create initial values based on form when attaching a form for
#    the first time.
# 2. Allow appearance of button to be given in preference.

# =========================
package Foswiki::Plugins::WorkflowPlugin;

use strict;

use Error ':try';
use Assert;

use Foswiki::Func                                     ();
use Foswiki::Plugins::WorkflowPlugin::Workflow        ();
use Foswiki::Plugins::WorkflowPlugin::ControlledTopic ();
use Foswiki::OopsException                            ();
use Foswiki::Sandbox                                  ();

our $VERSION = '$Rev$';
our $RELEASE = '1.12.7';
our $SHORTDESCRIPTION =
'Associate a "state" with a topic and then control the work flow that the topic progresses through as content is added.';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName        = 'WorkflowPlugin';
our %cache;
our $isStateChange;

sub initPlugin {
    my ( $topic, $web ) = @_;

    %cache = ();

    Foswiki::Func::registerRESTHandler(
        'changeState', \&_changeState,
        authenticate => 1,
        http_allow   => 'POST'
    );
    Foswiki::Func::registerRESTHandler(
        'fork', \&_restFork,
        authenticate => 1,
        http_allow   => 'POST'
    );

    Foswiki::Meta::registerMETA('WORKFLOW');
    Foswiki::Meta::registerMETA( 'WORKFLOWHISTORY', many => 1 );

    Foswiki::Func::registerTagHandler( 'WORKFLOWSTATE', \&_WORKFLOWSTATE );
    Foswiki::Func::registerTagHandler( 'WORKFLOWEDITTOPIC',
        \&_WORKFLOWEDITTOPIC );
    Foswiki::Func::registerTagHandler( 'WORKFLOWATTACHTOPIC',
        \&_WORKFLOWATTACHTOPIC );
    Foswiki::Func::registerTagHandler( 'WORKFLOWSTATEMESSAGE',
        \&_WORKFLOWSTATEMESSAGE );
    Foswiki::Func::registerTagHandler( 'WORKFLOWHISTORY', \&_WORKFLOWHISTORY );
    Foswiki::Func::registerTagHandler( 'WORKFLOWTRANSITION',
        \&_WORKFLOWTRANSITION );
    Foswiki::Func::registerTagHandler( 'WORKFLOWFORK', \&_WORKFLOWFORK );

    return 1;
}

# Tag handler
sub _initTOPIC {
    my ( $web, $topic, $rev, $meta, $text, $forceNew ) = @_;

    $rev ||= 99999;    # latest

    ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( $web, $topic );

    my $controlledTopic;

    unless ($forceNew) {
        $controlledTopic = $cache{"$web.$topic.$rev"};
        if ($controlledTopic) {
            return if $controlledTopic eq '_undef';
            return $controlledTopic;
        }
    }

    if ( defined &Foswiki::Func::isValidTopicName ) {

        # Allow non-wikiwords
        return undef unless Foswiki::Func::isValidTopicName( $topic, 1 );
    }
    else {

        # (tm)wiki doesn't have isValidTopicName
        # best we can do
        return undef unless Foswiki::Func::isValidWikiWord($topic);
    }

    Foswiki::Func::pushTopicContext( $web, $topic );
    my $workflowName = Foswiki::Func::getPreferencesValue('WORKFLOW');
    Foswiki::Func::popTopicContext( $web, $topic );

    if ($workflowName) {
        ( my $wfWeb, $workflowName ) =
          Foswiki::Func::normalizeWebTopicName( $web, $workflowName );

        if ( Foswiki::Func::topicExists( $wfWeb, $workflowName ) ) {
            my $workflow =
              new Foswiki::Plugins::WorkflowPlugin::Workflow( $wfWeb,
                $workflowName );

            if ($workflow) {
                ( $meta, $text ) =
                  Foswiki::Func::readTopic( $web, $topic, $rev )
                  unless defined $meta;
                $controlledTopic =
                  new Foswiki::Plugins::WorkflowPlugin::ControlledTopic(
                    $workflow, $web, $topic, $meta, $text );
            }
        }
    }

    $cache{"$web.$topic.$rev"} = $controlledTopic || '_undef';
    return $controlledTopic;
}

sub _getTopicName {
    my ( $attributes, $web, $topic ) = @_;

    return Foswiki::Func::normalizeWebTopicName( $attributes->{web} || $web,
        $attributes->{_DEFAULT} || $topic );
}

# Tag handler
sub _WORKFLOWEDITTOPIC {
    my ( $session, $attributes, $topic, $web ) = @_;

    ( $web, $topic ) = _getTopicName( $attributes, $web, $topic );
    my ($rev) =
      defined $attributes->{rev} ? ( $attributes->{rev} =~ /(\d+)/ ) : ();
    my $controlledTopic = _initTOPIC( $web, $topic, $rev );
    return '' unless $controlledTopic;

    # replace edit tag
    if ( $controlledTopic->canEdit() ) {
        return CGI::a(
            {
                href => Foswiki::Func::getScriptUrl(
                    $web, $topic, 'edit', t => time()
                ),
            },
            CGI::strong("Edit")
        );
    }
    else {
        return CGI::strike("Edit");
    }
}

# Tag handler
sub _WORKFLOWSTATEMESSAGE {
    my ( $session, $attributes, $topic, $web ) = @_;

    ( $web, $topic ) = _getTopicName( $attributes, $web, $topic );
    my ($rev) =
      defined $attributes->{rev} ? ( $attributes->{rev} =~ /(\d+)/ ) : ();
    my $controlledTopic = _initTOPIC( $web, $topic, $rev );
    return '' unless $controlledTopic;

    return $controlledTopic->getStateMessage();
}

# Tag handler
sub _WORKFLOWATTACHTOPIC {
    my ( $session, $attributes, $topic, $web ) = @_;

    ( $web, $topic ) = _getTopicName( $attributes, $web, $topic );
    my ($rev) =
      defined $attributes->{rev} ? ( $attributes->{rev} =~ /(\d+)/ ) : ();
    my $controlledTopic = _initTOPIC( $web, $topic, $rev );
    return '' unless $controlledTopic;

    # replace attach tag
    if ( $controlledTopic->canAttach() ) {
        return CGI::a(
            {
                href => Foswiki::Func::getScriptUrl(
                    $web, $topic, 'attach', t => time()
                )
            },
            CGI::strong("Attach")
        );
    }
    else {
        return CGI::strike("Attach");
    }
}

# Tag handler
sub _WORKFLOWHISTORY {
    my ( $session, $attributes, $topic, $web ) = @_;

    ( $web, $topic ) = _getTopicName( $attributes, $web, $topic );
    my ($rev) =
      defined $attributes->{rev} ? ( $attributes->{rev} =~ /(\d+)/ ) : ();
    my $controlledTopic = _initTOPIC( $web, $topic, $rev );
    return '' unless $controlledTopic;

    return $controlledTopic->getHistoryText();
}

# Tag handler
sub _WORKFLOWTRANSITION {
    my ( $session, $attributes, $topic, $web ) = @_;

    ( $web, $topic ) = _getTopicName( $attributes, $web, $topic );
    my ($rev) =
      defined $attributes->{rev} ? ( $attributes->{rev} =~ /(\d+)/ ) : ();
    my $controlledTopic = _initTOPIC( $web, $topic, $rev );
    return '' unless $controlledTopic;

    #
    # Build the button to change the current status
    #
    my @actions         = $controlledTopic->getActions();
    my $numberOfActions = scalar(@actions);
    my $cs              = $controlledTopic->getState();

    unless ($numberOfActions) {
        return
            '<span class="foswikiAlert">NO AVAILABLE ACTIONS in state ' 
          . $cs
          . '</span>'
          if $controlledTopic->debugging();
        return '';
    }

    my @fields = (
        "<input type='hidden' name='WORKFLOWSTATE' value='$cs' />",

        # Can't use CGI because a top parameter could defeat the value we need
        "<input type='hidden' name='topic' value='$web.$topic' />",

        # Use a time field to help defeat the cache
        "<input type='hidden' name='t' value='" . time() . "' />"
    );

    my $buttonClass =
      Foswiki::Func::getPreferencesValue('WORKFLOWTRANSITIONCSSCLASS')
      || 'foswikiChangeFormButton foswikiSubmit';

    if ( $numberOfActions == 1 ) {
        push( @fields,
                "<input type='hidden' name='WORKFLOWACTION' value='"
              . $actions[0]
              . "' />" );
        push(
            @fields,
            CGI::submit(
                -class => $buttonClass,
                -value => $actions[0]
            )
        );
    }
    else {
        push(
            @fields,
            CGI::popup_menu(
                -name   => 'WORKFLOWACTION',
                -values => \@actions
            )
        );
        push(
            @fields,
            CGI::submit(
                -class => $buttonClass,
                -value => 'Change status'
            )
        );
    }

    my $url = Foswiki::Func::getScriptUrl( $pluginName, 'changeState', 'rest' );
    my $form =
        CGI::start_form( -method => 'POST', -action => $url )
      . join( '', @fields )
      . CGI::end_form();

    $form =~ s/\r?\n//g;    # to avoid breaking TML
    return $form;
}

# Tag handler
sub _WORKFLOWSTATE {
    my ( $session, $attributes, $topic, $web ) = @_;

    ( $web, $topic ) = _getTopicName( $attributes, $web, $topic );
    my ($rev) =
      defined $attributes->{rev} ? ( $attributes->{rev} =~ /(\d+)/ ) : ();
    my $controlledTopic = _initTOPIC( $web, $topic, $rev );
    return '' unless $controlledTopic;

    return $controlledTopic->getState();
}

# Tag handler
sub _WORKFLOWFORK {
    my ( $session, $attributes, $topic, $web ) = @_;

    my ($rev) =
      defined $attributes->{rev} ? ( $attributes->{rev} =~ /(\d+)/ ) : ();
    my $controlledTopic = _initTOPIC( $web, $topic, $rev );
    return '' unless $controlledTopic;

    # Check we can fork
    return '' unless ( $controlledTopic->canFork() );

    my $newnames;
    if ( !defined $attributes->{newnames} ) {

        # Old interpretation, for compatibility
        $newnames = $attributes->{_DEFAULT};
        $topic = $attributes->{topic} || $topic;
    }
    else {
        ( $web, $topic ) = _getTopicName( $attributes, $web, $topic );
        $newnames = $attributes->{newnames};
    }
    return '' unless $newnames;
    my $lockdown = Foswiki::Func::isTrue( $attributes->{lockdown} );

    if ( !Foswiki::Func::topicExists( $web, $topic ) ) {
        return
"<span class='foswikiAlert'>WORKFLOWFORK: '$topic' does not exist</span>";
    }
    my $errors = '';
    foreach my $newname ( split( ',', $newnames ) ) {
        my ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( $web, $newname );
        if ( Foswiki::Func::topicExists( $w, $t ) ) {
            $errors .=
"<span class='foswikiAlert'>WORKFLOWFORK: $w.$t exists</span><br />";
        }
    }
    return $errors if $errors;

    my $label = $attributes->{label} || 'Fork';
    my $buttonClass =
      Foswiki::Func::getPreferencesValue('WORKFLOWTRANSITIONCSSCLASS')
      || 'foswikiChangeFormButton foswikiSubmit';
    my $url = Foswiki::Func::getScriptUrl( 'WorkflowPlugin', 'fork', 'rest' );
    return <<HTML;
<form name='forkWorkflow' action='$url' method="POST">
<input type='hidden' name='topic' value='$web.$topic' />
<input type='hidden' name='newnames' value='$newnames' />
<input type='hidden' name='lockdown' value='$lockdown' />
<input type='hidden' name='endPoint' value='$web.$topic' />
<input type='submit' class='$buttonClass' value='$label' />
</form>
HTML
}

# Handle actions. REST handler, on changeState action.
sub _changeState {
    my ($session) = @_;

    my $query = Foswiki::Func::getCgiQuery();
    return unless $query;

    my $web   = $session->{webName};
    my $topic = $session->{topicName};
    die unless $web && $topic;

    my $url;
    my $controlledTopic = _initTOPIC( $web, $topic );

    unless ($controlledTopic) {
        $url = Foswiki::Func::getScriptUrl(
            $web, $topic, 'oops',
            template => "oopssaveerr",
            param1   => "Could not initialise workflow for "
              . ( $web   || '' ) . '.'
              . ( $topic || '' )
        );
        Foswiki::Func::redirectCgiQuery( undef, $url );
        return undef;
    }

    my $action = $query->param('WORKFLOWACTION');
    my $state  = $query->param('WORKFLOWSTATE');
    die "BAD STATE $action $state!=", $controlledTopic->getState()
      unless $action
          && $state
          && $state eq $controlledTopic->getState()
          && $controlledTopic->haveNextState($action);

    my $newForm = $controlledTopic->newForm($action);

    # Check that no-one else has a lease on the topic
    my $breaklock = $query->param('breaklock');
    unless ( Foswiki::Func::isTrue($breaklock) ) {
        my ( $url, $loginName, $t ) =
          Foswiki::Func::checkTopicEditLock( $web, $topic );
        if ($t) {
            my $currUser = Foswiki::Func::getCanonicalUserID();
            my $locker   = Foswiki::Func::getCanonicalUserID($loginName);
            if ( $locker ne $currUser ) {
                $t = Foswiki::Time::formatDelta( $t,
                    $Foswiki::Plugins::SESSION->i18n );
                $url = Foswiki::Func::getScriptUrl(
                    $web, $topic, 'oops',
                    template => 'oopswfplease',
                    param1   => Foswiki::Func::getWikiName($locker),
                    param2   => $t,
                    param3   => $state,
                    param4   => $action,
                );
                Foswiki::Func::redirectCgiQuery( undef, $url );
                return undef;
            }
        }
    }

    try {
        try {
            if ($newForm) {

                # If there is a form with the new state, and it's not
                # the same form as previously, we need to kick into edit
                # mode to support form field changes. In this case the
                # transition is delayed until after the edit is saved
                # (the transition is executed by the beforeSaveHandler)
                $url = Foswiki::Func::getScriptUrl(
                    $web, $topic, 'edit',
                    breaklock    => $breaklock,
                    t            => time(),
                    formtemplate => $newForm,

                    # pass info about pending state change
                    template              => 'workflowedit',
                    WORKFLOWPENDINGACTION => $action,
                    WORKFLOWCURRENTSTATE  => $state,
                    WORKFLOWPENDINGSTATE =>
                      $controlledTopic->haveNextState($action),
                    WORKFLOWWORKFLOW => $controlledTopic->{workflow}->{name},
                );
            }
            else {
                $controlledTopic->changeState($action);

                # Flag that this is a state change to the beforeSaveHandler
                local $isStateChange = 1;
                $controlledTopic->save();
                $url = Foswiki::Func::getScriptUrl( $web, $topic, 'view' );
            }

            Foswiki::Func::redirectCgiQuery( undef, $url );
        }
        catch Error::Simple with {
            my $error = shift;
            throw Foswiki::OopsException(
                'oopssaveerr',
                web    => $web,
                topic  => $topic,
                params => [ $error || '?' ]
            );
        };
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        if ( $e->can('generate') ) {
            $e->generate($session);
        }
        else {

            # Deprecated, TWiki compatibility only
            $e->redirect($session);
        }

    };
    return undef;
}

sub _expandParametedTags {
    my ( $topic, $web, $tag, $state, $param ) = @_;

    my $attr = new Foswiki::Attrs($param);
    my ( $theTopic, $theWeb );

    if ( defined $attr->{_DEFAULT} ) {
        $theTopic = $attr->{_DEFAULT};
        $theWeb = defined $attr->{web} ? $attr->{web} : $web;
    }
    else {
        $theTopic = $topic;
        $theWeb   = $web;
    }

    my ($rev) = defined $attr->{rev} ? ( $attr->{rev} =~ /(\d+)/ ) : ();
    my $controlledTopic = _initTOPIC( $theWeb, $theTopic, $rev );
    if ($controlledTopic) {
        if ( $tag eq 'REV' || $tag eq 'TIME' ) {
            $tag = 'VERSION' if $tag eq 'REV';
            return $controlledTopic->getState("LAST${tag}_$state") || '';
        }
        else {
            my $val = $controlledTopic->getState("LAST${tag}_$state");
            my $url = Foswiki::Func::getScriptUrl( $theWeb, $theTopic, 'view' );
            return $val
              ? CGI::a( { href => "$url?rev=$val" }, "revision $val" )
              : '';
        }
    }

    return '';
}

# Mop up other WORKFLOW tags without individual handlers
sub commonTagsHandler {
    my ( $text, $topic, $web ) = @_;

    # Expand %WORKFLOWLAST*{"topic" web="web" ...}%
    $_[0] =~
s/%WORKFLOWLAST(REV|TIME|VERSION)_(\w+){(.*?)}%/_expandParametedTags($topic, $web, $1, $2, $3)/ge;

    my $controlledTopic = _initTOPIC( $web, $topic );
    if ($controlledTopic) {

        # show all tags defined by the preferences
        my $url = Foswiki::Func::getScriptUrl( $web, $topic, 'view' );
        $controlledTopic->expandWorkflowPreferences( $url, $_[0] );

        return unless ( $controlledTopic->debugging() );
    }

    # Clean up unexpanded variables
    $_[0] =~ s/%WORKFLOW[A-Z_]*%//g;
}

sub _restFork {
    my ($session) = @_;

    # Update the history in the template topic and the new topic
    my $query     = Foswiki::Func::getCgiQuery();
    my $forkTopic = $query->param('topic');
    my @newnames  = split( /,/, $query->param('newnames') );
    my $lockdown  = $query->param('lockdown');

    ( my $forkWeb, $forkTopic ) =
      Foswiki::Func::normalizeWebTopicName( undef, $forkTopic );

    if ( Foswiki::Func::topicExists( $forkWeb, $forkTopic ) ) {

        # Validated
        $forkWeb   = Foswiki::Sandbox::untaintUnchecked($forkWeb);
        $forkTopic = Foswiki::Sandbox::untaintUnchecked($forkTopic);
    }

    my ( $ttmeta, $tttext ) = Foswiki::Func::readTopic( $forkWeb, $forkTopic );

    my $now = time();
    my $who = Foswiki::Func::getWikiUserName();
    my $rev = $ttmeta->getLoadedRev();

    # create the new topics
    foreach my $newname (@newnames) {
        $newname = Foswiki::Sandbox::untaintUnchecked($newname);
        my ( $w, $t ) =
          Foswiki::Func::normalizeWebTopicName( $forkWeb, $newname );
        if ( Foswiki::Func::topicExists( $w, $t ) ) {
            return
"<span class='foswikiAlert'>WORKFLOWFORK: '$w.$t' already exists</span>";
        }
        my $text = $tttext;
        my $meta = new Foswiki::Meta( $session, $w, $t );

        # Clone the template
        foreach my $k ( keys %$ttmeta ) {

            # Note that we don't carry over the history from the forked topic
            next if ( $k =~ /^_/ || $k eq 'WORKFLOWHISTORY' );
            my @data;
            foreach my $item ( @{ $ttmeta->{$k} } ) {
                my %datum = %$item;
                push( @data, \%datum );
            }
            $meta->putAll( $k, @data );
        }
        my $history = {
            name     => -1,
            author   => $who,
            date     => $now,
            forkfrom => "$forkWeb.$forkTopic",
            rev      => $rev + 1,              # Since there will be a save with
                                               # 'forcenewrevision' it's safe
                                               # to do +1 here.
        };
        $meta->put( "WORKFLOWHISTORY", $history );
        Foswiki::Func::saveTopic( $w, $t, $meta, $text,
            { forcenewrevision => 1 } );
    }

    my @hist = $ttmeta->find('WORKFLOWHISTORY');

    push @hist,
      {
        name   => -1,
        author => $who,
        date   => $now,
        forkto => join( ', ', map { "$forkWeb.$_" } @newnames ),
      };
    $ttmeta->putAll( "WORKFLOWHISTORY", @hist );

    if ($lockdown) {
        $ttmeta->putKeyed( "PREFERENCE",
            { name => 'ALLOWTOPICCHANGE', value => 'nobody' } );
    }

    Foswiki::Func::saveTopic( $forkWeb, $forkTopic, $ttmeta, $tttext,
        { forcenewrevision => 1 } );
}

# Used to trap an edit and check that it is permitted by the workflow
sub beforeEditHandler {
    my ( $text, $topic, $web, $meta ) = @_;

    # Check the state change parameters to see if this edit is
    # part of a state change (state changes may be permitted even
    # for users who can't edit, so we have to suppress the edit
    # check in this case)
    my $changingState = 1;
    my $query         = Foswiki::Func::getCgiQuery();
    foreach my $p (
        qw(WORKFLOWPENDINGACTION WORKFLOWCURRENTSTATE
        WORKFLOWPENDINGSTATE WORKFLOWWORKFLOW)
      )
    {
        if ( !defined $query->param($p) ) {

            # All params must be present to change state
            $changingState = 0;
            last;
        }
    }

    return if $changingState;    # permissions check not required

    my $controlledTopic = _initTOPIC( $web, $topic, undef, $meta, $text );

    return unless $controlledTopic;    # not controlled, so check not required

    unless ( $controlledTopic->canEdit() ) {
        throw Foswiki::OopsException(
            'accessdenied',
            status => 403,
            def    => 'topic_access',
            web    => $_[2],
            topic  => $_[1],
            params => [
                'Edit topic',
'You are not permitted to edit this topic. You have been denied access by Workflow Plugin'
            ]
        );
    }
}

# Check that the user is allowed to attach to the topic, if it is controlled
sub beforeAttachmentSaveHandler {
    my ( $attrHashRef, $topic, $web ) = @_;
    my $controlledTopic = _initTOPIC( $web, $topic );
    return unless $controlledTopic;

    unless ( $controlledTopic->canSave() ) {
        throw Foswiki::OopsException(
            'accessdenied',
            status => 403,
            def    => 'topic_access',
            web    => $_[2],
            topic  => $_[1],
            params => [
                'Edit topic',
'You are not permitted to attach to this topic. You have been denied access by Workflow Plugin'
            ]
        );
    }
}

# The beforeSaveHandler inspects the request parameters to see if the
# right params are present to trigger a state change. The legality of
# the state change is *not* checked - it's assumed that the change is
# coming as the result of an edit invoked by a state transition.
sub beforeSaveHandler {
    my ( $text, $topic, $web, $meta ) = @_;

    # $isStateChange is true if state has just been changed in this session.
    # In this case we don't need the access check.
    return if ($isStateChange);

    # Otherwise we need to check if the packet of state change information
    # is present.
    my $query         = Foswiki::Func::getCgiQuery();
    my $changingState = 1;
    my %stateChangeInfo;
    foreach my $p (
        qw(WORKFLOWPENDINGACTION WORKFLOWCURRENTSTATE
        WORKFLOWPENDINGSTATE WORKFLOWWORKFLOW)
      )
    {
        $stateChangeInfo{$p} = $query->param($p);
        if ( defined $stateChangeInfo{$p} ) {
            $query->delete($p);
        }
        else {

            # All params must be present to change state
            $changingState = 0;
            last;
        }
    }

    my $controlledTopic;

    if ($changingState) {

        # See if we are expecting to apply a new state from query
        # params
        my ( $wfw, $wft ) =
          Foswiki::Func::normalizeWebTopicName( undef,
            $stateChangeInfo{WORKFLOWWORKFLOW} );

        # Can't use initTOPIC, because the data comes from the save
        my $workflow =
          new Foswiki::Plugins::WorkflowPlugin::Workflow( $wfw, $wft );
        $controlledTopic =
          new Foswiki::Plugins::WorkflowPlugin::ControlledTopic( $workflow,
            $web, $topic, $meta, $text );

    }
    else {

        # Otherwise we are *not* changing state so we can use initTOPIC
        $controlledTopic = _initTOPIC( $web, $topic, undef, $meta, $text );
    }

    return unless $controlledTopic;

    if ($changingState) {

        # The beforeSaveHandler has no way to abort the save,
        # so we have to do a state change without a topic save.
        $controlledTopic->changeState(
            $stateChangeInfo{WORKFLOWPENDINGACTION} );
    }
    elsif ( !$controlledTopic->canSave() ) {

        # Not a state change, make sure the AllowEdit in the state table
        # permits this action
        throw Foswiki::OopsException(
            'accessdenied',
            def    => 'topic_access',
            web    => $_[2],
            topic  => $_[1],
            params => [
                'Save topic',
'You are not permitted to save this topic. You have been denied access by Workflow Plugin'
            ]
        );
    }
}

sub afterSaveHandler {
    my ( $text, $topic, $web, $error, $meta ) = @_;

    return if defined $error;

    my $controlledTopic = _initTOPIC( $web, $topic, undef, $meta, $text, 1 );
    return unless $controlledTopic;

    my $mustSave = 0;

    my @hist = $controlledTopic->{meta}->find('WORKFLOWHISTORY');
    for ( my $h = 0 ; $h < @hist ; $h++ ) {
        next unless $hist[$h]->{name} eq '-1';
        @{ $hist[$h] }{qw(name date)} =
          @{ $meta->getRevisionInfo() }{qw(version date)};
        last;
    }
    if (@hist) {
        $controlledTopic->{meta}->remove('WORKFLOWHISTORY');
        $controlledTopic->{meta}->putAll( 'WORKFLOWHISTORY', @hist );
        $mustSave = 1;
    }

    my $lastRev = $controlledTopic->getState(
        'LASTVERSION_' . $controlledTopic->getState() );

    return
      if !$mustSave && defined $lastRev && $lastRev == $meta->getLatestRev();

    $controlledTopic->setState( $controlledTopic->getState(),
        $meta->getLatestRev() );

    try {
        $controlledTopic->{meta}
          ->saveAs( $web, $topic, dontlog => 1, minor => 1 );
    };
}

1;
__END__

 Copyright (C) 2005 Thomas Hartkens <thomas@hartkens.de>
 Copyright (C) 2005 Thomas Weigert <thomas.weigert@motorola.com>
 Copyright (C) 2008-2010 Crawford Currie http://c-dot.co.uk

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details, published at
 http://www.gnu.org/copyleft/gpl.html

