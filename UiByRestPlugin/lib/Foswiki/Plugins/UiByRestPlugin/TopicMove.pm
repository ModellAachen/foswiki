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

package Foswiki::Plugins::UiByRestPlugin::TopicMove;

use strict;
use warnings;
use Error qw(:try);

# the template which is generally used for this action
my $templatename = "movetopic";

=begin TML

---++ do( $session )
This is a partial wrapper substitute for the rename bin script.

It checks the prerequisites and sets the following status codes:
400 : url parameter(s) are missing
400 : newtopic is not valid (non) wikiword
401 : access denied for unauthorized user
403 : the user is not allowed to RENAME the topic
404 : the source topic does not exist
409 : the target topic already exists

Return:
In case of an error, the renametopic template is returned.
In case of no error, the Manage:rename() method is invoked,
which will take further (url) parameters and may end in a redirect.

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

    # check topic parameter first; if not set, the rest is irrelevant
    if ( !$isSetTopic ) {
        $session->{response}->status("400 Missing parameter: topic");
        return _showTemplate( $theTopic, $theWeb, $theSkin, $templatename );
    }

    # check if topic exists
    if ( !Foswiki::Func::topicExists( $theWeb, $theTopic ) ) {
        $session->{response}->status("404 Topic not found");
        return _showTemplate( $theTopic, $theWeb, $theSkin, $templatename );
    }

    # check permission
    if (
        !Foswiki::Func::checkAccessPermission(
            "RENAME", $theUser, undef, $theTopic, $theWeb, undef
        )
      )
    {
        if ( $theUser eq $Foswiki::cfg{DefaultUserWikiName} ) {
            $session->{response}->status("401 Unauthorized");
            return _showTemplate( $theTopic, $theWeb, $theSkin, "login" );
        }

        # else
        $session->{response}->status("403 Forbidden to rename this topic");
        return _showTemplate( $theTopic, $theWeb, $theSkin, $templatename );
    }

    return 0;
}

sub _softPrecondition {
    my $session  = shift;
    my $query    = $session->{cgiQuery};
    my $theTopic = $session->{topicName};
    my $theWeb   = $session->{webName};
    my $theSkin  = $query->param("skin")
      || Foswiki::Func::getSkin();    # SMELL: should be sanatized
    my $theNewTopic = $query->param("newtopic")
      || undef;                       # SMELL: should be sanatized

    my @missing = ();
    if ( !defined($theNewTopic) ) { push( @missing, "newtopic" ) }

    # check if we miss parameters
    if ( scalar(@missing) > 0 ) {
        $session->{response}
          ->status( "400 Missing parameter: " . join( ",", @missing ) );
        return _showTemplate( $theTopic, $theWeb, $theSkin, $templatename );
    }

    # former Foswiki::UI::Manage::_safeTopicname()
    $theNewTopic =~ s/\s//go;
    $theNewTopic = ucfirst $theNewTopic;    # Item3270
    $theNewTopic =~ s![./]!_!g;
    $theNewTopic =~ s/($Foswiki::cfg{NameFilter})//go;

    # does the newtopic met the optional nonwikiword requirement?
    if (
        !Foswiki::Func::isValidTopicName(
            $theNewTopic, Foswiki::isTrue( $query->param('nonwikiword') )
        )
      )
    {
        $session->{response}->status("400 Not valid: newtopic");
        return _showTemplate( $theTopic, $theWeb, $theSkin, $templatename );
    }

    # does newtopic already exists?
    if ( Foswiki::Func::topicExists( $theWeb, $theNewTopic ) ) {
        $session->{response}
          ->status("409 Conflict Target topic already exists");
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

