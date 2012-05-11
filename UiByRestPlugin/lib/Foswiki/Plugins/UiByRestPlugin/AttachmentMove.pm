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

package Foswiki::Plugins::UiByRestPlugin::AttachmentMove;

use strict;
use warnings;
use Error qw(:try);

# the template which is generally used for this action
my $templatename = "moveattachment";

=begin TML

---++ do( $session )
See documentation in Foswiki::Plugins::UiByRestPlugin::moveAttachment()

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
    my $session  = shift;
    my $query    = $session->{cgiQuery};
    my $theTopic = $session->{topicName};
    my $theWeb   = $session->{webName};
    my $theUser  = Foswiki::Func::getWikiName();
    my $theSkin  = $query->param("skin")
      || Foswiki::Func::getSkin();    # SMELL: should be sanatized
    my $isSetTopic = $query->param("topic") || 0;
    my $theAttachment = $query->param("attachment")
      || undef;                       # SMELL: should be sanatized

    # check topic parameter first; if not set, the rest is irrelevant
    if ( !$isSetTopic ) {
        $session->{response}->status("400 Missing parameter: topic");
        return _showTemplate( $theTopic, $theWeb, $theSkin, $templatename );
    }

    # check topic parameter first; if not set, the rest is irrelevant
    my @missing = ();
    if ( !$isSetTopic )             { push( @missing, "topic" ) }
    if ( !defined($theAttachment) ) { push( @missing, "attachment" ) }
    if ( scalar(@missing) > 0 ) {
        $session->{response}
          ->status( "400 Missing parameter: " . join( ",", @missing ) );
        return _showTemplate( $theTopic, $theWeb, $theSkin, $templatename );
    }

    # check if attachment exists
    if (
        !Foswiki::Func::attachmentExists( $theWeb, $theTopic, $theAttachment ) )
    {
        $session->{response}->status("404 Attachment not found");
        return _showTemplate( $theTopic, $theWeb, $theSkin, $templatename );
    }

    # check permission on old location
    if (
        !Foswiki::Func::checkAccessPermission(
            "CHANGE", $theUser, undef, $theTopic, $theWeb, undef
        )
      )
    {
        if ( $theUser eq $Foswiki::cfg{DefaultUserWikiName} ) {
            $session->{response}->status("401 Unauthorized");
            return _showTemplate( $theTopic, $theWeb, $theSkin, "login" );
        }    # else
        $session->{response}
          ->status("403 Forbidden: Current location is write protected");
        return _showTemplate( $theTopic, $theWeb, $theSkin, $templatename );
    }

    return 0;
}

sub _softPrecondition {
    my $session  = shift;
    my $query    = $session->{cgiQuery};
    my $theTopic = $session->{topicName};
    my $theWeb   = $session->{webName};
    my $theUser  = Foswiki::Func::getWikiName();
    my $theSkin  = $query->param("skin")
      || Foswiki::Func::getSkin();    # SMELL: should be sanatized
    my $theNewTopic = $query->param("newtopic")
      || undef;                       # SMELL: should be sanatized
    my $theNewWeb = $query->param("newweb")
      || undef;                       # SMELL: should be sanatized
    my $theAttachment = $query->param("attachment")
      || undef;                       # SMELL: should be sanatized

    my @missing = ();
    if ( !defined($theNewTopic) ) { push( @missing, "newtopic" ) }
    if ( !defined($theNewWeb) )   { push( @missing, "newweb" ) }

    # check if we miss parameters
    if ( scalar(@missing) > 0 ) {
        $session->{response}
          ->status( "400 Missing parameter: " . join( ",", @missing ) );
        return _showTemplate( $theTopic, $theWeb, $theSkin, $templatename );
    }

    # check permissions on new location
    if (
        !Foswiki::Func::checkAccessPermission(
            "CHANGE", $theUser, undef, $theNewTopic, $theNewWeb, undef
        )
      )
    {
        if ( $theUser eq $Foswiki::cfg{DefaultUserWikiName} ) {
            $session->{response}->status("401 Unauthorized");
            return _showTemplate( $theTopic, $theWeb, $theSkin, "login" );
        }    # else
        $session->{response}
          ->status("403 Forbidden: New location is write protected");
        return _showTemplate( $theTopic, $theWeb, $theSkin, $templatename );
    }

    # does newtopic exists?
    if ( !Foswiki::Func::topicExists( $theNewWeb, $theNewTopic ) ) {
        $session->{response}->header( -status => "404 New location not found" );
        return _showTemplate( $theTopic, $theWeb, $theSkin, $templatename );
    }

    # does attachment in new location already exists?
    if (
        Foswiki::Func::attachmentExists(
            $theNewWeb, $theNewTopic, $theAttachment
        )
      )
    {
        $session->{response}->header(
            -status => "409 Conflict Target attachment already exists" );
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

