# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007 Sven Dowideit, SvenDowideit@distributedINFORMATION.com
# Copyright (C) 2005-2008 Timothe Litt, litt@acm.org
# and Foswiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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

=begin TML

---+ package Foswiki::Users::X509UserMapping

The User mapping is the process by which Foswiki maps from a username (a login name)
to a wikiname and back. It is also where groups are defined.

By default Foswiki maintains user topics and group topics in the %USERSWEB% that
define users and group. These topics are
   * !WikiUsers - stores a mapping from usernames to Foswiki names
   * !WikiName - for each user, stores info about the user
   * !GroupNameGroup - for each group, a topic ending with "Group" stores a list of users who are part of that group.

This is a subclass of UserMapping that implements X.509 certificate-based users.
Groups are handled by topics.

This could ALMOST be a subclass of Foswiki::Users::TopicUserMapping, but it gets a bit too messy.

=cut

package Foswiki::Users::X509UserMapping;
use Foswiki::UserMapping;
our @ISA = qw( Foswiki::UserMapping );

use strict;
use Assert;
use Error qw( :try );

use Foswiki::Users::X509UserMapping::Cert;

#use Monitor;
#Monitor::MonitorMethod('Foswiki::Users::X509UserMapping');

=begin TML

---++ ClassMethod new ($session, $impl)

Constructs a new user mapping handler of this type, referring to $session
for any required Foswiki services.

=cut

sub new {
    my ( $class, $session ) = @_;

    if ( $Foswiki::cfg{PasswordManager} ne 'Foswiki::Users::X509PasswdUser' ) {
        die
"X509UserMapping requires X509PasswdUser, not $Foswiki::cfg{PasswordManager}.  Please fix in configure.";
    }

    my $this = $class->SUPER::new( $session, 'X509' );

    my $implPasswordManager = $Foswiki::cfg{PasswordManager};
    eval "require $implPasswordManager";
    die $@ if $@;
    $this->{passwords} = $implPasswordManager->new($session);

#if password manager says sorry, we're read only today
#'none' is a special case, as it means we're not actually using the password manager for
# registration.
    if ( $this->{passwords}->readOnly() ) {
        $session->writeWarning(
'X509UserMapping has TURNED OFF EnableNewUserRegistration, because the password file is read only.'
        );
        $Foswiki::cfg{Register}{EnableNewUserRegistration} = 0;
    }

    # Certificates aren't login names in the sense of things users can enter.
    # But some of the Foswiki infrastructure checks for this before calling us.

    if ( !$Foswiki::cfg{Register}{AllowLoginName} ) {
        $session->writeWarning(
'X509UserMapping has TURNED ON AllowLoginName, because it seems to be required for certificates.'
        );
        $Foswiki::cfg{Register}{AllowLoginName} = 1;
    }

    #SMELL: and this is a second user object
    #TODO: combine with the one in Foswiki::Users
    #$this->{U2L} = {};
    $this->{L2U}             = {};
    $this->{U2W}             = {};
    $this->{W2U}             = {};
    $this->{eachGroupMember} = {};

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;

    $this->{passwords}->finish() if $this->{passwords};
    undef $this->{L2U};
    undef $this->{U2W};
    undef $this->{W2U};
    undef $this->{passwords};
    undef $this->{eachGroupMember};
    $this->SUPER::finish();
}

=begin TML

---++ ObjectMethod supportsRegistration () -> false
return 1 if the UserMapper supports registration (ie can create new users)

=cut

sub supportsRegistration {
    return 1;
}

=begin TML

---++ ObjectMethod handlesUser ( $cUID, $login, $wikiname) -> $boolean

Called by the Foswiki::Users object to determine which loaded mapping
to use for a given user.

The user can be identified by any of $cUID, $login or $wikiname. Any of
these parameters may be undef, and they should be tested in order; cUID
first, then login, then wikiname. 

=cut

sub handlesUser {
    my ( $this, $cUID, $login, $wikiname ) = @_;

    return 1 if ( defined $cUID && $cUID =~ /^($this->{mapping_id})/ );

    # Check the login id to see if we know it
    return 1 if ( $login && $this->_userReallyExists($login) );

    # Or the wiki name
    if ($wikiname) {
        _loadMapping($this);
        return 1 if defined $this->{W2U}->{$wikiname};
    }

    return 0;
}

