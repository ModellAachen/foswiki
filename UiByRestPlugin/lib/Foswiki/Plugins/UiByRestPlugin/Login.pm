# This script Copyright (c) 2009 Collaborganize  ( www.collaborganize.com )
# and distributed under the GPL (see below)
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
#
# Author: Eugen Mayer, Oliver Krueger

package Foswiki::Plugins::UiByRestPlugin::Login;

use strict;
use warnings;
use Error qw(:try);

# the template which is generally used for this action
my $templatename = "login";

=begin TML

---++ do( $session )
Rest handler to perform logins

It checks the prerequisites and sets the following status codes:
400 : url parameter(s) are missing
400 : user is already logged in
403 : authentication failed

Return:
In case of an error, the login template is returned.
In case of no error, the LoginManagers login method is invoked,
which end in a redirect.

=cut

sub do {
    my $session = shift;

    # check preconditions. If something fails and is critical
    # a status code will be set and a template will be returned if.

    my $template = _checkPrecondition($session);
    if ( $template ne 0 )
    { # if a template has been returned, we have errors. So lets print the template to the body and return.
        return $template;
    }

    # unfortunately LoginManagers tend to redirect
    # at least TemplateLogin's login() sets a 403 in case of a failure
    $session->{users}->{loginManager}->login( $session->{request}, $session );

    return "";
}

=begin TML

---++ template( $session )
Return the template which is defined for renaming a topic ( renametopic.YOURSKIN.tmpl )
=cut

sub template {
    my $session  = shift;
    my $query    = $session->{cgiQuery};
    my $theTopic = $session->{topicName};
    my $theWeb   = $session->{webName};
    my $theSkin  = $query->param("skin")
      || Foswiki::Func::getSkin();    # SMELL: should be sanatized

    # as we dont care about the template the hardPrecondition returns
    # we load the one requested
    return _showTemplate( $theTopic, $theWeb, $theSkin, $templatename );
}

sub _checkPrecondition {
    my $session  = shift;
    my $query    = $session->{cgiQuery};
    my $theTopic = $session->{topicName};
    my $theWeb   = $session->{webName};
    my $theSkin  = $query->param("skin")
      || Foswiki::Func::getSkin();    # SMELL: should be sanatized
    my $theUsername = $query->param("username") || undef;
    my $thePassword = $query->param("password") || undef;

    # already logged in?
    if ( Foswiki::Func::getWikiName() ne $Foswiki::cfg{DefaultUserWikiName} ) {
        $session->{response}->status("400 Already logged in");
        return _showTemplate( $theTopic, $theWeb, $theSkin, $templatename );
    }

    # check if we miss parameters
    my @missing = ();
    if ( !defined($theUsername) ) { push( @missing, "username" ) }
    if ( !defined($thePassword) ) { push( @missing, "password" ) }

    if ( scalar(@missing) > 0 ) {
        $session->{response}
          ->status( "400 Missing parameter: " . join( ",", @missing ) );
        return _showTemplate( $theTopic, $theWeb, $theSkin, $templatename );
    }

    return 0;
}

sub _showTemplate {
    my ( $topic, $web, $skin, $templatename ) = @_;

    my $template = Foswiki::Func::loadTemplate( $templatename, $skin, undef );
    return Foswiki::Func::expandCommonVariables( $template, $topic, $web,
        undef );
}
