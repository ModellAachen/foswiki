# Module of Foswiki Collaboration Platform, http://Foswiki.org/
#
# Copyright (C) 2006-9 Sven Dowideit, SvenDowideit@fosiki.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package Foswiki::LoginManager::PhpBB3Login

This is a login manager that you can specify in the security setup section of [[%SCRIPTURL%/configure%SCRIPTSUFFIX%][configure]]. It provides users with a template-based form to enter usernames and passwords, and works with the PasswordManager that you specify to verify those passwords.

Subclass of Foswiki::LoginManager; see that class for documentation of the
methods of this class.

=cut

package Foswiki::LoginManager::PhpBB3Login;

use strict;
use Assert;
use Foswiki::LoginManager::TemplateLogin;

@Foswiki::LoginManager::PhpBB3Login::ISA =
  ('Foswiki::LoginManager::TemplateLogin');

sub new {
    my ( $class, $session ) = @_;

    my $this = bless( $class->SUPER::new($session), $class );
    $session->enterContext('can_login');
    return $this;
}

=pod

---++ ObjectMethod loadSession()

add phpBB3 cookie to the session management

=cut

sub loadSession {
    my $this    = shift;
    my $foswiki = $this->{foswiki};
    my $query   = $foswiki->{cgiQuery};

    ASSERT( $this->isa('Foswiki::LoginManager::PhpBB3Login') ) if DEBUG;

    my $authUser = '';

    # see if there is a phpBB3 username and password cookie
    #TODO: think i should check the password is right too.. otherwise ignore it
    my %cookies = fetch CGI::Cookie;
    if ( defined( $cookies{'usercookie[username]'} ) ) {
        my $id       = $cookies{'usercookie[username]'}->value;
        my $password = $cookies{'usercookie[password]'}->value;
        my $user     = $foswiki->{users}->getCanonicalUserID( $id, undef, 1 );

        #print STDERR "$id, $password, $user";
        my $passwordHandler = $foswiki->{users}->{passwords};

        #return $passwordHandler->checkPassword($this->{login}, $password);

        if ( defined($user)
            && $foswiki->{users}->checkPassword( $user->login(), $password, 1 )
          )
        {
            $authUser = $id;
        }
        else {

#mmm, if they have a cookie, but are not in the dba, either the db connection is busted, or we're in trouble
        }

        $this->userLoggedIn($authUser);
    }
    else {
        $authUser = $this->SUPER::loadSession();
    }
    return $authUser;
}

1;
