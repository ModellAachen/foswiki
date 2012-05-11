# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) Evolved Media Network 2005
# Copyright (C) Spanlink Communications 2006
# and Foswiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
#
# Authors: Crawford Currie http://c-dot.co.uk
# Author: Sven Dowideit http://fosiki.com
# Author: Eugen Mayer http://impressimpressive-media.de
#
# This plugin helps with permissions management by displaying the web
# permissions in a big table that can easily be edited. It updates
# WebPreferences in each affected web.
#
# =========================

package Foswiki::Plugins::WebPermissionsPlugin::Core;

use strict;

use CGI (':all');
use Foswiki::Meta ();

# =========================
our $antiBeforeSaveRecursion;

# =========================

# Handle %WEBPERMISSIONS% for Display and Edit
sub WEBPERMISSIONS {
    my ( $session, $params, $topic, $web ) = @_;
    my $query   = $session->{cgiQuery};
    my $action  = $query->param('web_permissions_action') || 'Display';
    my $editing = $action eq 'Edit';

    unless (
        Foswiki::Func::checkAccessPermission(
            'CHANGE', Foswiki::Func::getWikiName(),
            undef,    $Foswiki::cfg{WebPrefsTopicName},
            $web
        )
      )
    {
        $editing = 0;
    }

    my @modes =
      split( /[\s,]+/,
        $Foswiki::cfg{Plugins}{WebPermissionsPlugin}{modes} || 'VIEW,CHANGE' );

    my @webs       = Foswiki::Func::getListOfWebs('user');
    my $chosenWebs = $params->{webs};
    if ($chosenWebs) {
        @webs = _filterList( $chosenWebs, @webs );
    }

    my @knownusers;
    my $chosenUsers = $params->{users} || $query->param('users') || '';

    my %table;
    foreach $web (@webs) {

        next
          unless (
            $web = Foswiki::Sandbox::untaint(
                $web,
                sub { Foswiki::Func::isValidWebName( $_[0] ) ? $_[0] : undef }
            )
          );

        my $acls = _getACLs( \@modes, $web );

        unless ( scalar(@knownusers) ) {
            @knownusers = keys %$acls;
            if ($chosenUsers) {
                @knownusers = _filterList( $chosenUsers, @knownusers );
            }
        }
        $table{$web} = $acls;
    }

    # Generate the table
    my $tab = '';

    my %images;
    foreach my $op (@modes) {
        if (
            Foswiki::Func::attachmentExists(
                $Foswiki::cfg{SystemWebName}, 'WebPermissionsPlugin',
                $op . '.gif'
            )
          )
        {
            $images{$op} = CGI::img(
                {
                    src => Foswiki::Func::getPubUrlPath() . '/'
                      . $Foswiki::cfg{SystemWebName}
                      . '/WebPermissionsPlugin/'
                      . $op . '.gif',
                    alt => $op,
                }
            );
            $tab .= $images{$op} . ' ' . $op;
        }
        else {
            $images{$op} = $op;
        }
    }

    $tab .= CGI::start_table( { border => 1, class => 'foswikiTable' } );

    my $repeat_heads = $params->{repeatheads} || 0;
    my $repeater = 0;
    my $row;

    foreach my $user ( sort @knownusers ) {
        unless ($repeater) {
            $row = CGI::th('');
            foreach $web (@webs) {
                $row .= CGI::th($web);
            }
            $tab .= CGI::Tr($row);
            $repeater = $repeat_heads;
        }
        $repeater--;
        $row = CGI::th( $user . ' ' );
        foreach $web ( sort @webs ) {
            my $cell;
            foreach my $op (@modes) {

                # Generate a single cell in the permissions table.
                if ($editing) {
                    my %attrs = (
                        type => 'checkbox',
                        name => $user . ':' . $web . ':' . $op
                    );
                    $attrs{checked} = 'checked'
                      if $table{$web}->{$user}->{$op};
                    $cell .= CGI::label(
                        ( $images{$op} || $op ) . CGI::input( \%attrs ) );
                }
                elsif ( $table{$web}->{$user}->{$op} ) {
                    $cell .= $images{$op} || $op;
                }
            }
            $row .= CGI::td($cell);
        }
        $tab .= CGI::Tr($row);
    }
    $tab .= CGI::end_table();

    my $can_edit = 1;
    my $reason   = '';
    if ( !scalar(@knownusers) ) {
        $can_edit = 0;
        $reason   = "No authorised users in '$chosenUsers'";
    }
    elsif (
        !Foswiki::Func::checkAccessPermission(
            'CHANGE', Foswiki::Func::getWikiName(),
            undef,    $Foswiki::cfg{WebPrefsTopicName},
            $web
        )
      )
    {
        $can_edit = 0;
        $reason   = "Access denied";
    }

    if ( $editing && $can_edit ) {
        $action = Foswiki::Func::getScriptUrl( 'WebPermissionsPlugin', 'change',
            'rest' );
        $tab .= CGI::submit(
            -name  => 'web_permissions_action',
            -value => 'Save',
            -class => 'foswikiSubmit'
        );
        $tab .= CGI::submit(
            -name  => 'web_permissions_action',
            -value => 'Cancel',
            -class => 'foswikiSubmit'
        );
    }
    else {
        $action = Foswiki::Func::getScriptUrl( $web, $topic, 'view',
            '#' => 'webpermissions_matrix' );
        if ($can_edit) {
            $tab .= CGI::submit(
                -name  => 'web_permissions_action',
                -value => 'Edit',
                -class => 'foswikiSubmit'
            );
        }
        else {
            $tab .= "Cannot edit: $reason";
        }
    }
    my $page = CGI::start_form( -method => 'POST', -action => $action );

    # Anchor for jumping back to
    $page .= CGI::a( { name => 'webpermissions_matrix' } );

    # Note: use CGI::input rather than CGI::hidden below because CGI::hidden
    # splits the comma-separated value into separate multiple values
    $page .= CGI::input(
        { type => 'hidden', name => 'topic', value => "$web.$topic" } );
    if ( defined $chosenWebs ) {
        $page .= CGI::input(
            { type => 'hidden', name => 'webs', value => $chosenWebs } );
    }
    if ( defined $chosenUsers ) {
        $page .= CGI::input(
            { type => 'hidden', name => 'users', value => $chosenUsers } );
    }

    $page .= $tab . CGI::end_form();
    return $page;
}

