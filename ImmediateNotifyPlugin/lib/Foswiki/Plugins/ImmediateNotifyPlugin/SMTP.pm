# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ImmediateNotifyPlugin::SMTP

This plugin module supports immediate notification of topic saves using the XMPP (Jabber) protocol.
.
=cut

package Foswiki::Plugins::ImmediateNotifyPlugin::SMTP;

use strict;
use Foswiki::Net;

my $debug;
my $warning;

sub new {
    my ($class) = @_;

    my $this = bless( {}, $class );

    $debug   = \&Foswiki::Plugins::ImmediateNotifyPlugin::debug;
    $warning = \&Foswiki::Plugins::ImmediateNotifyPlugin::warning;

    &$debug("- SMTP init ");

    return $this;
}

# ========================
# handleNotify - handles notification for a single notification method
# Parameters: $userHash, $info
#    $userHash is a hash reference of the form username->user topic text
#    $info is an extended topicRevisionInfo hash for the saved topic
sub notify {
    my $this     = shift;
    my $userHash = shift;
    my $info     = shift;

    my ($skin) = Foswiki::Func::getPreferencesValue("SKIN");
    my ($template) = Foswiki::Func::readTemplate( 'smtp', 'immediatenotify' );

    # Expand legacy macros
    my ($from) = Foswiki::Func::getPreferencesValue("WIKIWEBMASTER");
    $template =~ s/%EMAILFROM%/$from/go;
    $template =~ s/%TOPICNAME%/$info->{topic}/go;
    $template =~ s/%USER%/$info->{user}/go;
    $template =~ s/%REV%/$info->{version}/go;

    $template =
      Foswiki::Func::expandCommonVariables( $template, $info->{topic},
        $info->{web} );

    foreach my $userName ( keys %$userHash ) {

        my ($to);
        &$debug("- SMTP: userName $userName");
        my @emails = Foswiki::Func::wikinameToEmails($userName);
        foreach my $email (@emails) {
            $to .= $email . ",";
        }
        if ($to) {
            my $msg = $template;
            $msg =~ s/%EMAILTO%/$to/go;
            &$debug("- SMTP: Sending mail to $to ($userName)");
            &$debug("- SMTP: MESSAGE ($msg)");

            my $error = &Foswiki::Func::sendEmail($msg);

            &$debug("- SMTP: Error ($error)") if ($error);
        }

    }
}

sub connect {
    return 1;
}

sub disconnect {
    return 1;
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
