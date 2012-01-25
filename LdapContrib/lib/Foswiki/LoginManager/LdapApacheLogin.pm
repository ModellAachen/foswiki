# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007-2012 Michael Daum http://michaeldaumconsulting.com
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
package Foswiki::LoginManager::LdapApacheLogin;

=begin TML

---+ Foswiki::LoginManager::LdapApacheLogin

This is a simple login manager to be used when authentication is done
using apache's LDAP capabilities. In addition to the normal 
<a href="%SCRIPTURLPATH{"view"}%/%SYSTEMWEB%/PerlDoc?module=Foswiki::LoginManager::ApacheLogin">Foswiki::LoginManager::ApacheLogin</a>
manager, this one adds a check to make sure the user is already cached
in <nop>LdapContrib, and that its name matches onto the configured naming conventions.

=cut

use strict;
use Assert ();
use Foswiki::LoginManager::ApacheLogin ();
use Foswiki::Contrib::LdapContrib ();
use Foswiki::Sandbox ();

@Foswiki::LoginManager::LdapApacheLogin::ISA = qw( Foswiki::LoginManager::ApacheLogin );

=begin TML

---++ ClassMethod new($session)

Construct the <nop>LdapApacheLogin object

=cut

sub new {
  my ($class, $session) = @_;

  my $this = bless( $class->SUPER::new($session), $class );

  $this->{ldap} = Foswiki::Contrib::LdapContrib::getLdapContrib($session);
  return $this;
}

=begin TML

---++ ObjectMethod loadSession()

Load the session, sanitize the login name and make sure its user information are already
cached.

=cut

sub loadSession {
  my $this = shift;

  my $authUser = $this->SUPER::loadSession(@_);

  # explicitly untaint it as this string comes from LDAP, and all strings
  # from LDAP are tainted, even if they come via mod_ldap
  $authUser = Foswiki::Sandbox::untaintUnchecked($authUser);

  # process authUser login name
  if (defined $authUser) {

    #print STDERR "before authUser=$authUser\n";

    $authUser =~ s/^\s+//o;
    $authUser =~ s/\s+$//o;
    $authUser = $this->{ldap}->fromUtf8($authUser);

    $authUser = lc($authUser) if ( $this->{ldap}{caseSensitivity} eq 'off' ); # TODO
    $authUser = $this->{ldap}->normalizeLoginName($authUser) if $this->{ldap}{normalizeLoginName};

    #print STDERR "after authUser=$authUser\n";

    unless ($this->{ldap}{excludeMap}{$authUser}) {
      $this->{ldap}->checkCacheForLoginName($authUser);
    }
  }

  return $authUser;
}

1;
