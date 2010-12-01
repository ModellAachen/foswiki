# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Query

provide a REST based CRUD API to foswiki objects using the Query language as the addressing scheme.

=cut

package Foswiki::UI::Query;

use strict;
use warnings;
use Assert;
use Foswiki            ();
use Foswiki::Serialise ();
use Foswiki::Query::Parser;
use Foswiki::Infix::Error ();

use Time::HiRes ();
use REST::Utils qw( :all );
use Error qw( :try );

#map MIME type to serialiseFunctions
our %serialiseFunctions = (
    'text/json' => 'Foswiki::Serialise::json',
    'text/perl' => 'Foswiki::Serialise::perl',

    #'text/html' => 'Foswiki::Serialise::html',
    'text/plain' => 'Foswiki::Serialise::raw',

    #'application/x-www-form-urlencoded' => ''
);

sub workoutSerialisation {
    my $query         = shift;
    my $url_mediatype = shift;

    #a URL specified mediatype will over-ride the request header one..
    if ( defined($url_mediatype) ) {
        $url_mediatype =~ s/^\.//;

#known shorcuts..
#TODO: EXTRACT and add registerable bits for plugins can add their own - ie, any one of the Pdf plugins can add a .pdf
        my %extensions = (
            json => 'text/json',
            perl => 'text/perl',
            html => "text/html",
            text => "text/plain"
        );
        $url_mediatype = $extensions{$url_mediatype};
        return $url_mediatype if ( defined($url_mediatype) );
    }

    my @supportedContentTypes = keys(%serialiseFunctions);

    #try out REST::Utils::media_type
    my $prefered = REST::Utils::media_type( $query, @supportedContentTypes );
    $prefered = 'text/json'
      if ( not defined($prefered) or ( $prefered eq '' ) );
    ASSERT($prefered) if DEBUG;
    return $prefered;
}

sub mapMimeType {
    my $ContentType = shift;

    return $serialiseFunctions{$ContentType};
}

#WARNING: danger will-robinson - remember that the typical size limit on a payload is 2MB
#TODO: redo the payloads to be _just_ the item, and plonk everything else in the header.
#       that way we can do: curl -X PATCH -d "{fieldName: 'value to set to'}" http://x61/bin/query/Main/SvenDowideit/topic.json

#TODO: work out how to apply the contentType to EngineExceptions..

#don't reply to PUT/POST/PATCH with the changed item, send a 303 (assuming we're allowed to) so that we cna simplify the code..
#generalise into container and endpoint ops / elements
#implement a text/tml seiralisation that uses the http header  for all the non-topic info (same again with text/html
#js UI and class to interact with this - the UI creates a new html form foreach element - so we can then post/patch/whtever
#    add tunneling option etc
#    then use that for selenium... so i can test auth via apache/template and the different strikeone's .....

