# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ImmediateNotifyPlugin::XMPP

This plugin module supports immediate notification of topic saves using the XMPP (Jabber) protocol.
.
=cut

package Foswiki::Plugins::ImmediateNotifyPlugin::XMPP;

use strict;
use warnings;

# SMELL: Net::XMPP::Debug requires a patch in perl >= 5.12 to avoid warnings
# https://rt.cpan.org/Ticket/Display.html?id=58333
use Net::XMPP;

my $debug;
my $warning;

sub new {
    my ($class) = @_;

    my $this = bless( {}, $class );

    $this->{xmppUser} =
      $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{XMPP}{Username};
    $this->{xmppPass} =
      $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{XMPP}{Password};
    $this->{xmppServer} =
      $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{XMPP}{Server};

    # SMELL: Resource allows multiple concurrent logins - consider including
    # the pid or some other identifier so multiple fastcgi handlers could
    # maintain concurrent connections.
    $this->{xmppResource} =
      'Foswiki';    #Foswiki::Func::getPreferencesValue( 'WIKITOOLNAME' );
    $this->{con} = '';

    $debug   = \&Foswiki::Plugins::ImmediateNotifyPlugin::debug;
    $warning = \&Foswiki::Plugins::ImmediateNotifyPlugin::warning;

    &$debug(
"- XMPP init with $this->{xmppUser},  $this->{xmppPass}, $this->{xmppServer}"
    );

    return $this;
}

# ========================
# initMethed - initializes a single notification method
sub connect {
    my $this = shift;

    return
      unless defined( $this->{xmppUser} )
          && defined( $this->{xmppPass} )
          && defined( $this->{xmppServer} );

# SMELL: XML::Stream::Parser < 1.23_02 has a bug in new{}.
# See: https://rt.cpan.org/Ticket/Display.html?id=56574
# It fails to shift $this off of the parameter list and therefor has an odd
# number of arguments.   The while loop that converts the arg list to a hash array
# then throws a warning - undefined argument to call to lc.   Shifting $this off of
# parameter list would be a fix.   For now suppress warnings.
    $^W = 0;

    $this->{con} = Net::XMPP::Client->new();
    &$debug("- XMPP: Connecting to server $this->{xmppServer}...");
    $this->{con}->Connect(
        hostname => $this->{xmppServer},
        port     => 5222,
        timeout  => 2,                   # Want this fast - don's slow down save
    );
    unless ( $this->{con}->Connected() ) {
        &$warning(
            "- XMPP: Could not connect to XMPP server $this->{xmppServer}");
        return 0;
    }
    &$debug(
"- XMPP: Connected, logging in with ($this->{xmppUser}) and ($this->{xmppPass})..."
    );
    my @authResult = $this->{con}->AuthIQAuth(
        username => $this->{xmppUser},
        password => $this->{xmppPass},
        resource => $this->{xmppResource},
    );
    if ( $authResult[0] ne 'ok' ) {
        &$warning(
"- XMPP: Could not log in to XMPP server $this->{xmppServer} ($this->{xmppUser}), ($this->{xmppPass}): $authResult[0] $authResult[1]"
        );
        $this->{con}->Disconnect();
        undef $this->{con};
        return 0;
    }

    # Restore warnings
    $^W = 1;

    return 1;
}

# ========================
# handleNotify - handles notification for a single notification method
# Parameters: $userHash, $info
#    $userHash is a hash reference of the form username->user topic text
#    $info is a hash reference for an extended topicRevisionInfo of the saved topic
sub notify {
    my $this     = shift;
    my $userHash = shift;
    my $info     = shift;

    unless ( $this->{con} && $this->{con}->Connected() ) {
        &$warning(
"- XMPP: Connection to server is not open - cannot notify: $this->{xmppServer} ($this->{xmppUser})"
        );
        return;
    }

    my ($skin) = Foswiki::Func::getPreferencesValue("SKIN");
    my ($template) = Foswiki::Func::readTemplate( 'xmpp', 'immediatenotify' );

    &$debug("- XMPP:  template read $template");

    # Expand Legacy variables - not used in latest templates
    my ($from) = Foswiki::Func::getPreferencesValue("WIKIWEBMASTER");
    $template =~ s/%EMAILFROM%/$from/go;
    $template =~ s/%USER%/$info->{user}/go;
    $template =~ s/%TOPICNAME%/$info->{topic}/go;
    $template =~ s/%REV%/$info->{version}/go;

    my $body =
      Foswiki::Func::expandCommonVariables( $template, $info->{topic},
        $info->{web} );

    &$debug("- XMPP: Logged in OK, sending messages...");
    my $toolName = Foswiki::Func::getPreferencesValue("WIKITOOLNAME")
      || "Foswiki";
    foreach my $user ( keys %$userHash ) {

        &$debug(" processing $user");

        my %uHash = %{ $userHash->{$user} };

        # TODO:  Allow serverless ID's - substute in the @server for destination
        # get jabber userid
        my $jabberID;
        if ( $uHash{PARMS} ) {
            $jabberID = $uHash{PARMS};
            &$debug("- XMPP: User $user: $jabberID");
        }
        next unless $jabberID;
        my $message = Net::XMPP::Message->new();
        my $topicUrl =
          Foswiki::Func::getViewUrl( $info->{web}, $info->{topic} );
        $message->SetMessage(
            to   => $jabberID,
            from => "$user\@$this->{xmppServer}",
            body => $body
        );
        $this->{con}->Send($message);
    }

    #$this->{con}->Disconnect();
}

# ========================
# disconnect - Close any persistent connection to the server
sub disconnect {
    my $this = shift;

    if ( $this->{con} && $this->{con}->Connected() ) {
        $this->{con}->Disconnect();
        &$debug(" disconnect completed XMPP");
    }
    return 0;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.

Copyright (C) 2010-2011 George Clark
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