sub _returnRESTResult {
    my ( $response, $status, $text ) = @_;
    $response->header(
        -status => $status,
        -type   => 'text/plain'
    );
    $response->print($text);
    print STDERR $text if ( $status >= 400 );
}

# Rest handler for a change to the permissions
sub changeHandler {
    my ( $session, $plugin, $verb, $response ) = @_;
    my $request = Foswiki::Func::getCgiQuery();
    my $action  = $request->param('web_permissions_action');

    my ( $tweb, $ttopic ) =
      Foswiki::Func::normalizeWebTopicName( undef,
        $request->param('topic') || '' );
    unless ( Foswiki::Func::isValidWebName($tweb)
        && Foswiki::Func::isValidTopicName($ttopic) )
    {
        _returnRESTResult( $response, 400, "Bad topic" );
        return undef;
    }
    my $chosenWebs  = $request->param('webs');
    my $chosenUsers = $request->param('users');

    if ( $action ne 'Cancel' ) {

        if ( $request->method() && uc( $request->method() ) ne 'POST' ) {
            _returnRESTResult( $response, 405, "Must use POST" );
            return undef;

        }

        my @modes = split( /[\s,]+/,
            $Foswiki::cfg{Plugins}{WebPermissionsPlugin}{modes}
              || 'VIEW,CHANGE' );

        my @webs = Foswiki::Func::getListOfWebs('user');
        if ($chosenWebs) {
            @webs = _filterList( $chosenWebs, @webs );
        }
        my @knownusers;

        my %table;
        foreach my $web (@webs) {
            next
              unless (
                $web = Foswiki::Sandbox::untaint(
                    $web,
                    sub {
                        Foswiki::Func::isValidWebName( $_[0] ) ? $_[0] : undef;
                    }
                )
              );

            next
              unless (
                Foswiki::Func::checkAccessPermission(
                    'CHANGE', Foswiki::Func::getWikiName(),
                    undef,    $Foswiki::cfg{WebPrefsTopicName},
                    $web
                )
              );

            my $acls = _getACLs( \@modes, $web );

            unless ( scalar(@knownusers) ) {
                @knownusers = keys %$acls;
                if ($chosenUsers) {
                    @knownusers = _filterList( $chosenUsers, @knownusers );
                }
            }
            my $changes = 0;
            foreach my $user (@knownusers) {
                foreach my $op (@modes) {
                    my $onoff =
                      $request->param( $user . ':' . $web . ':' . $op );
                    if ( $onoff && !$acls->{$user}->{$op}
                        || !$onoff && $acls->{$user}->{$op} )
                    {
                        $changes++;
                        $acls->{$user}->{$op} = $onoff;
                    }
                }
            }

            # Commit changes to ACLs
            if ($changes) {
                _setACLs( \@modes, $acls, $web );
            }
            else {
                print STDERR "No changes in $web\n";
            }
        }
    }

    Foswiki::Func::redirectCgiQuery(
        $request,
        Foswiki::Func::getScriptUrl(
            $tweb, $ttopic, 'view',
            '#'   => 'webpermissions_matrix',
            webs  => $chosenWebs,
            users => $chosenUsers
        )
    );
    return undef;
}

