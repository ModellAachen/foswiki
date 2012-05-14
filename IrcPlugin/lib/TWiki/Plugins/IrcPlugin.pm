# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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

=pod

---+ package IrcPlugin

=cut

package TWiki::Plugins::IrcPlugin;
use strict;

use Net::IRC;
use Data::Dumper;

use vars qw( $VERSION $RELEASE $debug $pluginName );
$VERSION = '$Rev$';
$RELEASE = 'Dakar';

# Name of this Plugin, only used in this module
$pluginName = 'IrcPlugin';

################################################################################

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Plugin correctly initialized
    return 1;
}

sub afterSaveHandler {

    # $text = $[0]
    my ( $topic, $web, $error, $meta ) = @_[ 1 .. 4 ];

    TWiki::Func::writeDebug(
        "- ${pluginName}::afterSaveHandler( ${web}.${topic} )")
      if $debug;

    my $topicInfo = $meta->get('TOPICINFO');

 # Strip the front 1. part of rcs version numbers to get simple revision numbers
    ( my $version = $topicInfo->{version} ) =~ s/^[\d]+\.//;

    _writeIrc(
        {
            newconn => {
                Server => TWiki::Func::getPluginPreferencesValue('SERVER')
                  || 'localhost',
                Port => TWiki::Func::getPluginPreferencesValue('PORT')
                  || '6667',
                Nick => 'TWikiIrcPlugin'
                  || TWiki::Func::getPluginPreferencesValue('NICK')
                  || 'TWikiIrcPlugin',

                #	Ircname  => 'This bot brought to you by Net::IRC.',
                #	Username => 'TWikiIrcPlugin',
            },
                msg => TWiki::Func::getScriptUrl( $web, $topic, 'view' ) . ' '
              . ( $version == 1 ? 'created' : "updated to r$version" )
              . " by $topicInfo->{author}",
        }
    );

    # more code here
}

# SMELL: not mod_perl-friendly!!!
my $looping;

sub _writeIrc {
    my $p = shift;
    print STDERR "_writeIrc:" . Data::Dumper::Dumper($p);

    my $irc = Net::IRC->new() or die $!;
    my $conn = $irc->newconn( %{ $p->{newconn} } );

    # SMELL: make exception
    if ( !$conn ) {

        # SMELL: write to queue
        print STDERR "IrcPlugin: Can't connect to IRC server : "
          . Data::Dumper::Dumper($p);
        return;
    }
    $conn->{msg} = $p->{msg};

    $conn->add_handler( 'msg', \&on_msg );

    $conn->add_global_handler( [ 251, 252, 253, 254, 302, 255 ], \&on_init );
    $conn->add_global_handler( 376, \&on_connect );
    $conn->add_global_handler( 433, \&on_nick_taken );

    #    $irc->start();
    for ( $looping = 1 ; $looping ; ) {
        $irc->do_one_loop();
    }
}

################################################################################

# What to do when the bot successfully connects.
sub on_connect {
    my $self = shift;

    my $CHANNEL = TWiki::Func::getPluginPreferencesValue('CHANNEL') || 'test';
    $self->join($CHANNEL);

    #    print STDERR "nick=[" . $self->nick . "]\n";
    foreach ( $CHANNEL, $self->nick ) {
        $self->privmsg( $_, $self->{msg} );
    }
}

# Handles some messages you get when you connect
sub on_init {
    my ( $self, $event ) = @_;
    my (@args) = ( $event->args );
    shift(@args);

    #    print "*** @args\n";
}

# Change our nick if someone stole it.
sub on_nick_taken {
    my ($self) = shift;

    print STDERR "argh! nick [" . $self->nick . "] taken!!!\n";
    $self->nick( substr( $self->nick, -1 ) . substr( $self->nick, 0, 8 ) );
}

sub on_msg {
    my ( $self, $event ) = @_;
    my ($nick) = $event->nick;

#    print "*$nick*  ", ($event->args), "\n";
# we've received the message we broadcasted; we're done
# SMELL: unless some talked to us, and we didn't actually get back the message back yet...
    $looping = 0;
}

################################################################################

1;
