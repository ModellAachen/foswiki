# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007, 2008, Timothe Litt
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2005 Greg Abbas, twiki@abbas.org
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
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package Foswiki::LoginManager::X509Login

This is login manager that you can specify in the security setup section of
[[%SCRIPTURL{"configure"}%][configure]]. It instructs Foswiki to
cooperate with your web server (typically Apache) to require authentication
information (username & password) from users. It requires that you configure
your web server to demand authentication for scripts named "login" and anything
ending in "auth". The latter should be symlinks to existing scripts; e.g.,
=viewauth -> view=, =editauth -> edit=, and so on.

See also UserAuthentication.

Subclass of Foswiki::LoginManager; see that class for documentation of the
methods of this class.

=cut

package Foswiki::LoginManager::X509Login;
use Foswiki::LoginManager;
our @ISA = qw( Foswiki::LoginManager );

use strict;
use Assert;

=pod

---++ ClassMethod new ($session)

Construct the ApacheLogin object

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = $class->SUPER::new($session);
    $session->enterContext('can_login');

    $this->{foswiki} = $session;

    # Can't logout, though
    Foswiki::registerTagHandler( 'LOGOUT', sub { return '' } );
    return $this;
}

=pod

---++ ObjectMethod checkAccess()

Check if the script being run in this session is authorised for execution.
If not, throw an access control exception.

=cut

sub checkAccess {

    my $this    = shift;
    my $foswiki = $this->{foswiki};

    return $this->SUPER::checkAccess($foswiki)
      unless ( $Foswiki::cfg{Plugins}{X509UserPlugin}{ForceAuthentication} );

    return undef unless ( $Foswiki::cfg{UseClientSessions} );

    return undef if $foswiki->inContext('command_line');

    unless ( $foswiki->inContext('authenticated') ) {
        my $topic = $foswiki->{topicName};
        my $web   = $foswiki->{webName};

        my $script = $ENV{'SCRIPT_NAME'} || $ENV{'SCRIPT_FILENAME'};
        $script =~ s@^.*/([^./]+)@$1@g if $script;

        if ( defined $script && $script eq 'view' )
        {    # All others can be forced with $Foswiki::cfg{AuthScripts}
            if (
                $topic eq (
                    $Foswiki::cfg{Plugins}{X509UserPlugin}{RegistrationTopic}
                      || "UserRegistration"
                )
              )
            {

                my $store = $this->{foswiki}->{store};

                if ( $web eq $Foswiki::cfg{UsersWebName}
                    && $store->topicExists( $Foswiki::cfg{UsersWebName},
                        $topic )
                    || $web eq $Foswiki::cfg{SystemWebName}
                    && $store->topicExists( $Foswiki::cfg{SystemWebName},
                        $topic ) )
                {
                    return undef;
                }
            }

            require Foswiki::AccessControlException;
            throw Foswiki::AccessControlException( $script, $foswiki->{user},
                $web, $topic, 'authentication required' );
        }
    }

    # Let the LoginManager decide

    return $this->SUPER::checkAccess($foswiki);
}

=pod

---++ ObjectMethod forceAuthentication () -> boolean

method called when authentication is required - redirects to (...|view)auth
Triggered on auth fail

=cut

sub forceAuthentication {
    my $this    = shift;
    my $foswiki = $this->{foswiki};
    my $query   = $foswiki->{cgiQuery};

    # See if there is an 'auth' version
    # of this script, may be a result of not being logged in.
    my $script = $ENV{SCRIPT_FILENAME};
    $script =~ s/^(.*\/)([^\/]+?)($Foswiki::cfg{ScriptSuffix})?$/$1/o;
    my $scriptPath = $1;
    my $scriptName = $2;
    $script = $scriptPath . $scriptName . 'auth' . $Foswiki::cfg{ScriptSuffix};

    if ( !$query->remote_user() && -e $script ) {

        # Assemble the new URL using the host, the changed script name,
        # the path info, and the query string.  All three query
        # variables are in the list of the canonical request meta
        # variables in CGI 1.1.
        my $url = $ENV{REQUEST_URI};
        if ( $url && $url =~ m!(.*/$scriptName)([^?]*)! ) {

            # $url should not contain query string as it gets appended
            # in Foswiki::redirect. Script gets 'auth' appended.
            $url = "$foswiki->{urlHost}${1}auth$2";
        }
        else {
            if (   $ENV{SCRIPT_NAME}
                && $ENV{SCRIPT_NAME} =~ s/\/$scriptName/\/${scriptName}auth/ )
            {
                $url = $foswiki->{urlHost} . $ENV{SCRIPT_NAME};
            }
            else {

                # If SCRIPT_NAME does not contain the script name
                # the last hope is to try building up the URL using
                # the SCRIPT_FILENAME.
                $url =
                    $foswiki->{urlHost}
                  . $foswiki->{scriptUrlPath} . '/'
                  . $scriptName . 'auth'
                  . $Foswiki::cfg{ScriptSuffix};
            }
            if ( $ENV{PATH_INFO} ) {
                $url .= '/' unless $url =~ m#/$# || $ENV{PATH_INFO} =~ m#^/#;
                $url .= $ENV{PATH_INFO};
            }
        }

        # Redirect with passthrough so we don't lose the original query params
        $foswiki->redirect( $url, 1 );
        return 1;
    }
    return undef;
}

=pod

---++ ObjectMethod loginUrl () -> $loginUrl

TODO: why is this not used internally? When is it called, and why
Content of a login link

=cut

sub loginUrl {
    my $this    = shift;
    my $foswiki = $this->{foswiki};
    my $topic   = $foswiki->{topicName};
    my $web     = $foswiki->{webName};
    return $foswiki->getScriptUrl( 0, 'logon', $web, $topic, @_ );
}

=pod

---++ ObjectMethod login( $query, $foswiki )

this allows the login and logon cgi-scripts to use the same code. 
all a logon does, is re-direct to viewauth, and apache then figures out 
if it needs to challenge the user

=cut

sub login {
    my ( $this, $query, $foswikiSession ) = @_;

    my $url = $foswikiSession->getScriptUrl(
        0, 'viewauth',
        $foswikiSession->{webName},
        $foswikiSession->{topicName},
        t => time()
    );

    $url .= ( ';' . $query->query_string() ) if $query->query_string();

    $foswikiSession->redirect( $url, 1 );
}

=pod

---++ ObjectMethod getUser () -> $authUser

returns the userLogin if stored in the apache CGI query (ie session)

=cut

sub getUser {
    my $this = shift;

    my $query = $this->{foswiki}->{cgiQuery};
    my $authUser;

    # Ignore remote user if we got here via an error
    unless ( ( $ENV{REDIRECT_STATUS} || 0 ) >= 400 ) {
        if ($query) {
            $authUser = $query->remote_user();
        }
        Foswiki::LoginManager::_trace( $this,
            "apache getUser says " . ( $authUser || 'undef' ) );
    }
    return $authUser;
}

1;