sub TOPICPERMISSIONS {
    my ( $session, $params, $topic, $web ) = @_;

    my $disableSave = 'Disabled';
    $disableSave = ''
      if Foswiki::Func::checkAccessPermission( 'CHANGE',
        Foswiki::Func::getWikiUserName(),
        undef, $topic, $web );

    my $pluginPubUrl =
        Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName}
      . '/WebPermissionsPlugin';

    #add the JavaScript
    my $jscript =
      Foswiki::Func::readTemplate( 'webpermissionsplugin', 'topicjavascript' );
    $jscript =~ s/%PLUGINPUBURL%/$pluginPubUrl/g;
    Foswiki::Func::addToHEAD( 'WebPermissionsPlugin', $jscript );

    my $templateText =
      Foswiki::Func::readTemplate( 'webpermissionsplugin', 'topichtml' );
    $templateText =~ s/%SCRIPT%/%SCRIPTURL{save}%/g
      if ( $disableSave eq '' );
    $templateText =~ s/%SCRIPT%/%SCRIPTURL{view}%/g
      unless ( $disableSave eq '' );
    $templateText =
      Foswiki::Func::expandCommonVariables( $templateText, $topic, $web );

    my $topicViewerGroups = '';
    my $topicViewers      = '';
    my $topicEditorGroups = '';
    my $topicEditors      = '';
    my $unselectedGroups  = '';
    my $unselectedUsers   = '';

    my $acls = _getACLs( [ 'VIEW', 'CHANGE' ], $web, $topic );
    foreach my $user ( sort ( keys %$acls ) ) {
        my $isGroup = Foswiki::Func::isGroup($user);

        if ( $acls->{$user}->{CHANGE} ) {
            $topicEditors .= '<OPTION>' . $user . '</OPTION>'
              unless $isGroup;
            $topicEditorGroups .= '<OPTION>' . $user . '</OPTION>'
              if $isGroup;
        }
        elsif ( $acls->{$user}->{VIEW} ) {
            $topicViewers .= '<OPTION>' . $user . '</OPTION>'
              unless $isGroup;
            $topicViewerGroups .= '<OPTION>' . $user . '</OPTION>'
              if $isGroup;
        }
        else {
            $unselectedUsers .= '<OPTION>' . $user . '</OPTION>'
              unless $isGroup;
            $unselectedGroups .= '<OPTION>' . $user . '</OPTION>'
              if $isGroup;
        }
    }
    $templateText =~ s/%EDITGROUPS%/$topicEditorGroups/g;
    $templateText =~ s/%EDITUSERS%/$topicEditors/g;
    $templateText =~ s/%VIEWGROUPS%/$topicViewerGroups/g;
    $templateText =~ s/%VIEWUSERS%/$topicViewers/g;
    $templateText =~ s/%UNSELECTEDGROUPS%/$unselectedGroups/g;
    $templateText =~ s/%UNSELECTEDUSERS%/$unselectedUsers/g;
    $templateText =~ s/%PLUGINNAME%/WebPermissionsPlugin/g;
    $templateText =~ s/%DISABLESAVE%/$disableSave/g;

    return $templateText;
}

