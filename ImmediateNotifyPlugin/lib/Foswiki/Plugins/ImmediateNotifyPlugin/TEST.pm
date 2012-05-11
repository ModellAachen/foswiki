# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ImmediateNotifyPlugin::TEST

This plugin module supports the unit tests.  It on of topic records all actions to STDERR for analysis
.
=cut

package Foswiki::Plugins::ImmediateNotifyPlugin::TEST;
use FoswikiFnTestCase;

use strict;
use warnings;
no warnings 'redefine';

my $debug;
my $warning;

sub new {
    my ($class) = @_;

    my $this = bless( {}, $class );

    $debug   = \&Foswiki::Plugins::ImmediateNotifyPlugin::debug;
    $warning = \&Foswiki::Plugins::ImmediateNotifyPlugin::warning;

    return $this;
}

# ========================
# initMethed - initializes a single notification method
sub connect {
    my $this = shift;

    &$debug("ImmediateNotify:TEST - Simulating connection\n");
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

    my ($skin) = Foswiki::Func::getPreferencesValue("SKIN");
    my ($template) = Foswiki::Func::readTemplate( 'xmpp', 'immediatenotify' );

    &$debug("- TEST:  template read $template");

    # Expand Legacy variables - not used in latest templates
    my ($from) = Foswiki::Func::getPreferencesValue("WIKIWEBMASTER");
    $template =~ s/%EMAILFROM%/$from/go;
    $template =~ s/%USER%/$info->{user}/go;
    $template =~ s/%TOPICNAME%/$info->{topic}/go;
    $template =~ s/%REV%/$info->{version}/go;

    my $body =
      Foswiki::Func::expandCommonVariables( $template, $info->{topic},
        $info->{web} );

    my $toolName = Foswiki::Func::getPreferencesValue("WIKITOOLNAME")
      || "Foswiki";
    foreach my $user ( keys %$userHash ) {

        &$debug(" processing $user");

        my %uHash   = %{ $userHash->{$user} };
        my $uParams = 'none';

        if ( $uHash{PARMS} ) {
            $uParams = $uHash{PARMS};
        }

        push( @FoswikiFnTestCase::mails,
            "TEST Sending To: $user, PARAMS $uParams, BODY: $body" );
    }
}

# ========================
# disconnect - Close any persistent connection to the server
sub disconnect {
    my $this = shift;

    &$debug(" TEST - disconnect completed\n");
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
