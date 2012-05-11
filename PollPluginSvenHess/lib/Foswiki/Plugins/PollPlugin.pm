# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009 Sven Hess, shess@seibert-media.net
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

package Foswiki::Plugins::PollPlugin;

use strict;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version

use vars qw(%pollUser %pollLog %config);

our $VERSION           = '$Rev: 3048 (2009-03-12) $';
our $RELEASE           = 'v1.0';
our $SHORTDESCRIPTION  = 'Setup polls for voting on topics.';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # get name of current wiki user
    $config{USER} = $user;

    # register handler for enabling votings
    Foswiki::Func::registerTagHandler( 'POLL', \&_poll );

    # register handler for creating a vote configuration
    Foswiki::Func::registerTagHandler( 'POLLSETUP', \&_pollsetup );

    # register REST handler for saving votes
    Foswiki::Func::registerRESTHandler( 'savevote', \&_restSaveVote );

    # Plugin correctly initialized
    return 1;
}

# creates necessary configuration tables
# and saves to current topic
sub _pollsetup {
    my ( $session, $params, $topic, $webName ) = @_;

    my ( $meta, $topicdata ) = Foswiki::Func::readTopic( $webName, $topic );

    my $plugin_conf_table = "*Poll setup*";
    $plugin_conf_table .= "\n<!-- DO NOT CHANGE TABLE ORDER -->";
    $plugin_conf_table .=
      "\n| *username* | *credit points* | *latest vote* | *comment* |\n";
    $plugin_conf_table .= "| Main.ExampleUser | 20 | - | please edit me |\n\n";

    my $plugin_log_table = "*Poll log*";
    $plugin_log_table .= "\n<!-- DO NOT EDIT THIS TABLE -->";
    $plugin_log_table .=
      "\n| *date* | *username* | *topic* | *credit points* |\n\n";

    $topicdata =~ s/%POLLSETUP%\s*/$plugin_conf_table$plugin_log_table/mg;

    Foswiki::Func::saveTopic( $webName, $topic, $meta, $topicdata,
        { minor => 1 } );
    _redirect( $webName, $topic );

    return '';
}

# inserts voting form and voting stats
sub _poll {
    my ( $session, $params, $topic, $webName ) = @_;

    my $config_topic = $params->{topic} || $params->{"_DEFAULT"} || $topic;
    my $disable = $params->{disable};

    ( $config{CONFWEB}, $config{CONFTOPIC} ) =
      $Foswiki::Plugins::SESSION->normalizeWebTopicName( '', $config_topic );

    # creates hash of all voters
    _createVoterList();

    # creates hash of all saved votes
    _createPollLog();

    # checks if vote configuration found
    if ( scalar keys %pollUser < 1 ) {

        my $mes = "No configuration found.";
        return _error($mes);
    }

    # checks voting permission of current user
    if ( !exists $pollUser{ $config{USER} } ) {

        my $mes = "";
        return _error($mes);
    }

    my $sum_points = 0;
    my $user_votes = 0;

    # Sum up all votes from user and topic
    while ( my $user = each(%pollLog) ) {

        while ( ( my $date, my $points ) =
            each( %{ $pollLog{$user}{ $webName . "." . $topic } } ) )
        {

            $sum_points += $points;
            $user_votes += $points if ( $user eq $config{USER} );
        }
    }

    # creates voting stats
    my $voting_stats = "| *topic score: $sum_points* || \n";
    $voting_stats .= "| credit points shared: | " . $user_votes . " |\n";
    $voting_stats .=
      "| credit points left: | " . $pollUser{ $config{USER} }{points} . " |\n";

    my $voting_form = '';

    # checks user credits left and voting not disabled
    if ( ( $pollUser{ $config{USER} }{points} > 0 ) && ( $disable ne 1 ) ) {

        # creates voting form
        $voting_form = "| *Vote for it* |";
        $voting_form .=
"*<form action=\"%SCRIPTURLPATH{\"rest/PollPlugin/savevote\"}%\" method=\"post\"><input type=\"text\" size=\"3\" id=\"credits\" name=\"credits\" />";
        $voting_form .=
          " <input type=\"submit\" value=\"vote!\" class=\"foswikiButton\" />";
        $voting_form .=
            " <input type=\"hidden\" value=\"" 
          . $webName . "." 
          . $topic
          . "\" name=\"voted_t\" />";
        $voting_form .=
            " <input type=\"hidden\" value=\""
          . $config{CONFWEB} . "."
          . $config{CONFTOPIC}
          . "\" name=\"conf_t\" />";
        $voting_form .= "</form>* |";
    }

    return $voting_stats . $voting_form;
}

sub _createVoterList {

    # get topic text of configuration topic
    my $topicdata =
      Foswiki::Func::readTopic( $config{CONFWEB}, $config{CONFTOPIC} );

    my $wikiword_p = $Foswiki::regex{wikiWordRegex};
    my $webname_p  = $Foswiki::regex{webNameRegex};

    # extract user configuration for voting and create hash of it
    $topicdata =~
s/^\|\s*($webname_p\.)?($wikiword_p)\s*\|\s*(\d+)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|.*$/_userlistmap($2,$3,$4,$5)/mego;

    return 1;
}

sub _createPollLog {

    # get topic text of configuration topic
    my $topicdata =
      Foswiki::Func::readTopic( $config{CONFWEB}, $config{CONFTOPIC} );

    my $wikiword_p = $Foswiki::regex{wikiWordRegex};
    my $webname_p  = $Foswiki::regex{webNameRegex};

    # extract all votes and create hash of it
    $topicdata =~
s/^\|\s*(.*?)\s*\|\s*($webname_p\.)?($wikiword_p)\s*\|\s*($webname_p\.$wikiword_p)\s*\|\s*(\d+)\s*\|.*$/_logmap($1,$3,$4,$5)/mego;

    return 1;
}