sub beforeSaveHandler {
    my ( $text, $topic, $web, $meta ) = @_;
    my $query  = Foswiki::Func::getCgiQuery();
    my $action = $query->param('topic_permissions_action');
    return unless ( defined($action) );    #nothing to do with this plugin

    Foswiki::Func::writeDebug(
        "WebPermissionsPlugin::Core::beforeSaveHandler: action=" . $action )
      if (Foswiki::Plugins::WebPermissionsPlugin::TRACE);

    if ( $action ne 'Save' ) {

        # SMELL: canceling out from, or just stopping a save seems
        # to be quite difficult
        Foswiki::Func::redirectCgiQuery( $query,
            Foswiki::Func::getScriptUrl( $web, $topic, 'view' ) );
        throw Error::Simple('cancel permissions action');
    }

    return if ($antiBeforeSaveRecursion);
    $antiBeforeSaveRecursion++;

    # these lists only contain seelcted users (by using javascript
    # to select the changed ones in save onclick)
    my @topicEditors    = $query->param('topiceditors');
    my @topicViewers    = $query->param('topicviewers');
    my @disallowedUsers = $query->param('disallowedusers');

    if ( ( @topicEditors || @topicViewers || @disallowedUsers ) ) {

        #TODO: change this to get modes from params
        my @modes = split( /[\s,]+/,
            $Foswiki::cfg{Plugins}{WebPermissionsPlugin}{modes}
              || 'VIEW,CHANGE' );
        my $acls = _getACLs( \@modes, $web, $topic );
        my ( $userName, $userObj );
        foreach $userName (@topicEditors) {
            $acls->{$userName}->{'CHANGE'} = 1;
            $acls->{$userName}->{'VIEW'}   = 1;
        }
        foreach $userName (@topicViewers) {
            $acls->{$userName}->{'CHANGE'} = 0;
            $acls->{$userName}->{'VIEW'}   = 1;
        }
        foreach $userName (@disallowedUsers) {
            $acls->{$userName}->{'CHANGE'} = 0;
            $acls->{$userName}->{'VIEW'}   = 0;
        }

        # TODO: what exactly happens on error?
        _setACLs( \@modes, $acls, $web, $topic );

        # read in what setACLs just saved, (don't grok why redirect
        # looses the save)
        ( $_[3], $_[0] ) = Foswiki::Func::readTopic( $_[2], $_[1] );

        # SMELL: canceling out from, or just stopping a save seems
        # to be quite difficult
        # return a redirect to view..
        Foswiki::Func::redirectCgiQuery( $query,
            Foswiki::Func::getScriptUrl( $web, $topic, 'view' ) );
        throw Error::Simple('permissions action saved');
    }
}