sub query {
    my ( $session, %initialContext ) = @_;

    my $req = $session->{request};
    my $res = $session->{response};
    my $err;

  #support tunneling of requests using X-HTTP-METHOD-OVERRIDE or ?_method=DELETE
    my $request_method = uc( REST::Utils::request_method($req) );

#REST::Utils doesn't seem to cope with the shenanigans we pull when running from UIFn unit tests / commandline.
    $request_method = uc( $req->method() )
      if ( not defined($request_method) or ( $request_method eq '' ) );

    #TODO: detect commandline use and set to GET / $ENV{FOSWIKI_ACTION}, or...
    $request_method = 'GET'
      if ( $request_method eq 'QUERY' )
      ;  #TODO: for some reason the cmdline method is returning the script name.
         #make sure we're doing a suported HTTP op
    unless ( $request_method =~ /(GET|PUT|POST|PATCH|DELETE)/ ) {
        $res->header( -type => 'text/html', -status => '400' );
        $err =
"ERROR: (400) Invalid query invocation - unsupported HTTP method $request_method";
        $res->print($err);
        throw Foswiki::EngineException( 400, $err, $res );
    }

    authenticate($session);
    print STDERR "after auth\n";

#delegate to POSTquery
#return POSTquery($session, %initialContext) if ($request_method eq 'POST');
#Rest and View have a pageCache->getPage, which could be extracted and reused for some GET ops.

    my $pathInfo = $req->path_info();

    #query requests have the form 'Query/element[.mediatype]'
    unless ( $pathInfo =~ m#^(.*)/([^./]*)(\..*)?$# ) {

        $res->header( -type => 'text/html', -status => '400' );
        $err = "ERROR: (400) Invalid query invocation - $pathInfo is malformed";
        $res->print($err);
        throw Foswiki::EngineException( 400, $err, $res );
    }
    my ( $query, $elementAlias, $url_mediatype ) = ( $1, $2, $3 );
    print STDERR "---- elementAlias: $elementAlias\n";

    #find the best mediatype
    #a URL specified mediatype will over-ride the request header one..
    my $responseContentType = workoutSerialisation( $req, $url_mediatype );
    print STDERR
      "---- responseContentType: $responseContentType (was $url_mediatype)\n";

    #validate alias
    #TODO: there appear to me other 'aliases' defined in QueryAlgo::getField..
    unless ( ( $elementAlias =~ /^(webs|web|topic|text|name)$/ )
        or ( defined( $Foswiki::Meta::aliases{$elementAlias} ) ) )
    {
        $res->header( -type => 'text/html', -status => '400' );
        $err =
"ERROR: (400) Invalid query invocation - unsupported element requested: $elementAlias";
        $res->print($err);
        throw Foswiki::EngineException( 400, $err, $res );
    }

    #validate query
    #ensure we have the authorisation to do what we're requesting
    $session->logEvent( 'query', $query,
        "$elementAlias, $responseContentType" );

##############################
# begin with the presumption that all queries are the simplified 'http://server/query/System/WebHome/alias.ext' type..
    my ( $web, $topic, $baseObjectExists );
    if ( $query =~ /^\/?(.*)\/(.*?)$/ ) {
        $web   = $1;
        $topic = $2;

        #TODO: nasty hack to stop webs/topics from starting with a /
        $web   =~ s/^\/*//;
        $topic =~ s/^\/*//;
        $query =~ s/^\/*//;

#TODO: actually, this parsing has to work diferently for POST, as the uri in POST's refer to the container (and so a cntextural on the elementAlias
        if ( $elementAlias eq 'webs' ) {

#base webs $query ~~ '', otherwise, if it is defined, then we're making a new subweb..
            $topic = undef;
            $web   = $query;
            $baseObjectExists =
              ( ( $web eq '' ) or Foswiki::Func::webExists($web) );

            #$elementAlias = 'hash';    # if ( $elementAlias eq 'webs' );
            $query = "'$web'/$elementAlias";
        }
        elsif ( $elementAlias eq 'topic' ) {

#I created a quick hack in the QueryAlgo::getField so that element 'hash' returned the meta object
#need to map topic==hash
            $baseObjectExists =
              (       Foswiki::Func::webExists($web)
                  and Foswiki::Func::topicExists( $web, $topic ) );

            #$elementAlias = 'hash';# if ( $elementAlias eq 'topic' );
            $query = "'$web.$topic'/$elementAlias";
        }
        else {

            #attachments are to a topic, so the simple regex above is ok
            $baseObjectExists =
              (       Foswiki::Func::webExists($web)
                  and Foswiki::Func::topicExists( $web, $topic ) );
            $query = "'$web.$topic'/$elementAlias";
        }

    }
    else {
        die 'not implemented';
    }

#need to test if this topic exists, as Meta->new currently returns an obj, even if the web, or the topic don't exist. totally yuck.
#TODO: note that if we're PUT-ing and the item does not exist, we're basically POSTing, but to a static URI, not to a collection.
    if ( not $baseObjectExists ) {
        $res->header( -type => 'text/html', -status => '404' );
        $err =
"ERROR: (401) Invalid query invocation - web or topic do not exist ($web . $topic)";
        $res->print($err);
        throw Foswiki::EngineException( 404, $err, $res );
    }
    my $topicObject = Foswiki::Meta->new( $session, $web, $topic );
    print STDERR "---- actual Meta ("
      . $topicObject->web . ", "
      . ( $topicObject->topic || '' ) . ")\n";

#TODO: this will need ammending when we actually query, as we don't know what topics we're talking about at this point.
    my $accessType = 'CHANGE';
    $accessType = 'VIEW'   if ( $request_method eq 'GET' );
    $accessType = 'RENAME' if ( $request_method eq 'DELETE' );

    if ( not $topicObject->haveAccess($accessType) ) {
        $res->header( -type => 'text/html', -status => '401' );
        $err = "ERROR: (401) $accessType not permitted to ($web . $topic)";
        $res->print($err);
        throw Foswiki::EngineException( 401, $err, $res );
    }

    my $requestContentType = $req->header('Content-Type') || 'text/json';
    my $requestPayload = REST::Utils::get_body($req);
    print STDERR "----------- request_method : ||$request_method||\n";
    print STDERR "----------- query : ||$query||\n";
    print STDERR "----------- requestContentType : ||$requestContentType||\n";
    print STDERR "----------- requestPayload : ||$requestPayload||\n";
    if ( ( $request_method ne 'GET' ) and ( $requestPayload eq '' ) ) {
        print STDERR
          "@@@@@@@@@@@@@@@@@@@@ no payload. writing to /tmp/cgi.out\n";
        open( OUT, '>', '/tmp/cgi.out' );
        $req->save( \*OUT );
        close(OUT);

        #        return '';
    }

    #DOIT
    my $result;
    try {
        my $evalParser = new Foswiki::Query::Parser();
        my $querytxt   = $query;
        $querytxt =~ s/(webs|topic)$/hash/;
        print STDERR "~~~~~~~~~~~~~~~~~~~~~~~$querytxt\n";
        my $node = $evalParser->parse($querytxt);

        #time it.
        my $startTime = [Time::HiRes::gettimeofday];
        $result = $node->evaluate( tom => $topicObject, data => $topicObject );
        if ( $request_method eq 'GET' ) {

            #it just gets..
        }
        elsif ( $request_method eq 'PUT' ) {
            die 'not implemented';
        }
        elsif ( $request_method eq 'PATCH' ) {
            ASSERT( $requestPayload ne '' ) if DEBUG;
            my $value =
              Foswiki::Serialise::deserialise( $session, $requestPayload,
                mapMimeType($requestContentType) );
            copyFrom( $topicObject, $value );    #copy meta..

#print STDERR ")))))".Foswiki::Serialise::serialise( $session, $value, 'perl' )."(((((\n";
            $topicObject->text( $value->{_text} )
              if ( defined( $value->{_text} ) );
            $topicObject->save();
        }
        elsif ( $request_method eq 'POST' ) {
            ASSERT( $requestPayload ne '' ) if DEBUG;

#TODO: er, sorry, POST uri should be the web that the new topic will be made in...
            my $value =
              Foswiki::Serialise::deserialise( $session, $requestPayload,
                mapMimeType($requestContentType) );

            #TODO: mmm, very much presuming we're creating a topic.
            require Foswiki::UI::Save;
            $topic =
              Foswiki::UI::Save::expandAUTOINC( $session, $web,
                $value->{_topic} );

            #new topic...
            $topicObject = Foswiki::Meta->new( $session, $web, $topic );

            copyFrom( $topicObject, $value );
            $topicObject->text( $value->{_text} )
              if ( defined( $value->{_text} ) );
            $topicObject->save();

    #if we created something and are returning it, and a uri for it, status=201
    #need a location header
    #if we created something, but are not returning it, then status = 200 or 204
    #could use 303 to redirect to the created resource too..?
            $res->status('201 OK');

#TODO: yes, needs to detect what we're creating and change the element alias appropriatly.
            $res->pushHeader( 'Location',
                getResourceURI( $topicObject, 'topic' ) );
        }
        elsif ( $request_method eq 'DELETE' ) {
            die 'not implemented';
        }
        else {

            #throw something  - this should have been noticed before
            die 'not implemented';
        }
        if ( $result->isa('Foswiki::Meta') ) {
            $result = Foswiki::Serialise::convertMeta($result);
        }

#TODO: the elementAlias and query != what was requested - it should be what is returned (for eg, POST is the item, not the container

        #end timer
        my $endTime = [Time::HiRes::gettimeofday];
        my $timeDiff = Time::HiRes::tv_interval( $startTime, $endTime );

     #push this into the HTTP header, as the HTTP payload _is_ the resource data
        my $header_info = {
            query     => $query,
            element   => $elementAlias,
            mediatype => $responseContentType,
            action    => $request_method,
            rev       => '',
            startTime => $startTime,
            endTime   => $endTime,
            time      => $timeDiff,
        };
        map { $res->pushHeader( 'X-Foswiki-REST-' . $_, $header_info->{$_} ) }
          keys(%$header_info);
        $result =
          Foswiki::Serialise::serialise( $session, $result,
            mapMimeType($responseContentType) );
    }
    catch Foswiki::Infix::Error with {
        my $e = shift;
        $result = $e->{-text};
        $res->status( '500 ' . $result );
    }
    finally {};

    #these will be processed and selected..
    print STDERR "--------result ($result)\n";

    _writeCompletePage( $session, $result, 'view', $responseContentType );
}

sub getResourceURI {
    my $meta         = shift;
    my $elementAlias = shift;    #TODO: derive this from the meta..

    print STDERR "getResourceURI - getScriptUrl("
      . $meta->web . ", "
      . $meta->topic
      . ", 'query')\n";

    #TODO: er, and what about attchments?
    #TODO: and allow mimetype to be added later
    return Foswiki::Func::getScriptUrl( $meta->web, $meta->topic, 'query' )
      . "/$elementAlias";
}

sub _writeCompletePage {
    my ( $session, $text, $pageType, $responseContentType ) = @_;

#TODO: because writeCompletePage is badly broken by renderZones and other new cruft, I have to re-implement it here
#$session->writeCompletePage($result, $pageType, $responseContentType);

#not sure its a good idea to run the completePageHandler, but i'm sure its not a goot idea not to run it :/
#    my $hdr = "Content-type: " . $responseContentType . "\r\n";
# Call final handler
#    $session->{plugins}->dispatch( 'completePageHandler', $text, $hdr );

    my $cachedPage;
    $session->generateHTTPHeaders( $pageType, $responseContentType, $text,
        $cachedPage );
    print STDERR $session->{response}->printHeaders()
      ;    #these are not printed for cmdline..
    $session->{response}->print($text);
}

#thows an exception if something isn't right.
sub authenticate {
    my $session = shift;
    my $req     = $session->{request};
    my $res     = $session->{response};
    my $err;

    # If there's login info, try and apply it
    my $login = $req->param('username');
    if ($login) {
        my $pass = $req->param('password');
        my $validation = $session->{users}->checkPassword( $login, $pass );
        unless ($validation) {
            $res->header( -type => 'text/html', -status => '401' );
            $err = "ERROR: (401) Can't login as $login";
            $res->print($err);
            throw Foswiki::EngineException( 401, $err, $res );
        }

        my $cUID     = $session->{users}->getCanonicalUserID($login);
        my $WikiName = $session->{users}->getWikiName($cUID);
        $session->{users}->getLoginManager()->userLoggedIn( $login, $WikiName );
    }

    # Check that the script is authorised under the standard
    # {AuthScripts} contract
    try {
        $session->getLoginManager()->checkAccess();
    }
    catch Error with {
        my $e = shift;
        $res->header( -type => 'text/html', -status => '401' );
        $err = "ERROR: (401) $e";
        $res->print($err);
        throw Foswiki::EngineException( 401, $err, $res );
    };
}

########################
#yes, this is a simplified copy from Foswiki::Meta::copyFrom so we can copy from a random hashref
#TODO: this is not a PUT/POST, its a PATCH.
sub copyFrom {
    my ( $meta, $other, $type, $filter ) = @_;

    #ASSERT( $meta->{_web} && $meta->{_topic}, '$this is not a topic object' )
    #  if DEBUG;
    #ASSERT( $other->isa('Foswiki::Meta') && $other->{_web} && $other->{_topic},
    #    'other is not a topic object' )
    #  if DEBUG;

    if ($type) {
        return if $type =~ /^_/;
        my @data;
        foreach my $item ( @{ $other->{$type} } ) {
            if ( !$filter
                || ( $item->{name} && $item->{name} =~ /$filter/ ) )
            {
                my %datum = %$item;
                push( @data, \%datum );
            }
        }
        print STDERR "--------------actually modifying $type..\n";
        $meta->putAll( $type, @data );
    }
    else {
        foreach my $k ( keys %$other ) {
            unless ( $k =~ /^_/ ) {
                copyFrom( $meta, $other, $k );
            }
        }
    }
}

{

    package Foswiki::Serialise;

    #TODO: have to work out what these are, and how they come out..
    sub html {
        my ( $session, $result ) = @_;
        my ( $web, $topic );
        $result = Foswiki::Func::renderText( $result, $web, $topic );
        return $result;
    }

    sub raw {
        my ( $session, $result ) = @_;
        my ( $web, $topic );
        $result = Foswiki::Func::renderText( $result, $web, $topic );
        return $result;
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

author: SvenDowideit@fosiki.com