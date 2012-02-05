# Foswiki RedirectPlugin
#
# Copyright (C) 2010 Modell Aachen, stoffers@modell-aachen.de
# Copyright (C) 2008 - 2009 Andrew Jones, andrewjones86@gmail.com
# Copyright (C) 2006 Motorola, thomas.weigert@motorola.com
# Copyright (C) 2006 Meredith Lesly, msnomer@spamcop.net
# Copyright (C) 2003 Steve Mokris, smokris@softpixel.com
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

# =========================
package Foswiki::Plugins::RedirectPlugin;

# =========================
use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $pluginName $NO_PREFS_IN_TOPIC );

use strict;

our $VERSION           = '$Rev$';
our $RELEASE           = '1.1';
our $SHORTDESCRIPTION  = 'Create a redirect to another topic or website.';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName        = 'RedirectPlugin';

# =========================
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # this doesn't really have any meaning if we aren't being called as a CGI
    my $query = &Foswiki::Func::getCgiQuery();
    return 0 unless $query;

    Foswiki::Func::registerTagHandler( 'REDIRECT', \&REDIRECT );

    return 1;
}

# =========================
sub REDIRECT {
    my ( $session, $params, $topic, $web ) = @_;

    my $context     = Foswiki::Func::getContext();
    my $newWeb      = $web;
    my $newTopic    = '';
    my $anchor      = '';
    my $queryString = '';
    my $dest        = $params->{'newtopic'} || $params->{_DEFAULT};
    my $group		= $params->{'group'} || 0;
    my $user		= Foswiki::Func::getWikiUserName();
    my $dontCheckDestinationExists = $params->{'dontcheck'} || 0; 

    my $webNameRegex  = Foswiki::Func::getRegularExpression('webNameRegex');
    my $wikiWordRegex = Foswiki::Func::getRegularExpression('wikiWordRegex');
    my $anchorRegex   = Foswiki::Func::getRegularExpression('anchorRegex');

	# Redirect only if user is in user group and group is existing
	if(!$group || Foswiki::Func::isGroupMember($group) )
	{

    # Redirect only on view 
    # Support Codev.ShorterURLs: do not redirect on edit
	    if (   $dest
	        && !$context->{'edit'}
	        && !$context->{'save'}
	        && !$context->{'preview'} )
	    {
	
	        my $query = Foswiki::Func::getCgiQuery();
	
	        my $queryString = "";
	        my $param;
	        foreach my $param ( $query->param ) {
	            foreach my $value ( $query->param("$param") ) {
	                $queryString .= "&" if $queryString;
	                $queryString .= "$param=" . $value;
	            }
	        }
	
	        # do not redirect when param "redirect=no" is passed
	        my $noredirect = $query->param( -name => 'noredirect' ) || '';
	        return '' if $noredirect eq 'on';
	
	        $dest = Foswiki::Func::expandCommonVariables( $dest, $topic, $web );
	
	        # redirect to URL
	        if ( $dest =~ m/^http/ ) {
	
	            return "%BR% %RED% Cannot redirect to current topic %ENDCOLOR%"
	              if ( $dest eq Foswiki::Func::getViewUrl( $web, $topic ) );
	            Foswiki::Func::redirectCgiQuery( $query, $dest );
	            return '';
	        }
	
	        # else: "topic" or "web.topic" notation
	        # get the components and check if the topic exists
	        my $topicLocation = "";
	        if ( $dest =~ /^((.*?)\.)*(.*?)(\#.*|\?.*|$)$/ ) {
	            $newWeb = $2 || $web || '';
	            $newTopic = $3 || '';
	
	            # ignore anchor and params here
	            $topicLocation = "$newWeb.$newTopic";
	        }
	
	        return "%BR% %RED% Cannot redirect to current topic %ENDCOLOR%"
	          if ( $topicLocation eq "$web.$topic" );
	        return "%BR% %RED% Cannot redirect to an already visited topic %ENDCOLOR%"
	          if ( $queryString =~ /redirectedfrom=$topicLocation/ );
	
	        unless ($dontCheckDestinationExists) { 
		    if ( !Foswiki::Func::topicExists( undef, $topicLocation ) ) {
			return
			    "%RED% Could not redirect to topic $topicLocation (the topic does not seem to exist) %ENDCOLOR%";
		    }
		}
	
	        if ( $dest =~ /($anchorRegex)/ ) {
	            $anchor = $1;
	        }
	
	        if ( $dest =~ /(\?.*)/ ) {
	
	            #override url params
	            $queryString = $1;
	        }
	
	        # AndrewJones: allow us to use %<nop>URLPARAM{redirectfrom}%
	        # in destination topic to display Wikipedia like "Redirected
	        # from ..." text
	        my $q = "?redirectedfrom=$web.$topic";
	        $q .= "&" . $queryString if $queryString;
	
	        # topic exists
	        Foswiki::Func::redirectCgiQuery( $query,
	            Foswiki::Func::getViewUrl( $newWeb, $newTopic ) . $anchor . $q );
	
	    }
	}

    return '';

}

1;
