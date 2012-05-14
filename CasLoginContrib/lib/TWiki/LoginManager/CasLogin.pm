# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2006 TWiki Contributors.
# All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2005 Greg Abbas, twiki@abbas.org
# Copyright (C) 2008 Charlie Reitsma, reitsma@denison.edu
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

---+ package TWiki::LoginManager::CasLogin

This is a login manager that you can specify in the security setup section of
[[%SCRIPTURL{"configure"}%][configure]]. It provides users with a trip to
the CAS server to enter usernames and passwords.

Subclass of TWiki::LoginManager; see that class for documentation of the
methods of this class.

=cut

package TWiki::LoginManager::CasLogin;
use TWiki::LoginManager;
our @ISA = qw( TWiki::LoginManager );

use strict;
use Assert;
use AuthCAS;

=pod

---++ ClassMethod new ($session, $impl)

Construct the CasLogin object

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = $class->SUPER::new($session);
    $session->enterContext('can_login');
    if ( $TWiki::cfg{Sessions}{ExpireCookiesAfter} ) {
        $session->enterContext('can_remember_login');
    }
    return $this;
}

=pod

---++ ObjectMethod forceAuthentication () -> boolean

method called when authentication is required - redirects to (...|view)auth
Triggered on auth fail

=cut

sub forceAuthentication {
    my $this  = shift;
    my $twiki = $this->{twiki};

    unless ( $twiki->inContext('authenticated') ) {
        my $query = $twiki->{cgiQuery};

        # Redirect with passthrough so we don't lose the original query params
        my $twiki = $this->{twiki};
        my $topic = $twiki->{topicName};
        my $web   = $twiki->{webName};
        my $url   = $twiki->getScriptUrl( 0, 'login', $web, $topic );
        $query->param( -name => 'origurl', -value => $ENV{REQUEST_URI} );
        $twiki->redirect( $url, 1 );
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
    my $this  = shift;
    my $twiki = $this->{twiki};
    my $topic = $twiki->{topicName};
    my $web   = $twiki->{webName};
    return $twiki->getScriptUrl( 0, 'login', $web, $topic,
        origurl => $ENV{REQUEST_URI} );
}

=pod

---++ ObjectMethod login( $query, $twiki )

Redirect to CAS server to login. Successful login results in a
username.

=cut

sub login {
    my ( $this, $query, $twikiSession ) = @_;
    my $twiki  = $this->{twiki};
    my $casUrl = $TWiki::cfg{CAS}{casUrl};
    my $CAFile = $TWiki::cfg{CAS}{CAFile};
    my $cas    = new AuthCAS(
        casUrl => $casUrl,
        CAFile => $CAFile
    );

    my $origurl  = $query->param('origurl');
    my $app_url  = $TWiki::cfg{DefaultUrlHost};
    my $remember = $query->param('remember');
    my $ticket   = $query->param('ticket');

    # Eat these so there's no risk of accidental passthrough
    $query->delete( 'origurl', 'ticket' );

    my $cgisession = $this->{_cgisession};

    $cgisession->param( 'REMEMBER', $remember ) if $cgisession;

    my $error = '';

    if ($ticket) {
        my $validation = 1;
        $origurl = $cgisession->param('my_orig');
        $cgisession->clear( ['my_orig'] );

        my $loginName = $cas->validateST( $app_url . $origurl, $ticket );
        if ($loginName) {
            $this->userLoggedIn($loginName);
            $cgisession->param( 'VALIDATION', $validation ) if $cgisession;

            #SUCCESS our user is authenticated..
            $query->delete('sudo')
              ; #remove the sudo param - its only to tell TemplateLogin that we're using BaseMapper..
                # Redirect with passthrough
            $twikiSession->redirect( $origurl, 1 );
            return;
        }
    }
    else {
        $cgisession->param( 'my_orig', $origurl ) if $cgisession;
        ###
        ### Redirect the User for login at CAS server
        ###
        my $login_url = $cas->getServerLoginURL( $app_url . $origurl );
        printf "Location: $login_url\n\n";
        exit 0;
    }
}

1;
