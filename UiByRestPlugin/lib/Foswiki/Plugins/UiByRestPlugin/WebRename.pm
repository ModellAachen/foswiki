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

package Foswiki::Plugins::UiByRestPlugin::WebRename;

use strict;
use warnings;
use Error qw(:try);

# the template which is generally used for this action
my $templatename = "renameweb";

=begin TML

---++ do( $session )
See documentation in Foswiki::Plugins::UiByRestPlugin::renameWeb()

=cut

sub do {
    my $session = shift;

    # check preconditions. If something fails and is critical
    # a status code will be set and a template will be returned if.

    my $template = _hardPrecondition($session);
    if ( $template ne 0 )
    { # if a template has been returned, we have errors. So lets print the template to the body and return.
        return $template;
    }
    $template = _softPrecondition($session);
    if ( $template ne 0 )
    { # if a template has been returned, we have errors. So lets print the template to the body and return.
        return $template;
    }

    # prepare the action for rename
    $session->{cgiQuery}->param( "action", "renameweb" );

    # if everything is fine, we can do the actual renaming now
    use Foswiki::UI::Manage;
    Foswiki::UI::Manage::rename($session);

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

    # we do this, to get the proper status code.
    # Eventhough we return the template requested in any case
    # we will e.g. set a 403 if the user is not allowed
    # this can be used by the request to maybe better show a login screen
    # or something else.
    _hardPrecondition($session);

    # as we dont care about the template the hardPrecondition returns
    # we load the one requested
    return _showTemplate( $theTopic, $theWeb, $theSkin, $templatename );
}

sub _hardPrecondition {
    my $session   = shift;
    my $query     = $session->{cgiQuery};
    my $theTopic  = $session->{topicName};
    my $theOldWeb = $session->{webName};
    my $theUser   = Foswiki::Func::getWikiName();
    my $theSkin   = $query->param("skin")
      || Foswiki::Func::getSkin();    # SMELL: should be sanatized
    my $isSetTopic = $query->param("topic") || 0;

    # check topic parameter first; if not set, the rest is irrelevant
    if ( !$isSetTopic ) {
        $session->{response}->status("400 Missing parameter: topic");
        return _showTemplate( $theTopic, $theOldWeb, $theSkin, $templatename );
    }

    # check if old web exists
    if ( !Foswiki::Func::webExists($theOldWeb) ) {
        $session->{response}->header( -status => "404 File not found" );
        return _showTemplate( $theTopic, $theOldWeb, $theSkin, $templatename );
    }

    # Calculate parent of the old web
    my @tmp = split( /[\/\.]/, $theOldWeb );
    pop(@tmp);
    my $oldParentWeb = join( '/', @tmp );

   # If the user is not allowed to rename anything in the parent web - stop here
   # This also ensures we check root webs for ALLOWROOTRENAME and DENYROOTRENAME
    if (
        !Foswiki::Func::checkAccessPermission(
            'RENAME', $theUser, undef, undef, $oldParentWeb || undef, undef
        )
      )
    {
        if ( $theUser eq $Foswiki::cfg{DefaultUserWikiName} ) {
            $session->{response}->status("401 Unauthorized");
            return _showTemplate( $theTopic, $theOldWeb, $theSkin, "login" );
        }    # else
        $session->{response}
          ->status("403 Forbidden to rename in old parent web");
        return _showTemplate( $theTopic, $theOldWeb, $theSkin, $templatename );
    }

# If old web is a root web then also stop if ALLOW/DENYROOTCHANGE prevents access
    if (
        !$oldParentWeb
        && !Foswiki::Func::checkAccessPermission(
            'CHANGE', $theUser, undef, undef, $oldParentWeb || undef, undef
        )
      )
    {
        if ( $theUser eq $Foswiki::cfg{DefaultUserWikiName} ) {
            $session->{response}->status("401 Unauthorized");
            return _showTemplate( $theTopic, $theOldWeb, $theSkin, "login" );
        }    # else
        $session->{response}
          ->status("403 Forbidden to change old root parent web");
        return _showTemplate( $theTopic, $theOldWeb, $theSkin, $templatename );
    }

    return 0;
}

sub _softPrecondition {
    my $session   = shift;
    my $query     = $session->{cgiQuery};
    my $theTopic  = $session->{topicName};
    my $theOldWeb = $session->{webName};
    my $theSkin   = $query->param("skin")
      || Foswiki::Func::getSkin();    # SMELL: should be sanatized
    my $theNewSubWeb = $query->param("newsubweb")
      || undef;                       # SMELL: should be sanatized
    my $theNewParentWeb = $query->param("newparentweb")
      || undef;                       # SMELL: should be sanatized

    my @missing = ();
    if ( !defined($theNewSubWeb) )    { push( @missing, "newsubweb" ) }
    if ( !defined($theNewParentWeb) ) { push( @missing, "newparentweb" ) }

    # check if we miss parameters
    if ( scalar(@missing) > 0 ) {
        $session->{response}
          ->status( "400 Missing parameter: " . join( ",", @missing ) );
        return _showTemplate( $theTopic, $theOldWeb, $theSkin, $templatename );
    }

    # is the newparentweb a valid webname?
    if ( !Foswiki::Func::isValidWebName( $theNewParentWeb, 1 ) ) {
        $session->{response}->status("400 Not valid: newparentweb");
        return _showTemplate( $theTopic, $theOldWeb, $theSkin, $templatename );
    }

    # is the newsubweb a valid webname?
    if ( !Foswiki::Func::isValidWebName( $theNewSubWeb, 1 ) ) {
        $session->{response}->status("400 Not valid: newnewsubweb");
        return _showTemplate( $theTopic, $theOldWeb, $theSkin, $templatename );
    }

    # calculate the new webname
    my $newWeb = _calculateNewWeb( $theNewParentWeb, $theNewSubWeb );

    # check if new web exists
    if ( !Foswiki::Func::webExists($newWeb) ) {
        $session->{response}
          ->header( -status => "409 Conflict. New web already exists." );
        return _showTemplate( $theTopic, $theOldWeb, $theSkin, $templatename );
    }

    return 0;
}

sub _showTemplate {
    my ( $topic, $web, $skin, $templatename ) = @_;

    my $template = Foswiki::Func::loadTemplate( $templatename, $skin, undef );
    return Foswiki::Func::expandCommonVariables( $template, $topic, $web,
        undef );
}

sub _calculateNewWeb {
    my ( $theNewParentWeb, $theNewSubWeb ) = @_;

    if ($theNewSubWeb) {
        if ($theNewParentWeb) {
            return $theNewParentWeb . '/' . $theNewSubWeb;
        }
        else {
            return $theNewSubWeb;
        }
    }
}