# creates hash of all votes
sub _logmap {
    my ( $date, $user, $topic, $points ) = @_;

    $pollLog{$user}{$topic}{$date} = 0;
    $pollLog{$user}{$topic}{$date} += $points || 0;

    return '';
}

# creates hash of all permitted users
sub _userlistmap {
    my ( $user, $points, $date, $comment ) = @_;

    $pollUser{$user}{points}  = $points  || 0;
    $pollUser{$user}{date}    = $date    || '';
    $pollUser{$user}{comment} = $comment || '';

    return '';
}

# inserts new vote to credit log
sub _updatePollLog {
    my $submitted_credits = $_[0];
    my $voted_topic       = $_[1];
    my $today             = $_[2];
    my $log;
    my $theader;

    my ( $meta, $topicdata ) =
      Foswiki::Func::readTopic( $config{CONFWEB}, $config{CONFTOPIC} );

    if ( $topicdata =~
m/^(\s*\|\s*\*date\*\s*\|\s*\*username\*\s*\|\s*\*topic\*\s*\|\s*\*credit points\*\s*\|)\s*$/mgo
      )
    {

        $theader = $1;
        $log     = $theader
          . "\n| $today | $config{USER} | $voted_topic | $submitted_credits |";
    }

    $theader = quotemeta($theader);

    if ( $topicdata =~ s/^$theader/$log/mgo ) {
        Foswiki::Func::saveTopic( $config{CONFWEB}, $config{CONFTOPIC}, $meta,
            $topicdata );
    }

    return 1;
}

# sets remaining credit points of user
# sets date of recent changes
#
# return 1 - if setting succed
sub _updatePollConfig {
    my $submitted_credits = $_[0];
    my $today             = $_[1];
    my $confentry;

    my ( $meta, $topicdata ) =
      Foswiki::Func::readTopic( $config{CONFWEB}, $config{CONFTOPIC} );
    my $webname_p = $Foswiki::regex{webNameRegex};

    if ( $topicdata =~
m/^(\|\s*($webname_p\.)?$config{USER}\s*\|\s*\d+\s*\|\s*.*?\s*\|\s*.*?\s*\|)\s*$/mgo
      )
    {

        $confentry = $1;

        if ( $confentry =~
m/^\|\s*($webname_p\.)?$config{USER}\s*\|\s*(\d+)\s*\|\s*.*?\s*\|\s*(.*?)\s*\|$/mgo
          )
        {
            my $credits     = $2;
            my $comment     = $3;
            my $new_credits = $credits - $submitted_credits;

            if ( $new_credits < 0 ) {

                return 0;
            }

            $config{USER} = Foswiki::Func::getWikiUserName( $config{USER} );

            $confentry = quotemeta($confentry);
            my $editentry =
              "| $config{USER} | $new_credits | $today | $comment |";

            if ( $topicdata =~ s/$confentry/$editentry/mgo ) {
                Foswiki::Func::saveTopic( $config{CONFWEB}, $config{CONFTOPIC},
                    $meta, $topicdata );
                return 1;
            }
        }
    }

    return 0;
}

# handles rest call 'savevote'
# - saves submitted credits
# - updates credits of voting user
# - redirects to current topic
sub _restSaveVote {
    my ($session) = @_;

    my $query = Foswiki::Func::getCgiQuery();
    return unless $query;

    # get necessary query params
    my $submitted_credits = $query->param('credits');
    my $voted_topic       = $query->param('voted_t');
    my $config_topic      = $query->param('conf_t');

    # validate submitted input
    if (   ( $submitted_credits !~ m/^[1-9]{1}[0-9]*$/i )
        || ( $voted_topic  eq "" )
        || ( $config_topic eq "" ) )
    {

        return _redirect( '', $voted_topic );
    }

    ( $config{CONFWEB}, $config{CONFTOPIC} ) =
      $Foswiki::Plugins::SESSION->normalizeWebTopicName( '', $config_topic );

    # create hash of all voters
    _createVoterList();

    # check if user has permission to vote AND has credit points left
    if (   ( exists $pollUser{ $config{USER} } )
        && ( $pollUser{ $config{USER} }{points} > 0 ) )
    {

        # get current datetime
        my $today = Foswiki::Time::formatTime( time,
            '$day. $month $year - $hours:$minutes:$seconds' );

        # check if updating credits of current user succeeded
        if ( _updatePollConfig( $submitted_credits, $today ) ) {

            # save submitted credits of current user to credit log
            _updatePollLog( $submitted_credits, $voted_topic, $today );
        }
    }

    # redirect to current topic
    return _redirect( '', $voted_topic );
}

# redirects to specific topic
sub _redirect() {
    my ( $voted_web, $voted_topic ) = @_;

    ( $voted_web, $voted_topic ) =
      $Foswiki::Plugins::SESSION->normalizeWebTopicName( $voted_web,
        $voted_topic );

    return Foswiki::Func::redirectCgiQuery( undef,
        Foswiki::Func::getViewUrl( $voted_web, $voted_topic ), 1 );
}

# returns specific error message
sub _error {
    my $mes             = @_[0];
    my $error_label     = "%RED%";
    my $error_label_end = "%ENDCOLOR%";

    return $error_label . $mes . $error_label_end;
}

1;
