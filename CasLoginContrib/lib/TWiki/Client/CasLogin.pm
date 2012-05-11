# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2005 Greg Abbas, twiki@abbas.org
# Copyright (C) 2008 Charlie Reitsma, reitsma@denison.edu
# Copyright (C) 2008 Olivier Berger, olivier.berger@it-sudparis.eu
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

---+ package TWiki::Client::CasLogin

This is a login manager that you can specify in the security setup section of
[[%SCRIPTURL{"configure"}%][configure]]. It provides users with a trip to
the CAS server to enter usernames and passwords.

Subclass of TWiki::Client; see that class for documentation of the
methods of this class.

=cut

package TWiki::Client::CasLogin;

use strict;
use Assert;
use TWiki::Client;
use AuthCAS;

@TWiki::Client::CasLogin::ISA = ('TWiki::Client');

sub new {
    my ( $class, $session ) = @_;

    my $this = bless( $class->SUPER::new($session), $class );

    $session->enterContext('can_login');
    return $this;
}

# Triggered on auth fail : redirects to the login script which in turn will go to CAS
sub forceAuthentication {
    my $this  = shift;
    my $twiki = $this->{twiki};

    #    TWiki::Client::_trace($this, "CasLogin::forceAuthentication()");

    unless ( $twiki->inContext('authenticated') ) {
        my $query = $twiki->{cgiQuery};

        # Redirect with passthrough so we don't lose the original query params
        my $twiki = $this->{twiki};
        my $topic = $twiki->{topicName};
        my $web   = $twiki->{webName};

# simple URL of the login script (not using loginUrl() to not provide additional args not necessary when calling redirect and not real redirect)
        my $url = $twiki->getScriptUrl( 0, 'login', $web, $topic );
        $query->param( -name => 'origurl', -value => $ENV{REQUEST_URI} );

# redirect to the login script by asking it to transfer to origurl one authenticated successfully
        $twiki->redirect( $url, 1 );
        return 1;
    }
    return undef;
}

# Content of a login link displayed in the page
sub loginUrl {
    my $this = shift;

    #    TWiki::Client::_trace($this, "CasLogin::loginUrl()");

    my $twiki = $this->{twiki};
    my $topic = $twiki->{topicName};
    my $web   = $twiki->{webName};

# generate a link to the login script with origurl param to return to the same place (view normally)
    return $twiki->getScriptUrl( 0, 'login', $web, $topic,
        origurl => $ENV{REQUEST_URI} );
}

=pod

---++ ObjectMethod login( $query, $twiki )


If invoked from the CAS server with a valid ticket, redirects to the original
script. If the ticket is invalid, fails.

If invoked without a ticket parameter (maybe after direct access to
login script or redirect because of previous forceAuthentication, then
redirect to CAS server to login. 
After successful login on CAS server, we will be invoked back, with
the ability to retrieve a username by verifying the ticket.

When invoked since foreceAuthentication is needed, we should return
afterwards to the orig_url parameter. This needs to be saved during
the trip to the CAS server, by using the 'my_orig' session variable.

=cut

sub login {
    my ( $this, $query, $twikiSession ) = @_;

    #    TWiki::Client::_trace($this, "CasLogin::login()");

    my $twiki = $this->{twiki};

    my $casUrl = $TWiki::cfg{CAS}{casUrl};
    my $CAFile = $TWiki::cfg{CAS}{CAFile};
    my $cas    = new AuthCAS(
        casUrl => $casUrl,
        CAFile => $CAFile
    );

    my $url      = $query->url();
    my $origurl  = $query->param('origurl');
    my $app_url  = $TWiki::cfg{DefaultUrlHost};
    my $remember = $query->param('remember');

# this is a param provided by CAS server to the app it redirects to upon succesfull login
    my $ticket = $query->param('ticket');

    # Eat these so there's no risk of accidental passthrough
    $query->delete( 'origurl', 'ticket' );

    my $cgisession = $this->{_cgisession};

    $cgisession->param( 'REMEMBER', $remember ) if $cgisession;

    my $error = '';

    if ($ticket) {

        # now we've been redirected here by the CAS server

  #TWiki::Client::_trace($this, "CasLogin::login : we have a ticket : $ticket");

       # retrieve the original orig_url that had been passed to the login script
        $origurl = $cgisession->param('my_orig');
        $cgisession->clear( ['my_orig'] );

        # validate the ticket with our login URL
        my $loginName = $cas->validateST( $url, $ticket );

        # if validation is successfull, we have the login name
        if ($loginName) {

#	    TWiki::Client::_trace($this, "CasLogin::login : we have a login : $loginName");

            # notifiy parent class that user is logged-in
            $this->userLoggedIn($loginName);

            #SUCCESS our user is authenticated..

            # Redirect with passthrough
            # get back to where authentication was requested
            $twikiSession->redirect( $origurl, 1 );
            return;
        }
        else {

            # autherwise, authentication was refused
            printf STDERR "Error: %s\n", &AuthCAS::get_errors();

# would need some kind of banner in case of unsuccesfull auth (reuse templatelogin)
            exit 0;
        }
    }
    else {

# initially called by explicit login script or forceauthentication() pseudo redirect

# save previous origurl into my_orig in the session to b able to retrieve it when coming back from CAS server's login screen
        $cgisession->param( 'my_orig', $origurl ) if $cgisession;

        ###
        ### Redirect the User for login at CAS server
        ###

# Redirect the server so that we get back to login afterwards and be able to consume the ticket parameter
        my $login_url = $cas->getServerLoginURL($url);

        # real redirect
        print "Location: $login_url\n\n";
        exit 0;
    }
}

1;
