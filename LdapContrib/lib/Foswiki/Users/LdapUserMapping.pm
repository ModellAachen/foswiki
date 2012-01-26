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

package Foswiki::Users::LdapUserMapping;

use strict;
use Foswiki::Contrib::LdapContrib ();
use Foswiki::ListIterator ();

use Foswiki::Users::TopicUserMapping;
our @ISA = qw( Foswiki::Users::TopicUserMapping );

use vars qw($isLoadedMapping);

=pod

---+ Foswiki::Users::LdapUserMapping

This class allows to use user names and groups stored in an LDAP
database inside Foswiki in a transparent way. This replaces Foswiki's
native way to represent users and groups using topics with
according LDAP records.

=cut

=pod 

---++ new($session) -> $ldapUserMapping

create a new Foswiki::Users::LdapUserMapping object and constructs an <nop>LdapContrib
object to delegate LDAP services to.

=cut

sub new {
  my ($class, $session) = @_;

  my $this = bless($class->SUPER::new( $session ), $class);
  $this->{ldap} = &Foswiki::Contrib::LdapContrib::getLdapContrib($session);
  $this->{eachGroupMember} = {};

  return $this;
}


=pod

---++ finish()

Complete processing after the client's HTTP request has been responded
to. I.e. it disconnects the LDAP database connection.

=cut

sub finish {
  my $this = shift;
    
  $this->{ldap}->finish() if $this->{ldap};
  undef $this->{ldap};
  undef $this->{eachGroupMember};
  $this->SUPER::finish();
}

=pod

---++ writeDebug($msg) 

Static method to write a debug messages. 

=cut

sub writeDebug {
  print STDERR "- LdapUserMapping - $_[0]\n" if $Foswiki::cfg{Ldap}{Debug};
}


=pod

---++ addUser ($login, $wikiname, $password, $emails) -> $cUID

overrides and thus disables the SUPER method

=cut

sub addUser {
  my $this = shift;

  return $this->SUPER::addUser(@_)
    if $this->{ldap}{nativeGroupsBackoff};

  return '';
}

=begin 

---++ getLoginName ($cUID) -> $login

Converts an internal cUID to that user's login
(undef on failure)

=cut

sub getLoginName {
  my ($this, $cUID) = @_;

  my $login = $cUID;

  # Remove the mapping id in case this is a subclass
  $login =~ s/$this->{mapping_id}// if $this->{mapping_id};

  use bytes;
  # Reverse the encoding used to generate cUIDs in login2cUID
  # use bytes to ignore character encoding
  $login =~ s/_([0-9a-f][0-9a-f])/chr(hex($1))/gei;
  no bytes;

  return undef unless $this->{ldap}->getWikiNameOfLogin($login);
  return undef unless ($cUID eq $this->login2cUID($login));

  return $login;
}


=pod

---++ getWikiName ($cUID) -> wikiname

Maps a canonical user name to a wikiname

=cut

sub getWikiName {
  my ($this, $cUID) = @_;

  #writeDebug("called LdapUserMapping::getWikiName($cUID)");
    
  my $loginName = $this->getLoginName($cUID);
  return undef unless $loginName;

  return $loginName if $this->isGroup($loginName);

  my $wikiName;

  unless ($this->{ldap}{excludeMap}{$loginName}) {
    $wikiName = $this->{ldap}->getWikiNameOfLogin($loginName); 
    $wikiName = undef if !$wikiName || $wikiName eq '_unknown_';
  }

  unless ($wikiName) {

    # fallback
    #writeDebug("asking SUPER");
    $wikiName = $this->SUPER::getWikiName($cUID);
  }

  # fallback fallback
  $wikiName ||= $loginName;


  #writeDebug("returning $wikiName");
  return $wikiName; 
}

=pod 

---++ getEmails($cUID) -> @emails

emails might be stored in the ldap account as well if
the record is of type possixAccount and inetOrgPerson.
if this is not the case we fallback to the default behavior

=cut

sub getEmails {
  my ($this, $user, $emails) = @_;

  $emails ||= {};

  return values %$emails if $emails->{$user};

  if ($this->isGroup($user)) {
    my $it = $this->eachGroupMember($user);
    while ($it->hasNext()) {
      $this->getEmails($it->next(), $emails);
    }
  } else {
    # get emails from the password manager
    my $login = $this->getLoginName($user);
    if ($login) {
      foreach ($this->{passwords}->getEmails($login, $emails)) {
        $$emails{$user} = $_;
      }
    }
  }

  return values %$emails;
}


=pod

---++ userExists($cUID) -> $boolean

Determines if the user already exists or not. 

=cut

