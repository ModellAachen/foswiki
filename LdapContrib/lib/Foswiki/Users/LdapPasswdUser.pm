# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2012 Michael Daum http://michaeldaumconsulting.com
# Portions Copyright (C) 2006 Spanlink Communications
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

package Foswiki::Users::LdapPasswdUser;
use Foswiki::Users::Password;
our @ISA = qw( Foswiki::Users::Password );

use strict;

use Foswiki::Contrib::LdapContrib ();
use Foswiki::Plugins ();
use Foswiki::ListIterator ();

=pod

---+ Foswiki::Users::LdapPassdUser

Password manager that uses Net::LDAP to manage users and passwords.

Subclass of =Foswiki::Users::Password=.

This class does not grant any write access to the ldap server for security reasons. 
So you need to use your ldap tools to create user accounts.

Configuration: add the following variables to your <nop>LocalSite.cfg 
   * $Foswiki::cfg{Ldap}{server} = &lt;ldap-server uri>, defaults to localhost
   * $Foswiki::cfg{Ldap}{base} = &lt;base dn> subtree that holds the user accounts
     e.g. ou=people,dc=your,dc=domain,dc=com

=cut

=pod

---++ new($session) -> $ldapUser

Takes a session object, creates an LdapContrib object used to
delegate LDAP calls and returns a new Foswiki::User::LdapPasswd object

=cut

sub new {
  my ($class, $session) = @_;

  my $this = bless($class->SUPER::new( $session ), $class);
  $this->{ldap} = &Foswiki::Contrib::LdapContrib::getLdapContrib($session);

  my $secondaryImpl = $this->{ldap}->{secondaryPasswordManager};
  if ($secondaryImpl) {
    eval "use $secondaryImpl";
    die "Secondary Password Manager: $@" if $@;
    $this->{secondaryPasswordManager} = $secondaryImpl->new($session);
  }

  return $this;
}

=pod

---++ error() -> $errorMsg

return the last error during LDAP operations

=cut

sub error {
  my $this = shift;
  $this->{error} = $this->{ldap}->getError();
  return return $this->{error};
}

=pod

---++ writeDebug($msg) 

Static method to write a debug messages. 

=cut

sub writeDebug {
  print STDERR "- LdapPasswdUser - $_[0]\n" if $Foswiki::cfg{Ldap}{Debug};
}


=pod 

---++ fetchPass($login) -> $passwd

this method is used most of the time to detect if a given
login user is known to the database. the concrete (encrypted) password 
is of no interest: so better use userExists() for that

=cut

sub fetchPass {
  my ($this, $login) = @_;

  #writeDebug("called fetchPass($login)");

  # try to find out if foswiki calls this functio as part
  # of an existence check. fetching the actual password of
  # a user is more expensive than just checking the existence
  # the _user_exists context is set in LdapUserMapping::userExists()
  # when backing off to native groups anyway
  return $this->userExists($login) 
    if $this->{session}->inContext("_user_exists");

  # foswiki tends to feed all sorts of strings to fetchPass,
  # let's try to filter out some of the siliest cases
  if ($this->{session}->{users}->isGroup($login)) {
    return undef;
  }

  my $passwd = $this->{passwords}{$login};

  unless (defined $passwd) {
    my $entry = $this->{ldap}->getAccount($login); # expensive

    $passwd = $entry->get_value('userPassword') if $entry;
    $passwd = $this->{secondaryPasswordManager}->fetchPass($login)
      if !defined($passwd) && $this->{secondaryPasswordManager};

    $passwd = 0 unless defined $passwd;
    $this->{passwords}{$login} = $passwd;
  }

  return $passwd;
}

=pod 

---++ userExists($name) -> $boolean

returns true if the login or wikiname exists in the database;
that's performing better than fetching the password and then
see what comes out of this

=cut

sub userExists {
  my ($this, $name) = @_;

  #writeDebug("called userExists($name)");

  return 1 if 
    $this->{ldap}->getWikiNameOfLogin($name) || 
    $this->{ldap}->getLoginOfWikiName($name);

  if ($this->{secondaryPasswordManager}) {
    #writeDebug("asking secondary password manager");
    my $passwd = $this->{secondaryPasswordManager}->fetchPass($name);
    return 1 if defined $passwd;
  }
  #writeDebug("$name is unknown");

  return 0;
}


=pod 

---++ checkPassword($login, $password) -> $boolean

check passwd by binding to the ldap server

=cut

sub checkPassword {
  my ($this, $login, $passU) = @_;

  writeDebug("called checkPassword($login, passU)");

  # guest has no password
  return 1 if $login eq $Foswiki::cfg{DefaultUserWikiName};

  # get user record
  my $dn = $this->{ldap}->getDnOfLogin($login);
  writeDebug("dn not found") unless $dn;

  return $this->{ldap}->connect($dn, $passU)
    if $dn;

  return $this->{secondaryPasswordManager}->checkPassword($login, $passU)
    if $this->{secondaryPasswordManager};

  return 0;
}

=pod 

---++ readOnly() -> $boolean

we can change passwords, so return false

=cut

sub readOnly {
  my $this = shift;

  return $this->{secondaryPasswordManager}->readOnly()
    if $this->{secondaryPasswordManager};
}

=pod

---++ isManagingEmails() -> $boolean

we are managing emails, but don't allow setting emails. alas the
core does not distinguish this case, e.g. by using readOnly()

=cut

sub isManagingEmails {
  return 1;
}

=pod 

