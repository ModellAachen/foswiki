# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2005-2008 Timothe Litt, litt@acm.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

=begin TML 

---+ package Foswiki::Users::X509PasswdUser

Support for htpasswd and htdigest format password files containing X.509 certificate-based login namess.

Subclass of =[[%SCRIPTURL{view}%/%SYSTEMWEB%/PerlDoc?module=Foswiki::Users::Password][Foswiki::Users::Password]]=.
See documentation of that class for descriptions of the methods of this class.

Apache authorizes access to files with SSL certificates using the full DN 
 e.g. /C=US/ST=Confusion/L=Unknown/O=Megalith/OU=Fun house/CN=Fake Test User/emailAddress=faker@example.com
as the username.  This confuses the rest of Foswiki due to lots of special characters, as well as
being, well, ugly.

We solve this problem in four parts:

o The X509UserPlugin provides access to the DN as required for registration and other forms.

o This X509PasswdUser class provides storage for the DN as login name & 'password' required by apache, 
  PLUS the wikiname and e-mail address list for each user.

o Note that the password for certificate users is ALWAYS "xxj31ZMTZzkVA" (without the quotes).
  If you are curious, this is a DES encoding of 'password'

o The X509UserMapping class handles the mapping between wikinames and login names (as well as internal
  identifiers called cUIDs.

o The X509Login manager manages X509 logins.

See the X509UserPlugin topic for additional documentation.

=cut

package Foswiki::Users::X509PasswdUser;
use Foswiki::Users::Password;
our @ISA = qw( Foswiki::Users::Password );
use Fcntl qw( :flock :seek );

use strict;
use Assert;
use Error qw( :try );

# 'Use locale' for internationalisation of Perl sorting in getTopicNames
# and other routines - main locale settings are done in Foswiki::setupLocale
BEGIN {

    # Do a dynamic 'use locale' for this module
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( $class->SUPER::new($session), $class );
    $this->{error} = undef;

    # Always plaintext encoding for X509

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
    $this->SUPER::finish();
    undef $this->{passworddata};
    close $this->{passwordlock} if ( $this->{passwordlock} );
    undef $this->{passwordlock};
}

=pod

---++ ObjectMethod readOnly(  ) -> boolean

returns true if the password file is not currently modifyable

=cut

sub readOnly {
    my $this = shift;
    my $path = $Foswiki::cfg{Htpasswd}{FileName};

    #TODO: what if the data dir is also read only?
    if ( ( !-e $path ) || ( -e $path && -r $path && !-d $path && -w $path ) ) {
        $this->{session}->enterContext('passwords_modifyable');
        return 0;
    }
    return 1;
}

sub canFetchUsers {
    return 1;
}

sub fetchUsers {
    my $this = shift;
    my $db   = $this->_readPasswd();
    my @users;
    foreach ( sort keys %$db ) {
        push @users, $_ if ( $_ eq $db->{$_}->{wikiname} );
    }
    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@users );
}

sub wiki2Login {
    my $this     = shift;
    my $wikiname = shift;

    my $db = $this->_readPasswd();
    return $db->{$wikiname}->{certname};
}

sub _readPasswd {
    my $this = shift;
    my $lock = shift;

    if ( defined( $this->{passworddata} ) ) {
        return $this->{passworddata} unless ($lock);
    }

    my $db = {};
    if ( !-e $Foswiki::cfg{Htpasswd}{FileName} ) {
        return $db;
    }

    # Htpasswd contains certificate, wikiname and emails
    # WikiUsers topic is not used (anymore)
    my $ifh;
    if ($lock) {
        open( $ifh, "+<$Foswiki::cfg{Htpasswd}{FileName}" )
          || throw Error::Simple(
            $Foswiki::cfg{Htpasswd}{FileName} . ' open failed: ' . $! );
        $this->{passwordlock} = $ifh;
        flock( $ifh, LOCK_EX )
          or throw Error::Simple(
            "Unable to lock $Foswiki::cfg{Htpasswd}{FileName}: $!");
        return $this->{passworddata} if ( defined( $this->{passworddata} ) );
    }
    else {
        open( $ifh, "<$Foswiki::cfg{Htpasswd}{FileName}" )
          || throw Error::Simple(
            $Foswiki::cfg{Htpasswd}{FileName} . ' open failed: ' . $! );
        flock( $ifh, LOCK_SH )
          or throw Error::Simple(
            "Unable to lock $Foswiki::cfg{Htpasswd}{FileName}: $!");
    }
    my $line = '';
    while ( defined( $line = <$ifh> ) ) {
        if ( $line =~ /^(.+?):(.*?):(.*?)(?::(.*))?$/ ) {
            my ( $certname, $pass, $wikiname, $email ) = ( $1, $2, $3, $4 );

            # Map from login to password and e-mail.

            $db->{$certname} = {
                certname => $certname,        # For reverse lookups
                pass     => "xxj31ZMTZzkVA"
                ,    # Required for apache certificate authentication
                emails   => $email    || '',
                wikiname => $wikiname || '',
            };

# Map data from wikiname as well.
# Wikinames don't look anything like a login name, so there's no conflict.
# Perhaps we should have 2 separate hashes to reduce the sort costs.  Not today.

            $db->{$wikiname} = $db->{$certname} if ($wikiname);
        }
    }
    close($ifh) unless ($lock);

    $this->{passworddata} = $db;
    return $db;
}