sub userExists {
  my ($this, $cUID) = @_;

  my $loginName = $this->getLoginName($cUID);
  return 0 unless $loginName;

  my $wikiName = $this->{ldap}->getWikiNameOfLogin($loginName);

  return 1 if $wikiName;

  my $result = 0;
  if ($this->{ldap}{nativeGroupsBackoff}) {
    # see LdapPasswdUser
    $this->{session}->enterContext("_user_exists");
    $result = $this->SUPER::userExists($cUID);
    $this->{session}->leaveContext("_user_exists");
  }

  return $result;
}

=pod

---++ eachUser () -> listIterator of cUIDs

returns a list iterator for all known users

=cut

sub eachUser {
  my $this = shift;

  my @allCUIDs = ();

  foreach my $login (@{$this->{ldap}->getAllLoginNames()}) {
    my $cUID = $this->login2cUID($login, 1);
    push @allCUIDs, $cUID if $cUID;
  }

  my $ldapIter = new Foswiki::ListIterator(\@allCUIDs);
  return $ldapIter unless $this->{ldap}{nativeGroupsBackoff};

  my $backOffIter = $this->SUPER::eachUser(@_);
  my @list = ($ldapIter, $backOffIter);


  return new Foswiki::AggregateIterator(\@list, 1);
}

=pod

---++ eachGroup () -> listIterator of groupnames

returns a list iterator for all known groups

=cut

sub eachGroup {
  my ($this) = @_;

  my @groups = $this->getListOfGroups();

  return new Foswiki::ListIterator(\@groups );
}

=pod

---++ getListOfGroups( ) -> @listOfUserObjects

Get a list of groups defined in the LDAP database. If 
=nativeGroupsBackoff= is defined the set of LDAP and native groups will
merged whereas LDAP groups have precedence in case of a name clash.

=cut

sub getListOfGroups {
  my $this = shift;

  #writeDebug("called getListOfGroups()");

  my %groups;
  
  return @{$this->SUPER::_getListOfGroups()}
    unless $this->{ldap}{mapGroups};

  if ($this->{ldap}{nativeGroupsBackoff}) {
    %groups = map { $_ => 1 } @{$this->SUPER::_getListOfGroups()};
  } else {
    %groups = ();
  }
  my $groupNames = $this->{ldap}->getGroupNames();
  if ($groupNames) {
    foreach my $groupName (@$groupNames) {
      $groups{$groupName} = 1;
    }
  }
  #writeDebug("got " . (scalar keys %groups) . " overall groups=".join(',',keys %groups));
  return keys %groups;
}


=pod

---++ eachGroupMember ($groupName) ->  listIterator of cUIDs

returns a list iterator for all groups members

=cut

sub eachGroupMember {
  my ($this, $groupName, $options) = @_;

  writeDebug("called eachGroupMember($groupName)");
  return $this->SUPER::eachGroupMember($groupName, $options)
    unless $this->{ldap}{mapGroups};

  my $expand = $options->{expand};
  $expand = 1 unless defined $expand;

  my $result = $this->{"eachGroupMember::$expand"}{$groupName};

  unless (defined $result) {
    $result = [];

    # prevent deep recursion
    $this->{_seen} ||= {};

    unless ($this->{_seen}{$groupName}) {
      $this->{_seen}{$groupName} = 1;

      my $members = $this->{ldap}->getGroupMembers($groupName) || [];

      unless (@$members) {

        # fallback to native groups,
        # try also to find the SuperAdminGroup
        if ($this->{ldap}{nativeGroupsBackoff} || $groupName eq $Foswiki::cfg{SuperAdminGroup}) {

          #writeDebug("asking SUPER");
          my $listResult = $this->SUPER::eachGroupMember($groupName, $options);
          $result = [ $listResult->all ] if $listResult && $listResult->{list};    # SMELL: breaks encapsulation of list iterator, but hey
        }
      } else {
        foreach my $login (@$members) {
          if ($expand && $this->isGroup($login)) {
            my $it = $this->eachGroupMember($login, $options);
            while ($it->hasNext()) {
              push @$result, $it->next;
            }
          } else {
            my $cUID = $this->login2cUID($login);
            push @$result, $cUID if $cUID;
          }
        }
      }
    }

    $this->{_seen} = {};
    $this->{"eachGroupMember::$expand"}{$groupName} = $result;
  }

  return new Foswiki::ListIterator($result);
}

=pod

---++ eachMembership ($cUID) -> listIterator of groups this user is in

returns a list iterator for all groups a user is in.

=cut

sub eachMembership {
  my ($this, $cUID) = @_;

  my @groups = $this->getListOfGroups();

  my $it = new Foswiki::ListIterator( \@groups );
  $it->{filter} = sub {
    $this->isInGroup($cUID, $_[0]);
  };

  return $it;
}