---++ getEmails($login) -> @emails

emails might be stored in the ldap account as well if
the record is of type possixAccount and inetOrgPerson.
if this is not the case we fallback to twiki's default behavior

=cut

sub getEmails {
  my ($this, $login) = @_;

  # guest has no email addrs
  return () if $login eq $Foswiki::cfg{DefaultUserWikiName};

  # get emails from ldap
  my $emails = $this->{ldap}->getEmails($login);

  return @{$emails} if $emails;

  return $this->{secondaryPasswordManager}->getEmails($login)
    if $this->{secondaryPasswordManager};

  return ();
}

=pod 

---++ finish()

Complete processing after the client's HTTP request has been responded.
i.e. destroy the ldap object.

=cut

sub finish {
  my $this = shift;

  $this->{ldap}->finish() if $this->{ldap};
  undef $this->{ldap};
  undef $this->{passwords};
  $this->{secondaryPasswordManager}->finish(@_)
    if $this->{secondaryPasswordManager};
}

=pod

---++ removeUser( $user ) -> $boolean

LDAP users can't be removed from within the engine.
So this will call the deleteUser interface of the secondary
password manager only

Returns 1 on success, undef on failure.

=cut

sub removeUser {
  my $this = shift;

  return $this->{secondaryPasswordManager}->removeUser(@_)
    if $this->{secondaryPasswordManager};

  $this->{error} = 'System does not support removing users';
  return undef;
}

=pod

---++ passwd( $user, $newPassword, $newPassword ) -> $boolean

TODO: API missmatch

This method can only change the LDAP password. It can not
add the user to the LDAP directory. To change the password the
old password must always be correct. There's no mode to force the
change irrespective of the existing password.

In any other case the secondary password manager gets the job.

=cut

sub passwd {
  my ( $this, $user, $newPassword, $oldPassword ) = @_;

  if ($this->{ldap}->{allowChangePassword} && defined($oldPassword) && $oldPassword ne '1') {
    if ($this->{ldap}->getDnOfLogin($user)) {
      return 1 if $this->{ldap}->changePassword($user, $newPassword, $oldPassword);
      $this->error();
      return undef;
    }
  }

  if ($this->{secondaryPasswordManager}) {
    my $result = $this->{secondaryPasswordManager}->passwd($user, $newPassword, $oldPassword);
    unless ($result) {
      $this->{error} = $this->{secondaryPasswordManager}->{error};
    }
    return $result;
  }

  $this->{error} = 'System does not support adding a user or forcing a  password change';
  return undef;
}

=pod

---++ encrypt( $user, $passwordU, $fresh ) -> $passwordE

LDAP can't encrypt passwords. But maybe the secondary
password manager can.


=cut

sub encrypt {
  my $this = shift;

  return $this->{secondaryPasswordManager}->encrypt(@_)
    if $this->{secondaryPasswordManager};
  
  $this->{error} = 'System does not support encrypting passwords';
  return '';
}

=pod

---++ setPassword( $login, $newPassU, $oldPassU ) -> $boolean

If the $oldPassU matches matches the user's password, then it will
replace it with $newPassU.

If $oldPassU is not correct and not 1, will return 0.

If $oldPassU is 1, will force the change irrespective of
the existing password, adding the user if necessary.

Otherwise returns 1 on success, undef on failure.

=cut

sub setPassword {
  my ($this, $login, $newUserPassword, $oldUserPassword) = @_;

  my $isOk = $this->{ldap}->changePassword($login, $newUserPassword, $oldUserPassword);

  if ($isOk) {
    $this->{error} = undef;
    return 1;
  } 

  return $this->{secondaryPasswordManager}->setPassword($login, $newUserPassword, $oldUserPassword)
    if $this->{secondaryPasswordManager};

  $this->error();
  return undef;
}

=pod

---++ setEmails($user, @emails)

Set the email address(es) for the given username.
The engine can't set the email stored in LDAP. But may be the secondary
password manager can.

=cut

sub setEmails {
  my $this = shift;

  return $this->{secondaryPasswordManager}->setEmails(@_)
    if $this->{secondaryPasswordManager};
  
  $this->{error} = 'System does not support setting the email adress';
  return '';
}

=pod

---++ findUserByEmail( $email ) -> \@users
   * =$email= - email address to look up
Return a list of user objects for the users that have this email registered
with the password manager. This will concatenate the result list of the
LDAP manager with the secondary password manager

=cut

sub findUserByEmail {
  my ($this, $email) = @_;

  my $users = $this->{ldap}->getLoginOfEmail($email);
  return $users unless $this->{secondaryPasswordManager};

  # add those from the secondary
  my $moreUsers = $this->{secondaryPasswordManager}->findUserByEmail($email);

  push @$users, @{$moreUsers} if $moreUsers;

  # nothing found
  return undef unless $users;

  # remove duplicates
  my %users = map {$_ => $_} @$users;
  my @users = values %users;
  return \@users;
}

=pod 

---++ canFetchUsers() -> boolean

returns true, as we can fetch users

=cut

sub canFetchUsers {
  return 1;
}

=pod 

---++ fetchUsers() -> new Foswiki::ListIterator(\@users)

returns a Foswiki::ListIterator of loginnames 

=cut

sub fetchUsers {
  my $this = shift;

  my $users = $this->{ldap}->getAllLoginNames();
  #print STDERR "fetchUsers=".join(',', @$users)."\n";
  return new Foswiki::ListIterator($users);
}


1;