# Filter a list of strings based on the filter expression passed in
sub _filterList {
    my $filter = shift;
    my %included;

    foreach my $expr ( split( /,/, $filter ) ) {
        my $exclude = ( $expr =~ s/^-// ) ? 1 : 0;
        $expr =~ s/\*/.*/g;
        $expr =~ s/\?/./g;
        foreach my $item (@_) {

            # The \s's are needed to retain compatibility
            if ( $item =~ /^\s*$expr\s*$/ ) {
                if ($exclude) {
                    delete $included{$item};
                }
                else {
                    $included{$item} = 1;
                }
            }
        }
    }
    return keys %included;
}

sub USERSLIST {
    my ( $this, $params ) = @_;
    my $format = $params->{_DEFAULT} || $params->{'format'} || '$wikiname';
    my $separator = $params->{separator} || "\n";
    $separator =~ s/\$n/\n/;
    my $selection = $params->{selection} || '';
    $selection =~ s/\,/ /g;
    $selection = " $selection ";
    my $marker = $params->{marker} || 'selected="selected"';

    my @items;
    foreach my $item ( _getListOfUsers() ) {
        my $line = $format;
        $line =~ s/\$wikiname\b/$item/ge;
        my $mark = ( $selection =~ / \Q$item\E / ) ? $marker : '';
        $line =~ s/\$marker/$mark/g;
        if ( defined(&Foswiki::Func::decodeFormatTokens) ) {
            $line = Foswiki::Func::decodeFormatTokens($line);
        }
        else {
            $line =~ s/\$n\(\)/\n/gs;
            $line =~ s/\$n([^$Foswiki::regex{mixedAlpha}]|$)/\n$1/gs;
            $line =~ s/\$nop(\(\))?//gs;
            $line =~ s/\$quot(\(\))?/\"/gs;
            $line =~ s/\$percnt(\(\))?/\%/gs;
            $line =~ s/\$dollar(\(\))?/\$/gs;
        }
        push( @items, $line );
    }
    return join( $separator, @items );
}

# Get a list of all registered users
sub _getListOfUsers {
    my @list;
    my $it = Foswiki::Func::eachUser();
    while ( $it->hasNext() ) {
        my $user = $it->next();
        push( @list, $user );
    }
    return @list;
}

# Get a list of all groups
sub _getListOfGroups {
    my @list;
    my $it = Foswiki::Func::eachGroup();
    while ( $it->hasNext() ) {
        my $user = $it->next();
        push( @list, $user );
    }
    return @list;
}

# _getACLs( \@modes, $web, $topic ) -> \%acls
# Get the Access Control Lists controlling which registered users
# *and groups* are allowed to access the topic (web).
#    * =\@modes= - list of access modes you are interested in;
#      e.g. [ "VIEW","CHANGE" ]
#    * =$web= - the web
#    * =$topic= - if =undef=  then the setting is taken as a web setting
#      e.g. WEBVIEW. Otherwise it is taken as a topic setting e.g. TOPICCHANGE
#
# =\%acls= is a hash indexed by *user name* (web.wikiname). This maps to
# a hash indexed by *access mode* e.g. =VIEW=, =CHANGE= etc. This in turn
# maps to a boolean; 0 for access denied, non-zero for access permitted.
# <verbatim>
# my $acls = Foswiki::Func::getACLs( [ 'VIEW', 'CHANGE', 'RENAME' ],
#                                    $web, $topic );
# foreach my $user ( keys %$acls ) {
#     if( $acls->{$user}->{VIEW} ) {
#         print STDERR "$user can view $web.$topic\n";
#     }
# }
# </verbatim>
# The =\%acls= object may safely be written to e.g. for subsequent use with
# =setACLs=.
#
# __Note__ topic ACLs are *not* the final permissions used to control
# access to a topic. Web level restrictions may apply that prevent certain
# access modes for individual topics.
#
# *WARNING* when you use =setACLs= to set the ACLs of a web or topic, the
# change is not committed to the database until the current session exits.
# After =setACLs= has been called on a web or topic, the results of
# =getACLS= for that web/topic are *undefined* within the same session.
#

sub _getACLs {
    my ( $modes, $web, $topic ) = @_;

    my $context = 'TOPIC';
    unless ($topic) {
        $context = 'WEB';
        $topic   = $Foswiki::cfg{WebPrefsTopicName};
    }
    Foswiki::Func::writeDebug(
        "WebPermissionsPlugin::Core::_getACLs: GET $context $web.$topic")
      if (Foswiki::Plugins::WebPermissionsPlugin::TRACE);
    my @knownusers = _getListOfUsers();
    push( @knownusers, _getListOfGroups() );

    my %acls;

    # By default, allow all to access all
    foreach my $user (@knownusers) {
        foreach my $mode (@$modes) {
            $acls{$user}->{$mode} = 1;
        }
    }

    Foswiki::Func::pushTopicContext( $web, $topic );

    foreach my $mode (@$modes) {
        foreach my $perm ( 'ALLOW', 'DENY' ) {
            my $users;

            $users = Foswiki::Func::getPreferencesValue("$perm$context$mode");

            if ( defined $users ) {
                Foswiki::Func::writeDebug(
"WebPermissionsPlugin::Core::_getACLs: $perm$context$mode=$users"
                ) if (Foswiki::Plugins::WebPermissionsPlugin::TRACE);
            }
            else {
                Foswiki::Func::writeWarning(
"WebPermissionsPlugin::Core::_getACLs: no $perm$context$mode defined"
                );
            }

            next unless $users;

            my @lusers =
              grep { $_ }
              map {
                my ( $w, $t ) = Foswiki::Func::normalizeWebTopicName(
                    $Foswiki::cfg{UsersWebName}, $_ );
                $t;
              } split( /[ ,]+/, $users || '' );

            # expand groups
            my @users;
            while ( scalar(@lusers) ) {
                my $user = pop(@lusers);
                if ( Foswiki::Func::isGroup($user) ) {

                    # expand groups and add individual users
                    my $it = Foswiki::Func::eachGroupMember($user);
                    while ( $it && $it->hasNext() ) {
                        push( @lusers, $it->next() );
                    }
                }
                push( @users, $user );
            }

            if ( $perm eq 'ALLOW' ) {

                # If ALLOW, only users in the ALLOW list are permitted,
                # so change the default for all other users to 0.
                foreach my $user (@knownusers) {

                    Foswiki::Func::writeDebug(
"WebPermissionsPlugin::Core::_getACLs: Disallow $mode $user"
                    ) if (Foswiki::Plugins::WebPermissionsPlugin::TRACE);
                    $acls{$user}->{$mode} = 0;
                }
                foreach my $user (@users) {

                    Foswiki::Func::writeDebug(
"WebPermissionsPlugin::Core::_getACLs: Allow $mode $user"
                    ) if (Foswiki::Plugins::WebPermissionsPlugin::TRACE);
                    $acls{$user}->{$mode} = 1;
                }
            }
            else {
                foreach my $user (@users) {

                    Foswiki::Func::writeDebug(
"WebPermissionsPlugin::Core::_getACLs: Deny $mode $user "
                    ) if (Foswiki::Plugins::WebPermissionsPlugin::TRACE);
                    $acls{$user}->{$mode} = 0;
                }
            }
        }
    }

    Foswiki::Func::popTopicContext();

    return \%acls;
}

# ---++ _setACLs( \@modes, \%acls, $web, $topic )
# Set the access controls on the named topic.
#    * =\@modes= - list of access modes you want to set;
#      e.g. [ "VIEW","CHANGE" ]
#    * =$web= - the web
#    * =$topic= - if =undef=, then this is the ACL for the web. otherwise
#      it's for the topic.
#    * =\%acls= - must be a hash indexed by *user name* (web.wikiname).
#      This maps to a hash indexed by *access mode* e.g. =VIEW=, =CHANGE=
#      etc. This in turn maps to a boolean value; 1 for allowed, and 0 for
#      denied. See =getACLs= for an example of this kind of object.
#
# Access modes used in \%acls that do not appear in \@modes are simply ignored.
#
# If there are any errors, then an =Error::Simple= will be thrown.
#
# *WARNING* when you use =setACLs= to set the ACLs of a web or topic, the
# change is not committed to the database until the current session exits.
# After =setACLs= has been called on a web or topic, the results of =getACLS=
# for that web/topic are *undefined*.

sub _setACLs {
    my ( $modes, $acls, $web, $topic ) = @_;

    my $context = 'TOPIC';
    unless ($topic) {
        $context = 'WEB';
        $topic   = $Foswiki::cfg{WebPrefsTopicName};
    }

    Foswiki::Func::writeDebug(
        "WebPermissionsPlugin::Core::_setACLs: SET $context $web.$topic ")
      if (Foswiki::Plugins::WebPermissionsPlugin::TRACE);
    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    my @knownusers = _getListOfUsers();
    push( @knownusers, _getListOfGroups() );

    foreach my $op (@$modes) {
        my @allowed = grep { $acls->{$_}->{$op} } @knownusers;
        my @denied  = grep { !$acls->{$_}->{$op} } @knownusers;

        # Remove existing preferences of this type in text
        $text =~ s/^(   |\t)+\* Set (ALLOW|DENY)$context$op =.*$//gm;
        $meta->remove( 'PREFERENCE', 'DENY' . $context . $op );
        $meta->remove( 'PREFERENCE', 'ALLOW' . $context . $op );

        if ( scalar(@denied) ) {

            # Work out the access modes
            my $name;
            my $set;
            if ( scalar(@denied) <= scalar(@allowed) ) {
                $name = 'DENY' . $context . $op;
                $set  = \@denied;
            }
            else {
                $name = 'ALLOW' . $context . $op;
                $set  = \@allowed;
            }
            if ( $Foswiki::cfg{Plugins}{WebPermissionsPlugin}{UsePlainText} ) {
                $text .= "\n   * Set $name = " . join( ' ', @$set );
            }
            else {
                $meta->putKeyed(
                    'PREFERENCE',
                    {
                        name  => $name,
                        type  => 'Set',
                        title => 'PREFERENCE_' . $name,
                        value => join( ' ', @$set )
                    }
                );
            }
            Foswiki::Func::writeDebug(
                "WebPermissionsPlugin::Core::_setACLs: $name = "
                  . join( ' ', @$set ) )
              if (Foswiki::Plugins::WebPermissionsPlugin::TRACE);
        }
    }

    # If there is an access control violation this will throw.
    Foswiki::Func::saveTopic( $web, $topic, $meta, $text, { minor => 1 } );
}

1;