=begin TML

---++ ObjectMethod login2cUID ($login, $dontcheck) -> $cUID

Convert a login name to the corresponding canonical user name. The
canonical name can be any string of 7-bit alphanumeric and underscore
characters, and must correspond 1:1 to the login name.
(undef on failure)

(if dontcheck is true, return a cUID for a nonexistant user too.
This is used for registration)

=cut

sub login2cUID {
    my ( $this, $login, $dontcheck ) = @_;

    unless ($dontcheck) {
        return undef unless ( _userReallyExists( $this, $login ) );
    }

    return $this->{mapping_id} . Foswiki::Users::mapLogin2cUID($login);
}

=begin TML

---++ ObjectMethod getLoginName ($cUID) -> login

Converts an internal cUID to that user\'s login
(undef on failure)

=cut

sub getLoginName {
    my ( $this, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;

    #can't call userExists - its recursive
    #return unless (userExists($this, $user));

    # Remove the mapping id
    my @calls = caller(2);
    @calls = @calls[ 0 .. 4 ];
    die "Not X509's cUID |$cUID|" . join( ' ', @calls )
      unless ( $cUID =~ s/^$this->{mapping_id}// );

    use bytes;

    # Reverse the encoding used to generate cUIDs in login2cUID
    # use bytes to ignore character encoding
    $cUID =~ s/_([0-9a-f][0-9a-f])/chr(hex($1))/gei;
    no bytes;

    return undef unless _userReallyExists( $this, $cUID );

    return $cUID;
}

# test if the login is in the the password file
sub _userReallyExists {
    my ( $this, $login ) = @_;

    if ( $this->{passwords}->canFetchUsers() ) {

        my $pass = $this->{passwords}->fetchPass($login);
        return undef unless ( defined($pass) );
        return undef
          if ( "$pass" eq "0" ); # login invalid... (SMELL: We got a null login?
        return 1;
    }
    else {

        # passwd==none case generally assumes any login given exists...
        die "X509PasswdUser doesn't support FetchUsers";
        return 1;
    }

    return 0;
}

=begin TML

---++ ObjectMethod addUser ($login, $wikiname, $password, $emails) -> $cUID

throws an Error::Simple 

Add a user to the persistant mapping that maps from usernames to wikinames
and vice-versa. Names must be acceptable to $Foswiki::cfg{NameFilter}
$login must *always* be specified. $wikiname may be undef, in which case
the user mapper should make one up.
This function must return a *canonical user id* that it uses to uniquely
identify the user. This can be the login name, or the wikiname if they
are all guaranteed unigue, or some other string consisting only of 7-bit
alphanumerics and underscores.
if you fail to create a new user (for eg your Mapper has read only access), 
            throw Error::Simple(
               'Failed to add user: '.$ph->error());

=cut

sub addUser {
    my ( $this, $login, $wikiname, $password, $emails ) = @_;

    ASSERT($login) if DEBUG;

    $password =
      "xxj31ZMTZzkVA";    # Required for apache certificate authentication.

    $wikiname = ''
      if ( $Foswiki::cfg{Plugins}{X509UserPlugin}
        {RequireWikinameFromCertificate} );
    $wikiname = $this->wikinameFromDN($login) unless ($wikiname);

    if ( $this->{passwords}->fetchPass($login) ) {

   # They exist; their password must match
   #      unless( $this->{passwords}->checkPassword( $login, $password )) {
   #          throw Error::Simple(
   #              'New password did not match existing password for this user');
   #      }
   # User exists, and the password was good.  But why are we here?
    }
    else {

        # add a new user No need to generate a password.

        unless (
            $this->{passwords}->addUser( $login, $wikiname, $password, $emails )
          )
        {

           #print STDERR "\n Failed to add user:  ".$this->{passwords}->error();
            throw Error::Simple(
                'Failed to add user: ' . $this->{passwords}->error() );
        }
    }

    # add to the mapping caches
    my $user = _cacheUser( $this, $wikiname, $login );
    ASSERT($user) if DEBUG;

    if ( $Foswiki::cfg{Plugins}{X509UserPlugin}{RegisterInUsersTopic} ) {
        my $store = $this->{session}->{store};
        my ( $meta, $text );

        if (
            $store->topicExists(
                $Foswiki::cfg{UsersWebName},
                $Foswiki::cfg{UsersTopicName}
            )
          )
        {
            ( $meta, $text ) = $store->readTopic(
                undef,
                $Foswiki::cfg{UsersWebName},
                $Foswiki::cfg{UsersTopicName}
            );
        }
        else {
            ( $meta, $text ) =
              $store->readTopic( undef, $Foswiki::cfg{SystemWebName},
                'WikiUsersTemplate' );
        }

        my $result = '';
        my $entry  = "   * $wikiname - ";

        # X509 login names are cybercrud, shouldn't publish
        $entry .= $login . " - "
          if ( $login
            && $Foswiki::cfg{Plugins}{X509UserPlugin}
            {RegisterUsersWithLoginName} );

        require Foswiki::Time;
        my $today =
          Foswiki::Time::formatTime( time(), $Foswiki::cfg{DefaultDateFormat},
            'gmtime' );

        # add name alphabetically to list

 # insidelist is used to see if we are before the first record or after the last
 # 0 before, 1 inside, 2 after
        my $insidelist = 0;
        foreach my $line ( split( /\r?\n/, $text ) ) {

          # TODO: I18N fix here once basic auth problem with 8-bit user names is
          # solved
            if ($entry) {
                my ( $web, $name, $odate ) = ( '', '', '' );
                if ( $line =~
/^\s+\*\s($Foswiki::regex{webNameRegex}\.)?($Foswiki::regex{wikiWordRegex})\s*(?:-\s*\w+\s*)?-\s*(.*)/
                  )
                {
                    $web        = $1 || $Foswiki::cfg{UsersWebName};
                    $name       = $2;
                    $odate      = $3;
                    $insidelist = 1;
                }
                elsif ( $line =~ /^\s+\*\s([A-Z]) - / ) {

                    #	* A - <a name="A">- - - -</a>^M
                    $name       = $1;
                    $insidelist = 1;
                }
                elsif ( $insidelist == 1 ) {

              # After last entry we have a blank line or some comment
              # We assume no blank lines inside the list of users
              # We cannot look for last after Z because Z is not the last letter
              # in all alphabets
                    $insidelist = 2;
                    $name       = '';
                }
                if ( ( $name && ( $wikiname le $name ) ) || $insidelist == 2 ) {

                    # found alphabetical position or last record
                    if ( $wikiname eq $name ) {

                     # adjusting existing user - keep original registration date
                        $entry .= $odate;
                    }
                    else {
                        $entry .= $today . "\n" . $line;
                    }

                    # don't adjust if unchanged
                    return $user if ( $entry eq $line );
                    $line  = $entry;
                    $entry = '';
                }
            }

            $result .= $line . "\n";
        }
        if ($entry) {

            # brand new file - add to end
            $result .= "$entry$today\n";
        }

        try {
            $store->saveTopic(

                # SMELL: why is this Admin and not the RegoAgent??
                $this->{session}->{users}
                  ->getCanonicalUserID( $Foswiki::cfg{AdminUserLogin} ),
                $Foswiki::cfg{UsersWebName},
                $Foswiki::cfg{UsersTopicName},
                $result, $meta
            );
        }
        catch Error::Simple with {

            # Failed to add user; must remove them from the password system too,
            # otherwise their next registration attempt will be blocked
            my $e = shift;
            $this->{passwords}->removeUser($login);
            throw $e;
        };
    }

#can't call setEmails here - user may be in the process of being registered
#TODO; when registration is moved into the mapping, setEmails will happen after the createUserTOpic
#$this->setEmails( $user, $emails );

    return $user;
}

=pod

Compute a suggested/mandatory wikiname from a certificate's DN.

Certificate authorities vary greatly in how they format a DN.

While this code isn't infinitely flexible, it does allow the Foswiki
administrator to specify how to derive a wikiname from their 
certificates' DNs.  

{X509UserPlugin}{Cert2Wiki} specifies the algorithm as a mapping string.  

The mapping string is parsed into commands to fetch and format elements
of the DN.  The string is applied to the DN iteratively.

Each pass applies all the commands specified for that pass.  If the resulting
Wikiname is unique, it stops.  If not, it tries again, adding the commands for
the next pass.  If the name still isn't unique after all commands have been tried,
a sequence number is added to the result of the last pass.

Commands in the mapping string are separated by spaces.  

Each command consists of optional flags, an element name, and an optional formatter.

The flags are:

^    will ucfirst each word in an element of the DN
n? - will add this element in the nth pass only if the generated name is
     ambiguous at the start of the pass.

The element name is as found in the DN.  If a name (such as OU) occurs more 
than once, the second occurance will be name.2; the third name.3 and so on.

The formatter is applied to the element as an s/// command.  The formatter 
must contain its delimiters, and any flags.  You can use this to extract or re-order
subfields of an element, or pretty much anything else that's necessary.  

After the formatter runs, any remaining spaces are removed (they're not valid in a wikiname).

A given element can be used as many or as few times as required.  If an element isn't present,
in a particular certificate, its formatter will not be applied.

If the formatter is sufficiently ugly, you may need to quote the whole command.

Some examples:

The default of "^CN" will give /CN=John a McSmith the wikiname JohnAMcSmith.

"^CN/(\w+), *(.*)/$2$1/" ^OU.2 would give /OU=megalith/OU=sales/CN=smith, jan
the wikiname "JanSmithSales"

If you want the first smith, jan  to be JanSmith, but subsequent to be JanSmithSales,
you might use: "^CN{(\w+),\s*(.*)}($2$1)" ^1?OU.2/^(\w\s*?)\s*(Department|Dept|Group|Team).*$/$1/i

Quotes are necessary only if you embed spaces in your regexp.  You can \-quote your quote - but
any other \ is sent as-is to the s-command.  

=cut

sub wikinameFromDN {
    my $this     = shift;
    my $certname = shift;

    my $wikiname;
    my $cert = Foswiki::Users::X509UserMapping::Cert->parseDN($certname);

# Keep the string parsing code in sync with lib/Foswiki/Configure/Checkers/Plugins/X509UserPlugin/System.pm

    my $mapstring = $Foswiki::Cfg{Plugins}{X509UserPlugin}{Cert2Wiki} || "^CN";
    my @mapstring;
    while ($mapstring) {
        if ( $mapstring =~ /^\s*\"((?>(?:(?>[^\"\\]+)|\\.)*))\"(.*)$/ ) {
            $mapstring = $2;
            my $ms = $1;
            $ms =~ s/\\\"/\"/g;
            push @mapstring, $ms;
        }
        elsif ( $mapstring =~ /^\s*\'((?>(?:(?>[^\'\\]+)|\\.)*))\'(.*)$/ ) {
            $mapstring = $2;
            my $ms = $1;
            $ms =~ s/\\\'/\'/g;
            push @mapstring, $ms;
        }
        elsif ( $mapstring =~ s/^\s*(\S+)\s*(.*)$/$2/ ) {
            push @mapstring, $1;
        }
        else { die "error parsing mapstring $mapstring"; }
    }

    my $maxpass = 0;
  PASS:
    for ( my $pass = 0 ; 1 ; $pass++ ) {
        $wikiname = '';

        foreach my $ele (@mapstring) {

            $ele =~ m/(\^)?(?:(\d+)?\?)?([A-Za-z]+(?:\.\d+)?)(.*)$/;
            my $eflags = $1 | '';
            my $pnum   = $2 || 0;
            my $ename  = $3;
            my $substr = $4;

            $maxpass = $pnum if ( $pnum > $maxpass );

            if ( $pass >= $pnum ) {
                my $ev = $cert->element($ename) || '';
                next unless ($ev);

                $ev = join( ' ', map { ucfirst $_ } ( split( /\s+/, $ev ) ) )
                  if ( $eflags =~ /\^/ );

                if ($substr) {
                    eval("\$ev =~ s$substr;");
                    die "X509 eval failed: $@" if ($@);
                }
                $ev = join( '', split( /\s+/, $ev ) );
                $wikiname .= $ev;
            }
        }
        last PASS
          if ( !$this->{passwords}->fetchPass($wikiname) || $pass >= $maxpass );
    }

    unless ( $wikiname && $wikiname =~ m/^$Foswiki::regex{wikiWordRegex}$/ ) {
        throw Error::Simple(
"X509: Unable to translate $certname to a wikiname: Produced $wikiname; check \{X509UserPlugin\}\{X509Cert2Wiki\}"
        );
    }

    if ( $this->{passwords}->fetchPass($wikiname) ) {
        my $seq = 1;
        while ( $this->{passwords}->fetchPass( $wikiname . $seq ) ) {
            $seq++;
        }
        $wikiname .= $seq;
    }

    return $wikiname;
}

=begin TML

---++ ObjectMethod removeUser( $cUID ) -> $boolean

Delete the users entry. Removes the user from the password
manager and user mapping manager. Does *not* remove their personal
topics, which may still be linked.

=cut

sub removeUser {
    my ( $this, $cUID ) = @_;

    my $ln = $this->getLoginName($cUID);

    my $result = $this->{passwords}->removeUser($ln);

    if ( exists $this->{U2W}->{$cUID} ) {
        delete $this->{W2U}->{ $this->{U2W}->{$cUID} };
        delete $this->{U2W}->{$cUID};
    }
    delete $this->{L2U}->{$ln};

    return $result;
}

=begin TML

---++ ObjectMethod getWikiName ($cUID) -> $wikiname

Map a canonical user name to a wikiname. If it fails to find a
WikiName, it will attempt to find a matching loginname, and use
an escaped version of that.
If there is no matching WikiName or LoginName, it returns undef.

=cut

sub getWikiName {
    my ( $this, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;
    ASSERT( $cUID =~ /^$this->{mapping_id}/ ) if DEBUG;

    my $wikiname;

    $this->_loadMapping();

    $wikiname = $this->{U2W}->{$cUID};

    unless ($wikiname) {
        $wikiname = $this->getLoginName($cUID);
        if ($wikiname) {

            # sanitise the generated WikiName
            $wikiname =~ s/$Foswiki::cfg{NameFilter}//go;
        }
    }
    return $wikiname;
}

=begin TML

---++ ObjectMethod userExists($cUID) -> $boolean

Determine if the user already exists or not. Whether a user exists
or not is determined by the password manager.

=cut

sub userExists {
    my ( $this, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;

    # Do this to avoid a password manager lookup
    return 1 if $cUID eq $this->{session}->{user};

    my $loginName = $this->getLoginName($cUID);
    return 0 unless defined($loginName);

    return 1 if ( $loginName eq $Foswiki::cfg{DefaultUserLogin} );

    # Foswiki allows *groups* to log in
    return 1 if ( $this->isGroup($loginName) );

    # Look them up in the password manager (can be slow).
    return 1 if ( $this->{passwords}->fetchPass($loginName) );

#    unless ( $this->{passwords}->canFetchUsers() ) {
#        if (Foswiki::Func::topicExists($Foswiki::cfg{UsersWebName}, $loginName)) {
#            return 1;
#        }
#    }

    return 0;
}

=begin TML

---++ ObjectMethod eachUser () -> Foswiki::ListIterator of cUIDs

See baseclass for documentation

=cut

sub eachUser {
    my ($this) = @_;

    _loadMapping($this);
    my @list = keys( %{ $this->{U2W} } );
    require Foswiki::ListIterator;
    my $iter = new Foswiki::ListIterator( \@list );
    $iter->{filter} = sub {

        # don't claim users that are handled by the basemapping
        my $cUID     = $_[0] || '';
        my $login    = $this->{session}->{users}->getLoginName($cUID);
        my $wikiname = $this->{session}->{users}->getWikiName($cUID);

        #print STDERR "**** $cUID  $login  $wikiname \n";
        require Foswiki::Plugins;
        return !( $Foswiki::Plugins::SESSION->{users}->{basemapping}
            ->handlesUser( undef, $login, $wikiname ) );
    };
    return $iter;
}

my %expanding;

=begin TML

---++ ObjectMethod eachGroupMember ($group) ->  listIterator of cUIDs

See baseclass for documentation

=cut

sub eachGroupMember {
    my $this  = shift;
    my $group = shift;

    return new Foswiki::ListIterator( $this->{eachGroupMember}->{$group} )
      if ( defined( $this->{eachGroupMember}->{$group} ) );

    my $store = $this->{session}->{store};
    my $users = $this->{session}->{users};

    my $members = [];

    if (  !$expanding{$group}
        && $store->topicExists( $Foswiki::cfg{UsersWebName}, $group ) )
    {
        $expanding{$group} = 1;
        my $text = $store->readTopicRaw( undef, $Foswiki::cfg{UsersWebName},
            $group, undef );

        foreach ( split( /\r?\n/, $text ) ) {
            if (/$Foswiki::regex{setRegex}GROUP\s*=\s*(.+)$/) {
                next unless ( $1 eq 'Set' );

                # Note: if there are multiple GROUP assignments in the
                # topic, only the last will be taken.
                my $f = $2;
                $members = _expandUserList( $this, $f );
            }
        }
        delete $expanding{$group};
    }
    $this->{eachGroupMember}->{$group} = $members;

    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( $this->{eachGroupMember}->{$group} );
}

=begin TML

---++ ObjectMethod isGroup ($user) -> boolean

See baseclass for documentation

=cut

sub isGroup {
    my ( $this, $user ) = @_;

    # Groups have the same username as wikiname as canonical name
    return 1 if $user eq $Foswiki::cfg{SuperAdminGroup};

    return $user =~ /Group$/;
}

=begin TML

---++ ObjectMethod eachGroup () -> ListIterator of groupnames

See baseclass for documentation

=cut

sub eachGroup {
    my ($this) = @_;
    _getListOfGroups($this);
    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@{ $this->{groupsList} } );
}

=begin TML

---++ ObjectMethod eachMembership ($cUID) -> ListIterator of groups this user is in

See baseclass for documentation

=cut

sub eachMembership {
    my ( $this, $user ) = @_;

    _getListOfGroups($this);
    require Foswiki::ListIterator;
    my $it = new Foswiki::ListIterator( \@{ $this->{groupsList} } );
    $it->{filter} = sub {
        $this->isInGroup( $user, $_[0] );
    };
    return $it;
}

=begin TML

---++ ObjectMethod isAdmin( $cUID ) -> $boolean

True if the user is an admin
   * is $Foswiki::cfg{SuperAdminGroup}
   * is a member of the $Foswiki::cfg{SuperAdminGroup}

=cut

sub isAdmin {
    my ( $this, $cUID ) = @_;
    my $isAdmin = 0;

    # TODO: this might not apply now that we have BaseUserMapping - test
    if ( $cUID eq $Foswiki::cfg{SuperAdminGroup} ) {
        $isAdmin = 1;
    }
    else {
        my $sag = $Foswiki::cfg{SuperAdminGroup};
        $isAdmin = $this->isInGroup( $cUID, $sag );
    }

    return $isAdmin;
}

=begin TML

---++ ObjectMethod findUserByEmail( $email ) -> \@cUIDs
   * =$email= - email address to look up
Return a list of canonical user names for the users that have this email
registered with the password manager or the user mapping manager.

The password manager is asked first for whether it maps emails.
If it doesn\'t, then the user mapping manager is asked instead.

=cut

sub findUserByEmail {
    my ( $this, $email ) = @_;
    ASSERT($email) if DEBUG;
    my @users;

    my $logins = $this->{passwords}->findUserByEmail($email);
    if ( defined $logins ) {
        foreach my $l (@$logins) {
            $l = $this->login2cUID($l);
            push( @users, $l ) if $l;
        }
    }

    return \@users;
}

=begin TML

---++ ObjectMethod getEmails($name) -> @emailAddress

If $name is a user, return their email addresses. If it is a group,
return the addresses of everyone in the group.

The password manager and user mapping manager are both consulted for emails
for each user (where they are actually found is implementation defined).

Duplicates are removed from the list.

=cut

sub getEmails {
    my ( $this, $user, $seen ) = @_;

    $seen ||= {};

    my %emails = ();

    unless ( $seen->{$user} ) {
        $seen->{$user} = 1;

        if ( $this->isGroup($user) ) {
            my $it = $this->eachGroupMember($user);
            while ( $it->hasNext() ) {
                foreach ( $this->getEmails( $it->next(), $seen ) ) {
                    $emails{$_} = 1;
                }
            }
        }
        else {

            # get emails from the password manager
            foreach ( $this->{passwords}
                ->getEmails( $this->getLoginName($user), $seen ) )
            {
                $emails{$_} = 1;
            }
        }
    }

    return keys %emails;
}

=begin TML

---++ ObjectMethod setEmails($cUID, @emails) -> boolean

Set the email address(es) for the given user.
The password manager handles this for us.

=cut

sub setEmails {
    my $this = shift;
    my $user = shift;

    $this->{passwords}->setEmails( $this->getLoginName($user), @_ );
}

=begin TML

---++ StaticMethod mapper_getEmails($session, $user)

Only used if passwordManager->isManagingEmails= = =false
(The emails are stored in the user topics.

Note: This method is PUBLIC because it is used by the tools/upgrade_emails.pl
script, which needs to kick down to the mapper to retrieve email addresses
from Foswiki topics.

=cut

sub mapper_getEmails {
    my ( $session, $user ) = @_;

    die "Should not be called for X509 - is X509PasswdUser configured?";

    my ( $meta, $text ) = $session->{store}->readTopic(
        undef,
        $Foswiki::cfg{UsersWebName},
        $session->{users}->getWikiName($user)
    );

    my @addresses;

    # Try the form first
    my $entry = $meta->get( 'FIELD', 'Email' );
    if ($entry) {
        push( @addresses, split( /;/, $entry->{value} ) );
    }
    else {

        # Now try the topic text
        foreach my $l ( split( /\r?\n/, $text ) ) {
            if ( $l =~ /^\s+\*\s+E-?mail:\s*(.*)$/mi ) {
                push @addresses, split( /;/, $1 );
            }
        }
    }

    return @addresses;
}

=begin TML

---++ StaticMethod mapper_setEmails ($session, $user, @emails)

Only used if =passwordManager->isManagingEmails= = =false=.
(emails are stored in user topics

=cut

sub mapper_setEmails {
    my $session = shift;
    my $cUID    = shift;

    die "Should not be called for X509 - is X509PasswdUser configured?";
    my $mails = join( ';', @_ );

    my $user = $session->{users}->getWikiName($cUID);

    my ( $meta, $text ) =
      $session->{store}->readTopic( undef, $Foswiki::cfg{UsersWebName}, $user );

    if ( $meta->get('FORM') ) {

        # use the form if there is one
        $meta->putKeyed(
            'FIELD',
            {
                name       => 'Email',
                value      => $mails,
                title      => 'Email',
                attributes => 'h'
            }
        );
    }
    else {

        # otherwise use the topic text
        unless ( $text =~ s/^(\s+\*\s+E-?mail:\s*).*$/$1$mails/mi ) {
            $text .= "\n   * Email: $mails\n";
        }
    }

    $session->{store}
      ->saveTopic( $cUID, $Foswiki::cfg{UsersWebName}, $user, $text, $meta );
}

=begin TML

---++ ObjectMethod findUserByWikiName ($wikiname) -> list of cUIDs associated with that wikiname

See baseclass for documentation

The $skipExistanceCheck parameter
is private to this module, and blocks the standard existence check
to avoid reading .htpasswd when checking group memberships).

=cut

sub findUserByWikiName {
    my ( $this, $wn, $skipExistanceCheck ) = @_;
    my @users = ();

    if ( $this->isGroup($wn) ) {
        push( @users, $wn );
    }
    else {

        # Add additional mappings defined in WikiUsers
        _loadMapping($this);
        if ( $this->{W2U}->{$wn} ) {

            # Wikiname to UID mapping is defined
            push( @users, $this->{W2U}->{$wn} );
        }
        else {

           # Bloody compatibility!
           # The wikiname is always a registered user for the purposes of this
           # mapping. We have to do this because Foswiki defines access controls
           # in terms of mapped users, and if a wikiname is *missing* from the
           # mapping there is "no such user".
            push( @users, $this->login2cUID($wn) );
        }
    }

    return \@users;
}

=begin TML

---++ ObjectMethod checkPassword( $cUID, $password ) -> $boolean

Finds if the password is valid for the given user.

Returns 1 on success, undef on failure.

=cut

sub checkPassword {
    my ( $this, $cUID, $pw ) = @_;
    return $this->{passwords}->checkPassword( $this->getLoginName($cUID), $pw );
}

=begin TML

---++ ObjectMethod setPassword( $cUID, $newPassU, $oldPassU ) -> $boolean

BEWARE: $user should be a cUID, but is a login when the resetPassword
functionality is used.
The UserMapper needs to convert either one to a valid login for use by
the Password manager

TODO: needs fixing

If the $oldPassU matches matches the user\'s password, then it will
replace it with $newPassU.

If $oldPassU is not correct and not 1, will return 0.

If $oldPassU is 1, will force the change irrespective of
the existing password, adding the user if necessary.

Otherwise returns 1 on success, undef on failure.

=cut

sub setPassword {
    my ( $this, $user, $newPassU, $oldPassU ) = @_;
    return $this->{passwords}
      ->setPassword( $this->getLoginName($user), $newPassU, $oldPassU );
}

=begin TML

---++ ObjectMethod passwordError( ) -> $string

returns a string indicating the error that happened in the password handlers
TODO: these delayed errors should be replaced with Exceptions.

returns undef if no error

=cut

sub passwordError {
    my ($this) = @_;
    return $this->{passwords}->error();
}

# TODO: and probably flawed in light of multiple cUIDs mapping to one wikiname
sub _cacheUser {
    my ( $this, $wikiname, $login ) = @_;
    ASSERT($wikiname) if DEBUG;

    $login ||= $wikiname;

    my $cUID = $this->login2cUID( $login, 1 );
    return unless ($cUID);
    ASSERT($cUID) if DEBUG;

    #$this->{U2L}->{$cUID}     = $login;
    $this->{U2W}->{$cUID}     = $wikiname;
    $this->{L2U}->{$login}    = $cUID;
    $this->{W2U}->{$wikiname} = $cUID;

    return $cUID;
}

# callback for search function to collate results
sub _collateGroups {
    my $ref   = shift;
    my $group = shift;
    return unless $group;
    push( @{ $ref->{list} }, $group );
}

# get a list of groups defined in this Foswiki
sub _getListOfGroups {
    my $this = shift;
    ASSERT( $this->isa('Foswiki::Users::X509UserMapping') ) if DEBUG;

    #??
    unless ( $this->{groupsList} ) {
        my $users = $this->{session}->{users};
        $this->{groupsList} = [];

        $this->{session}->search->searchWeb(
            _callback => \&_collateGroups,
            _cbdata   => {
                list  => $this->{groupsList},
                users => $users
            },
            inline    => 1,
            search    => "Set GROUP =",
            web       => $Foswiki::cfg{UsersWebName},
            topic     => "*Group",
            type      => 'regex',
            nosummary => 'on',
            nosearch  => 'on',
            noheader  => 'on',
            nototal   => 'on',
            noempty   => 'on',
            format    => '$topic',
            separator => '',
        );
    }
    return $this->{groupsList};
}

# Build hash to translate between username (e.g. jsmith)
# and WikiName (e.g. Main.JaneSmith).
sub _loadMapping {
    my $this = shift;
    return if $this->{CACHED};
    $this->{CACHED} = 1;

    my $iter = $this->{passwords}->fetchUsers();
    while ( $iter->hasNext() ) {
        my $wikiname = $iter->next();
        _cacheUser( $this, $wikiname,
            $this->{passwords}->wiki2Login( $wikiname, 1 ) );
    }
    return;
}

# Get a list of *canonical user ids* from a text string containing a
# list of user *wiki* names, *login* names, and *group ids*.
sub _expandUserList {
    my ( $this, $names ) = @_;

    $names ||= '';

    # comma delimited list of users or groups
    # i.e.: "%USERSWEB%.UserA, UserB, Main.UserC # something else"
    $names =~ s/(<[^>]*>)//go;    # Remove HTML tags

    my @l;
    foreach my $ident ( split( /[\,\s]+/, $names ) ) {

        # Dump the web specifier if userweb
        $ident =~ s/^($Foswiki::cfg{UsersWebName}|%USERSWEB%|%MAINWEB%)\.//;
        next unless $ident;
        if ( $this->isGroup($ident) ) {
            my $it = $this->eachGroupMember($ident);
            while ( $it->hasNext() ) {
                push( @l, $it->next() );
            }
        }
        else {

            # Might be a wiki name (wiki names may map to several cUIDs)
            my %names =
              map { $_ => 1 }
              @{ $this->{session}->{users}->findUserByWikiName($ident) };

            # May be a login name (login names map to a single cUID)
            my $cUID = $this->{session}->{users}->getCanonicalUserID($ident);
            $names{$cUID} = 1 if $cUID;
            push( @l, keys %names );
        }
    }
    return \@l;
}

1;
