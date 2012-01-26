# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ImmediateNotifyPlugin

This plugin supports immediate notification of topic saves.

=cut

package Foswiki::Plugins::ImmediateNotifyPlugin;
use strict;
use warnings;

use Data::Dumper;

our $VERSION           = '$Rev$';
our $RELEASE           = 'v1.0RC';
our $NO_PREFS_IN_TOPIC = 1;

our $debug;

my %methodHandlers;    # Loaded handlers
my %methodAllowed;     # Methods permitted by config.

=begin TML

---+ debug ( $message )

Write debug messages if debug is enabled.

=cut

sub debug { Foswiki::Func::writeDebug(@_) if $debug; }

=begin TML

---+ warning ( $message )

Unconditionally write warning messages to debug log.

=cut

sub warning {
    Foswiki::Func::writeWarning(@_);
    debug( "WARNING" . $_[0], @_[ 1 .. $#_ ] );
}

=begin TML

---+ initPlugin ( $topic, $web, $user)

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;
    my $methodCount = 0;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.011 ) {
        warning(
            "Version mismatch between ImmediateNotifyPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = Foswiki::Func::getPluginPreferencesFlag("DEBUG") || 0;

    # Find any configured methods and make available.
    foreach
      my $method ( keys %{ $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin} } )
    {
        next if ( $method eq "Module" );
        next if ( $method eq "Enabled" );
        next if ( $method eq "Bitly" );     # Bitly is not a notifier plugin
        if ( $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{$method}{Enabled} ) {
            debug("Allowing method $method");
            $methodAllowed{$method} = 1;
            $methodCount++;
        }
    }

    # Plugin correctly initialized
    if ($methodCount) {
        debug(
"- Foswiki::Plugins::ImmediateNotifyPlugin::initPlugin( $web.$topic ) is OK"
        );
        return 1;
    }
    else {
        warning("ImmediateNotifyPlugin - no methods enabled");
        return 0;
    }
}

=begin TML

---+ finishPlugin ( )

Unload and disconnect any notifier methods with open connections.

=cut

sub finishPlugin {

    debug("finishPlugin entered");
    foreach my $handler (%methodHandlers) {
        next unless $handler;
        $methodHandlers{$handler}->disconnect();
        $methodHandlers{$handler} = '';
    }
}

=begin TML

---+ _loadHandler ( $mehod )

Find and load the requested notifitcation method.

=cut

sub _loadHandler {
    my $method = shift;
    return 1 if $methodHandlers{$method};    # Already loaded

    my $handler;

    if ( $methodAllowed{$method} ) {
        debug("- ImmediateNotifyPlugin: Loading method $method...");

        my $module = 'Foswiki::Plugins::ImmediateNotifyPlugin::' . $method;
        eval {
            ( my $file = $module ) =~ s|::|/|g;
            require $file . '.pm';
            $handler = $module->new();
            1;
          }
          or do {
            print STDERR "FAILED TO LOAD  $@";
            warning("- ImmediateNotifyPlugin::$method failed to load $@ $!");
            return 0;
          };

        if ( $handler->connect() ) {
            $methodHandlers{$method} = $handler;
            debug("- ImmediateNotifyPlugin::$method OK");
            return 1;
        }
        else {
            warning("- ImmediateNotifyPlugin::$method failed to load $@ $!");
            return 0;
        }
    }
    else {
        warning(
            "- ImmediateNotifyPlugin::$method not permitted by configuration!");
        return 0;
    }
}

=begin TML

---+ processName ($name, $users, $groups)

   * $name - User Name being processed
   * $users - Hash of users on notification list
   * $groups - Hash of groups on notification list

Parse names to be notified, expanding groups and reading settings for each user.

=cut

sub processName {
    my ( $name, $users, $groups ) = @_;

    debug("- ImmediateNotifyPlugin: Processing name $name");
    return
      if ( exists $users->{$name} || exists $groups->{name} )
      ;    # Already saw this name - skip it.

    if ( Foswiki::Func::isGroup($name) ) {
        $groups->{$name} = $name;

        my $it = Foswiki::Func::eachGroupMember($name);
        while ( $it->hasNext() ) {
            my $user = $it->next();
            processName( $user, $users, $groups );
        }
    }
    else {

        if (
            Foswiki::Func::topicExists( "$Foswiki::cfg{UsersWebName}", $name ) )
        {

        # Must read user topic without auth checking - the user issuing the save
        # does not necessarily have read authority for the user.
            my ( $topicObject, $text ) =
              Foswiki::Func::readTopic( "$Foswiki::cfg{UsersWebName}", $name );

            my $methodString =
              $topicObject->getPreference('IMMEDIATENOTIFYMETHOD');

            debug(
"- ImmediateNotifyPlugin: method setting for $name found /$methodString/"
            );

            if ($methodString) {
                my ( $method, $parms ) =
                  $methodString =~ m/^(.*?)(?:\((.*?)\))?$/;
                $parms |= '';
                debug(
"- ImmediateNotifyPlugin: processName: User $name found method ($method) parms ($parms) "
                );
                $users->{$name}{METHOD} = $method || 'SMTP';
                $users->{$name}{PARMS} = $parms;
            }
            else {
                $users->{$name}{METHOD} = 'SMTP';
                debug(
"- ImmediateNotifyPlugin: processName: User $name chosen no methods, defaulting to SMTP."
                );
            }
        }
        else {
            warning(
"- ImmediateNotifyPlugin: $name not found as a user or group, ignored"
            );
        }
    }
}

=begin TML

---+ beforeSaveHandler

Set a flag if this is a new topic.

=cut

sub beforeSaveHandler {
    my ( $text, $topic, $web, $meta ) = @_;

    unless ( Foswiki::Func::topicExists( $web, $topic ) ) {
        Foswiki::Func::getContext()->{'NewTopic'} = 1;
    }
}

=begin TML

---+ afterSaveHandler

Procesas the saved topic peforming any requested notifications

=cut

sub afterSaveHandler {
    my ( $text, $topic, $web, $error, $topicObject ) = @_;
    my $user = Foswiki::Func::getWikiName();

    my $topicInfo = $topicObject->getRevisionInfo();
    $topicInfo->{topic} = $topic;
    $topicInfo->{web}   = $web;
    $topicInfo->{user}  = $user;

# This handler is called by Foswiki::Store::saveTopic just after the save action.

    debug("- ImmediateNotifyPlugin::afterSaveHandler( $web.$topic )");

    if ($error) {
        debug("- ImmediateNotifyPlugin: Unsuccessful save, not notifying...");
        return;
    }

  #SMELL: We have to use the Meta getPreferences() function so that we get any
  # modified results from the save.  Note:  This needs a fix to Foswiki::Meta to
  # in Item9563 or changes made in the save will be missed.

    my @names;

# Check if the topic contains an IMMEDIATENOTIFY setting and extract names if present
    my $nameString = $topicObject->getPreference('IMMEDIATENOTIFY');
    if ($nameString) {
        debug("- ImmediateNotifyPlugin: Found ($nameString) ");
        chomp $nameString;
        @names = split /[\s,]+/, $nameString;
        foreach my $n (@names) {
            debug(
                "- ImmediateNotifyPlugin: ($n) found in IMMEDIATENOTIFY setting"
            );
        }
    }

  # Retrieve the WebImmediateNotify topic and extract names - ignore permissions
  # in case user saving topic can't access the topic.
    my $notifyTopic =
      Foswiki::Func::readTopicText( $web, "WebImmediateNotify", undef, 1 );
    debug("- ImmediateNotifyPlugin: no WebImmediateNotify topic found in $web")
      unless ($notifyTopic);

    while ( $notifyTopic =~
/(\t+|(   )+)\* (?:\%MAINWEB\%|$Foswiki::cfg{UsersWebName})\.([^\r\n]+)/go
      )
    {
        push @names, $3 if $3;
        debug("- ImmediateNotifyPlugin: Adding $3") if ($3);
    }

    unless ( scalar @names ) {
        debug("- ImmediateNotifyPlugin: No names registered for notification.");
        return;
    }

    # Recursively expand all users / groups into a list of names to notify
    my ( %users, %groups );
    foreach my $name (@names) {
        processName( $name, \%users, \%groups );
    }

    # Extract required methods from the users list and lazy load them
    my %userMethods;
    foreach my $user ( keys %users ) {
        debug("- ImmediateNotifyPlugin processing Users: $user");

        my @methodList = {};
        @methodList = ( $users{$user}{METHOD} );

        foreach my $method (@methodList) {
            if ( _loadHandler($method) ) {
                $userMethods{$user}{$method} = 1;
                debug(
"- ImmediateNotifyPlugin: Handler loaded - Set method to $method for $user "
                );
            }
        }
    }

    foreach my $method ( keys %methodHandlers ) {
        debug("- Processing methods $method");

        #my %methodUsers =
        #  map { $userMethods{$_}{$method} ? ( $_, \$users{$_} ) : () }
        #  keys %users;

        my %methodUsers;
        foreach my $k ( keys %users ) {
            if ( $userMethods{$k}{$method} ) {
                $methodUsers{$k} = $users{$k};
            }
        }

        debug( "- ImmediateNotifyPlugin: $method userlist "
              . join( " ", keys %methodUsers ) );
        if (%methodUsers) {
            $methodHandlers{$method}->notify( \%methodUsers, $topicInfo );
        }
    }
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.

Copyright (C) 2003 Walter Mundt, emage@spamcop.net
Copyright (C) 2003 Akkaya Consulting GmbH, jpabel@akkaya.de

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
