# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ImmediateNotifyPlugin::IRC

This plugin module supports immediate notification of topic saves using the IRC (Jabber) protocol.
.
=cut

package Foswiki::Plugins::ImmediateNotifyPlugin::IRC;

use strict;
use warnings;

#use Net::IRC;  DEPRECATED

use Bot::BasicBot;
use Data::Dumper;

my $debug;
my $warning;

sub new {
    my ($class) = @_;

    my $this = bless( {}, $class );

    $this->{ircUser} =
      $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{IRC}{Username};
    $this->{ircPass} =
      $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{IRC}{Password};
    $this->{ircServer} =
      $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{IRC}{Server};

    # SMELL: Resource allows multiple concurrent logins - consider including
    # the pid or some other identifier so multiple fastcgi handlers could
    # maintain concurrent connections.
    $this->{ircResource} =
      'Foswiki';    #Foswiki::Func::getPreferencesValue( 'WIKITOOLNAME' );
    $this->{con} = '';

    $debug   = \&Foswiki::Plugins::ImmediateNotifyPlugin::debug;
    $warning = \&Foswiki::Plugins::ImmediateNotifyPlugin::warning;

    &$debug(
"- IRC init with $this->{ircUser},  $this->{ircPass}, $this->{ircServer}"
    );

    return $this;
}

sub afterSaveHandler {

    # $text = $[0]
    my ( $topic, $web, $error, $meta ) = @_[ 1 .. 4 ];

    Foswiki::Func::writeDebug(
        "- ${pluginName}::afterSaveHandler( ${web}.${topic} )")
      if $debug;

    my $topicInfo = $meta->get('TOPICINFO');

 # Strip the front 1. part of rcs version numbers to get simple revision numbers
    ( my $version = $topicInfo->{version} ) =~ s/^[\d]+\.//;

    _writeIrc(
        {
            newconn => {
                Server => Foswiki::Func::getPluginPreferencesValue('SERVER')
                  || 'localhost',
                Port => Foswiki::Func::getPluginPreferencesValue('PORT')
                  || '6667',
                Nick => 'FoswikiIrcPlugin'
                  || Foswiki::Func::getPluginPreferencesValue('NICK')
                  || 'FoswikiIrcPlugin',

                #	Ircname  => 'This bot brought to you by Net::IRC.',
                #	Username => 'FoswikiIrcPlugin',
            },
                msg => Foswiki::Func::getScriptUrl( $web, $topic, 'view' ) . ' '
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

    my $CHANNEL = Foswiki::Func::getPluginPreferencesValue('CHANNEL') || 'test';
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

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.

Additional copyrights apply to some or all of the code in this
file as follows:
Copyright (C) 2005 TWiki Contributors. All Rights Reserved.
   TWiki Contributors are listed in the AUTHORS file in the root
   of the TWiki distribution.
Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