sub _dumpPasswd {
    my $db = shift;
    my $s  = '';
    foreach ( sort keys %$db ) {

     # db has the same data keyed by login and by wikiname.  Only write it once.
        $s .=
            $_ . ':'
          . $db->{$_}->{pass} . ':'
          . $db->{$_}->{wikiname} . ':'
          . $db->{$_}->{emails} . "\n"
          unless ( $_ eq $db->{$_}->{wikiname} );
    }
    return $s;
}

sub _savePasswd {
    my $this = shift;
    my $db   = shift;

    umask(077);
    my $fh = $this->{passwordlock}
      or throw Error::Simple(
        "X509 write without lock for $Foswiki::cfg{Htpasswd}{FileName}");
    seek( $fh, 0, SEEK_SET )
      or throw Error::Simple(
        "X509 seek 0 failed for $Foswiki::cfg{Htpasswd}{FileName}");
    print $fh _dumpPasswd($db);
    truncate( $fh, tell($fh) )
      or throw Error::Simple(
        "X509 truncate failed for $Foswiki::cfg{Htpasswd}{FileName}");

    close($fh);
    undef $this->{passwordlock};
}

sub encrypt {
    my ( $this, $login, $passwd, $fresh ) = @_;

    $passwd = "xxj31ZMTZzkVA"; # Required for apache certificate authentication;

# X509 never encrypts (but don't worry, the password is only to make apache happy.
# The real authentication is done by the certificate validation there.
    return $passwd;
}

sub fetchPass {
    my ( $this, $login ) = @_;
    my $ret = 0;

    if ($login) {
        try {
            my $db = $this->_readPasswd();
            if ( exists $db->{$login} ) {
                $ret = $db->{$login}->{pass};
            }
            else {
                $this->{error} = 'Login invalid';
                $ret = undef;
            }
        }
        catch Error::Simple with {
            $this->{error} = $!;
        };
    }
    else {
        $this->{error} = 'No user';
    }
    return $ret;
}

sub addUser( ) {
    my ( $this, $login, $wikiname, $password, $emails ) = @_;

    die "X509 Not a login name $login in add" unless ( $login =~ m/\/(\w+)=/ );

    if ( $this->fetchPass($login) ) {
        $this->{error} = $login . ' already exists';
        return 0;
    }
    die "No wikiname in X509 addUser" unless ($wikiname);

    try {
        my $db = $this->_readPasswd(1);

        $db->{$login} = {
            certname => $login,
            pass =>
              "xxj31ZMTZzkVA",  # Required for apache certificate authentication
            emails   => $emails   || '',
            wikiname => $wikiname || '',
        };
        $db->{$wikiname} = $db->{$login};
        $this->_savePasswd($db);
    }
    catch Error::Simple with {
        $this->{error} = $!;
        print STDERR "ERROR: failed to add User - $!";
        return undef;
    };

    $this->{error} = undef;
    return 1;
}

sub setPassword {
    my ( $this, $login, $newUserPassword, $oldUserPassword ) = @_;

# This was called at registration to add a user, but X509UserMapping will never do that..
#
# There's no point in changing the password, since it's a constant for all users
# when using X509 authentication.  So we just fail.

    $this->{error} =
"X.509 Authentication does not use passwords, and they can not be set or changed";
    return undef;
}

sub removeUser {
    my ( $this, $login ) = @_;
    my $result = undef;
    $this->{error} = undef;

    try {
        my $db = $this->_readPasswd(1);
        unless ( $db->{$login} ) {
            $this->{error} = 'No such user ' . $login;
        }
        else {
            delete $db->{ $db->{$login}->{wikiname} }
              if ( $db->{ $db->{$login}->{wikiname} } );
            delete $db->{$login};
            $this->_savePasswd($db);
            $result = 1;
        }
    }
    catch Error::Simple with {
        $this->{error} = shift->{-text};
    };
    return $result;
}

sub checkPassword {
    my ( $this, $login, $password ) = @_;
    my $encryptedPassword = $this->encrypt( $login, $password );

    $this->{error} = undef;

    my $pw = $this->fetchPass($login);
    return 0 unless defined $pw;

    # $pw will be 0 if there is no pw

    return 1 if ( $pw && ( $encryptedPassword eq $pw ) );

    # pw may validly be '', and must match an unencrypted ''. This is
    # to allow for sysadmins removing the password field in .htpasswd in
    # order to reset the password.
    return 1 if ( defined $password && $pw eq '' && $password eq '' );

    $this->{error} = 'Invalid user/password';
    return 0;
}

sub isManagingEmails {
    return 1;
}

sub getEmails {
    my ( $this, $login ) = @_;

    my $db = $this->_readPasswd();
    if ( $db->{$login}->{emails} ) {
        return split( /;/, $db->{$login}->{emails} );
    }
    return;
}

sub setEmails {
    my $this  = shift;
    my $login = shift;
    ASSERT($login) if DEBUG;

    my $db = $this->_readPasswd(1);
    if ( $db->{$login} ) {
        if ( defined( $_[0] ) ) {
            $db->{$login}->{emails} = join( ';', @_ );
        }
        else {
            $db->{$login}->{emails} = '';
        }
        $this->_savePasswd($db);
    }
    else {
        close $this->{passwordlock};
        undef $this->{passwordlock};
    }
    return 1;
}

# Searches the password DB for users who have set this email.
sub findUserByEmail {
    my ( $this, $email ) = @_;
    my $logins = [];
    my $db     = _readPasswd();
    while ( my ( $k, $v ) = each %$db ) {
        next unless $db->{$k}->{wikiname} eq $k;

        my %ems = map { $_ => 1 } split( ';', $v->{emails} );
        if ( $ems{$email} ) {
            push( @$logins, $k );
        }
    }
    return $logins;
}

1;