=pod

---++ isGroup($user) -> $boolean

Establish if a user object refers to a user group or not.
This returns true for the <nop>SuperAdminGroup or
the known LDAP groups. Finally, if =nativeGroupsBackoff= 
is set the native mechanism are used to check if $user is 
a group

=cut

sub isGroup {
  my ($this, $user) = @_;

  return 0 unless $user;
  #writeDebug("called isGroup($user)");

  # may be called using a user object or a wikiName of a user
  my $wikiName = (ref $user)?$user->wikiName:$user;

  # special treatment for build-in groups
  return 1 if $wikiName eq $Foswiki::cfg{SuperAdminGroup};

  my $isGroup;

  if ($this->{ldap}{mapGroups}) {
    # ask LDAP
    $isGroup = $this->{ldap}->isGroup($wikiName);
  }

  # backoff if it does not know
  if (!defined($isGroup) && $this->{ldap}{nativeGroupsBackoff}) {
    $isGroup = $this->SUPER::isGroup($user) if ref $user;
    $isGroup = ($wikiName =~ /Group$/); 
  }

  return $isGroup;
}

=pod

---++ findUserByEmail( $email ) -> \@cUIDs
   * =$email= - email address to look up

Return a list of canonical user names for the users that have this email
registered with the password manager or the user mapping manager.

=cut

sub findUserByEmail {
  my ($this, $email) = @_;

  return $this->{ldap}->getLoginOfEmail($email);
}

=pod 

---++ findUserByWikiName ($wikiName) -> list of cUIDs associated with that wikiname

See baseclass for documentation

=cut

sub findUserByWikiName {
  my ($this, $wikiName) = @_;

  #writeDebug("called findUserByWikiName($wikiName)");
  my @users = ();

  if ($this->isGroup($wikiName)) {
    push @users, $wikiName;
  } else {
    my $loginName = $this->{ldap}->getLoginOfWikiName($wikiName) || $wikiName;
    my $cUID = $this->login2cUID($loginName, 1);
    push @users, $cUID if $cUID;
  }

  #writeDebug("found ".join(', ', @users));

  return \@users;
}

=pod

---++ handlesUser($cUID, $login, $wikiName) -> $boolean

Called by the Foswiki::Users object to determine which loaded mapping
to use for a given user.

The user can be identified by any of $cUID, $login or $wikiName. Any of
these parameters may be undef, and they should be tested in order; cUID
first, then login, then wikiName. 

=cut

sub handlesUser {
  my ($this, $cUID, $login, $wikiName) = @_;

  if ($this->{ldap}{mapGroups}) {
    # ask LDAP
    return 1 if $login && $this->{ldap}->isGroup($login);
    return 1 if $wikiName && $this->{ldap}->isGroup($wikiName);
  }
  return 1 if $login && $this->{ldap}->getWikiNameOfLogin($login);
  return 1 if $wikiName && $this->{ldap}->getLoginOfWikiName($wikiName);

  $cUID = $this->login2cUID($login) if !$cUID && $login;
  return 1 if defined $cUID && $this->userExists($cUID);

  return $this->SUPER::handlesUser($cUID, $login, $wikiName);
}

=pod

---++ login2cUID($loginName, $dontcheck) -> $cUID

Convert a login name to the corresponding canonical user name. The
canonical name can be any string of 7-bit alphanumeric and underscore
characters, and must correspond 1:1 to the login name.
(undef on failure)

(if dontcheck is true, return a cUID for a nonexistant user too.
This is used for registration)

=cut

sub login2cUID {
  my ($this, $name, $dontcheck) = @_;

  #writeDebug("called login2cUID($name)");

  my $loginName = $this->{ldap}->getLoginOfWikiName($name);
  $name = $loginName if defined $loginName; # called with a wikiname

  my $cUID = $this->{mapping_id}.Foswiki::Users::mapLogin2cUID($name);

  unless ($dontcheck) {
    my $wikiName = $this->{ldap}->getWikiNameOfLogin($name);
    return undef unless $wikiName || $loginName;
  }

  return $cUID;
}

=pod

---++ groupAllowsChange($group, $cuid) -> boolean

normally, ldap-groups are read-only as they are maintained
using ldap-specific tools.

this method only returns 1 if the group is a topic-based group

=cut

sub groupAllowsChange {
  my ($this, $group, $cuid) = @_;

  my ($groupWeb, $groupName) = 
    $this->{session}->normalizeWebTopicName($Foswiki::cfg{UsersWebName}, $group);

  return $this->SUPER::groupAllowsChange($group, $cuid)
    if $this->{session}->topicExists($groupWeb, $groupName);

  return 0;
}



1;
