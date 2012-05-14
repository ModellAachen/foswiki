package RestPluginCurlTests;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );
use strict;

use Foswiki ();
use Foswiki::Func();
use Foswiki::Meta      ();
use Foswiki::Serialise ();
use JSON               ();
use File::Path qw(mkpath);

use constant MONITOR => 0;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub list_tests {
    my ( $this, $suite ) = @_;
    my @set = $this->SUPER::list_tests($suite);

    my $curlError = `curl 2>&1`;
    if (
        not( $curlError =~
            /curl: try 'curl --help' or 'curl --manual' for more information/ )
      )
    {
        print STDERR
          "curl not installed and in path, skipping curl based tests\n";
        return;
    }
    return @set;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "Improvement2" );
    $meta->putKeyed(
        'FIELD',
        {
            name  => 'Summary',
            title => 'Summary',
            value => 'Its not broken, but its really painful to use'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name  => 'Details',
            title => 'Details',
            value => 'work it out yourself!'
        }
    );
    Foswiki::Func::saveTopic(
        $this->{test_web}, "Improvement2", $meta, "
typically, a spade made with a thorny handle is functional, but not ideal.
"
    );
    Foswiki::Func::saveTopic(
        $this->{test_web}, "SomeAttachments", $meta, "
typically, a spade made with a thorny handle is functional, but not ideal.
   * Set ALLOWTOPICCHANGE = guest
   
%META:FILEATTACHMENT{name=\"favicon.ico\" attachment=\"favicon.ico\" attr=\"\" comment=\"\" date=\"1227691956\" path=\"favicon.ico\" size=\"1150\" user=\"ProjectContributor\" version=\"1\"}%
"
    );
    my $webData = Foswiki::Func::getDataDir() . '/' . $this->{test_web};
    my $webPub =
        Foswiki::Func::getPubDir() . '/'
      . $this->{test_web}
      . '/SomeAttachments/';
    my $attachment = $webPub . 'favicon.ico';
    print STDERR "chmod -R 777 $webData; touch $attachment returned: "
      . `mkdir -p $webPub ; chmod 777 $webPub; touch $attachment ; chmod 777 $attachment`;

#TODO: implementme - tbh, we need something simple in Func to attache existat files..
#    $this->addAttachmentsToTopic( $this->{test_web}, 'SomeAttachments',
#        ( 'one.txt', 'two.txt', 'inc/file.txt' ) );
}

sub callCurl {
    my $self               = shift;
    my $httpRequest        = shift;
    my $requestContentType = shift;
    my $requestContent     = shift;
    my $url                = shift;
    my $login              = shift;
    my $password           = shift;

    my $authOption = '';
    $authOption = " -u $login:$password "
      if ( defined($login) and defined($password) );

#curl -X PATCH -H "Content-Type:text/json" -d '{"_text": "set the topic text to something new again"}' http://x61/f/bin/query/Main/SvenDowideit/topic.json
#curl -X PATCH -H "Content-Type:text/json" -d '{"_text": "set the topic text to something new again"}' http://x61/f/bin/query/Main/SvenDowideit/topic.json
    my $curlCommand =
        'curl -s --trace-time -v -X '
      . $httpRequest
      . $authOption
      . ' -H "Content-Type:'
      . $requestContentType
      . '" -d \''
      . $requestContent . '\' '
      . $url;

    print STDERR "\n\n----\n$curlCommand\n----\n" if MONITOR;
    my $result = `$curlCommand 2>&1`
      ;    # grrrr, aparently they output the header info into stderr

    #now separate into headers and content.
    #14:48:54.853392 * Connected to x61 (127.0.1.1) port 80 (#0)
    #14:48:54.853517 > GET

    my $data = { '*' => '', '>' => '', '<' => '', '{' => '' };
    $result =~
s/(\d\d:\d\d:\d\d\.\d\d\d\d\d\d) ([<*>{}]) (.*)(\r\n)/addToResultHash($1, $2, $3, $data)/gem;

#argh. \r?\n isn't working for me, so i'll just run the regex twice until i get enough sleep to have a clue.
    $result =~
s/(\d\d:\d\d:\d\d\.\d\d\d\d\d\d) ([<*>{}]) (.*)(\n)/addToResultHash($1, $2, $3, $data)/gem;

    #print STDERR "\n================\n$result\n==========\n";

    print STDERR join( "\n-----------------\n",
        ( $result, $data->{'*'}, $data->{'>'}, $data->{'<'} ) )
      if MONITOR;

    return ( $result, $data );
}

sub addToResultHash {
    my ( $timestamp, $type, $text, $hash ) = @_;

    $hash->{$type} .= "$timestamp $type $text\n";
    if ( $type eq '<' ) {    #response header
                             #HTTP/1.1 200 OK
        if ( $text =~ /HTTP\/1.1\s(\d*)\s(.*)/ ) {
            $hash->{HTTP_RESPONSE_STATUS}      = $1;
            $hash->{HTTP_RESPONSE_STATUS_TEXT} = $2;
        }

        #X-Foswiki-Rest-Query: 'Main.SvenDowideit'/topic etc
        if ( $text =~ /(.*?):\s*(.*)/ ) {
            $hash->{$1} = $2;
        }
    }

    return '';
}

sub runTest {
    my (
        $this,         $OP,                   $sendType,
        $sendPayload,  $web,                  $topic,
        $attachment,   $element,              $receiveType,
        $expectedHash, $expectedReplyPayload, $login,
        $password
    ) = @_;

    #my $query = '/' . $web . '/' . $topic . '/' . $element;
    my @path;
    push( @path, $web )   if ( defined($web)   and ( $web   ne '' ) );
    push( @path, $topic ) if ( defined($topic) and ( $topic ne '' ) );
    push( @path, $attachment )
      if ( defined($attachment) and ( $attachment ne '' ) );
    push( @path, $element ) if ( defined($element) and ( $element ne '' ) );
    my $query = '/' . join( '/', @path );

    my ( $replytext, $extraHash ) = $this->callCurl(
        $OP,
        $sendType,
        $sendPayload,
        Foswiki::Func::getScriptUrl( undef, undef, 'query' ) 
          . $query . '.'
          . $receiveType,
        $login,
        $password
    );

    foreach my $key ( sort keys(%$expectedHash) ) {

        #if scalar..
        $this->assert_equals( $expectedHash->{$key}, $extraHash->{$key} );
    }

    #    $this->assert_matches( qr/^(topic|attachments)$/, $element,
    #        'only topic element implemented below' );
    $this->assert_equals( 'json', $receiveType, 'only JSON implemented below' );

    if ( defined($expectedReplyPayload) ) {

        $expectedReplyPayload =~
          s/date=\\"(.*?)\\"/date=\\"EXTRACTED_FOR_TESTING\\"/g;
        $expectedReplyPayload =~
          s/"date":(.*?),/"date":"EXTRACTED_FOR_TESTING",/g;

        #"date":1291604486,
        $replytext =~ s/date=\\"(.*?)\\"/date=\\"EXTRACTED_FOR_TESTING\\"/g;
        $replytext =~ s/"date":(.*?),/"date":"EXTRACTED_FOR_TESTING",/g;

        print STDERR "\njson expected:\n"  if MONITOR;
        print STDERR $expectedReplyPayload if MONITOR;
        print STDERR "\njson got:\n"       if MONITOR;
        print STDERR $replytext            if MONITOR;
        my $replyObj =
          Foswiki::Serialise::deserialise( $this->{session}, $replytext,
            'json' );
        my $expectedObj =
          Foswiki::Serialise::deserialise( $this->{session},
            $expectedReplyPayload, 'json' );
        $this->assert_deep_equals( $expectedObj, $replyObj );

        #TODO: can also compare to the meta obj we get??
        #my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
        #$this->assert_deep_equals( convertMETA($meta), $replyObj );
    }

}

sub test_create_web_noauth {
    my $this = shift;

    my $newWeb = 'RestPluginCurlWeb';
    $this->runTest(
        'POST',
        'text/json',
        '{
                "baseweb"    : "_default",
                "newweb"     : "' . $newWeb . '",
                "webbgcolor" : "#22ff22",
                "websummary" : "another subweb created by query REST AP"
            }',
        '', '', '', 'webs', 'json',
        {
            HTTP_RESPONSE_STATUS      => '401',
            HTTP_RESPONSE_STATUS_TEXT => 'Authorization Required',

#            'X-Foswiki-Rest-Query'    => '\'RestPluginCurlWeb\'/webs',
#            'Location'   => Foswiki::Func::getScriptUrl( undef, undef, 'query' ) .'/RestPluginCurlWeb/webs',
        },
        undef
    );

    $this->assert( not Foswiki::Func::webExists($newWeb) );

    #    $this->assert_equals( '#22ff22',
    #        Foswiki::Func::getPreferencesValue( 'WEBBGCOLOR', $newWeb ) );
    #    $this->assert_equals( 'web created by query REST API',
    #        Foswiki::Func::getPreferencesValue( 'WEBSUMMARY', $newWeb ) );

    $newWeb = 'Sandbox/Subweb';
    $this->runTest(
        'POST',
        'text/json',
        '{
                "baseweb"    : "_default",
                "newweb"     : "' . $newWeb . '",
                "webbgcolor" : "#22ff22",
                "websummary" : "subweb created by query REST API"
            }',
        '', '', '', 'webs', 'json',
        {
            HTTP_RESPONSE_STATUS      => '401',
            HTTP_RESPONSE_STATUS_TEXT => 'Authorization Required',

#            'X-Foswiki-Rest-Query'    => '\'RestPluginCurlWeb\'/webs',
#            'Location'   => Foswiki::Func::getScriptUrl( undef, undef, 'query' ) .'/RestPluginCurlWeb/Subweb/webs',
        },
        undef
    );

    #this should fail..
    $newWeb = 'NotThereRestPluginCurlWeb/Subweb';
    $this->runTest(
        'POST',
        'text/json',
        '{
                "baseweb"    : "_default",
                "newweb"     : "' . $newWeb . '",
                "webbgcolor" : "#22ff22",
                "websummary" : "subweb created by query REST API"
            }',
        '', '', '', 'webs', 'json',
        {
            HTTP_RESPONSE_STATUS      => '401',
            HTTP_RESPONSE_STATUS_TEXT => 'Authorization Required',

#            'X-Foswiki-Rest-Query'    => '\'RestPluginCurlWeb\'/webs',
#            'Location'   => Foswiki::Func::getScriptUrl( undef, undef, 'query' ) .'/RestPluginCurlWeb/Subweb/webs',
        },
        undef
    );
}

sub testGET_topiclist {
    my $this = shift;

    {    #(list of topics...)
            #/Main/topic.json
        my ( $replytext, $extraHash ) = $this->callCurl( 'GET', 'text/json', '',
            Foswiki::Func::getScriptUrl( undef, undef, 'query' )
              . '/Main/topic.json' );

        #print STDERR $replytext;
        my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        my @topicList =
          map { { '_topic' => $_ } } Foswiki::Func::getTopicList('Main');
        $this->assert_deep_equals( $fromJSON, \@topicList );
        $this->assert_equals( '200', $extraHash->{HTTP_RESPONSE_STATUS} );
        $this->assert_equals( 'OK',  $extraHash->{HTTP_RESPONSE_STATUS_TEXT} );
        $this->assert_equals( "'Main'/topic",
            $extraHash->{'X-Foswiki-Rest-Query'} );

        #TODO: test the other values we're returning
    }

}

sub testGET {
    my $this = shift;
    {

        #/Main/WebHome/topic.json
        my ( $replytext, $extraHash ) = $this->callCurl( 'GET', 'text/json', '',
            Foswiki::Func::getScriptUrl( undef, undef, 'query' )
              . '/Main/WebHome/topic.json' );

        #print STDERR $replytext;
        my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        my ( $meta, $text ) = Foswiki::Func::readTopic( 'Main', 'WebHome' );
        $this->assert_deep_equals( $fromJSON,
            Foswiki::Serialise::convertMeta($meta) );
        $this->assert_equals( '200', $extraHash->{HTTP_RESPONSE_STATUS} );
        $this->assert_equals( 'OK',  $extraHash->{HTTP_RESPONSE_STATUS_TEXT} );
        $this->assert_equals( "'Main.WebHome'/topic",
            $extraHash->{'X-Foswiki-Rest-Query'} );

        #TODO: test the other values we're returning
    }

    {

        #/Main/TopicDoesNotTexit/topic.json
        my ( $replytext, $extraHash ) = $this->callCurl( 'GET', 'text/json', '',
            Foswiki::Func::getScriptUrl( undef, undef, 'query' )
              . '/Main/TopicDoesNotTexit/topic.json' );

        #no payload
        #        $this->assert_deep_equals( $fromJSON,
        #            Foswiki::Serialise::convertMeta($meta) );
        $this->assert_equals( '404', $extraHash->{HTTP_RESPONSE_STATUS} );
        $this->assert_equals( 'Not Found',
            $extraHash->{HTTP_RESPONSE_STATUS_TEXT} );
        $this->assert_equals(
            undef,

            #"'Main.TopicDoesNotTexit'/topic",
            $extraHash->{'X-Foswiki-Rest-Query'}
        );

        #TODO: test the other values we're returning
    }

}

sub testPATCH {
    my $this = shift;

   #THIS MUST FAIL, guest should never have the ability to change System.WebHome
   #/System/WebHome/topic.json
    $this->runTest(
        'PATCH',
        'text/json',
        '{"_text": "Some text"}',
        'System',
        'WebHome',
        '', 'topic', 'json',
        {
            HTTP_RESPONSE_STATUS      => '401',
            HTTP_RESPONSE_STATUS_TEXT => 'Authorization Required',
            'X-Foswiki-Rest-Query'    => undef,
        }
    );

    $this->runTest(
        'PATCH',
        'text/json',
        '{"_text": "Some text"}',
        'Sandbox',
        'TestTopicAUTOINC001',
        '', 'topic', 'json',
        {
            HTTP_RESPONSE_STATUS      => '404',
            HTTP_RESPONSE_STATUS_TEXT => 'Not Found',
            'X-Foswiki-Rest-Query'    => undef,
        }
    );

#$this->{test_web}, "Improvement2"
#ER POOP. the test web is created with the wrong filesystem user, so can't be accessed by the web server (in some setups.)
    $this->runTest(
        'PATCH',
        'text/json',
        '{"_text": "Some text"}',
        $this->{test_web},
        'Improvement2',
        '', 'topic', 'json',
        {
            HTTP_RESPONSE_STATUS      => '500',
            HTTP_RESPONSE_STATUS_TEXT => 'OK',

#            'X-Foswiki-Rest-Query'    => '\''.$this->{test_web}.'.Improvement2\'/topic',
        }
    );
}

sub test_attachmentsProjectLogos {
    my $this = shift;

    #requesting a list of attachments in the 'container' System.ProjectLogos
    #/System/ProjectLogos/attachment.json
    $this->runTest(
        'GET',
        'text/json',
        '', 'System',
        'ProjectLogos',
        '',
        'attachments',
        'json',
        {
            HTTP_RESPONSE_STATUS      => '200',
            HTTP_RESPONSE_STATUS_TEXT => 'OK',
            'X-Foswiki-Rest-Query'    => '\'System.ProjectLogos\'/attachments',
        },
'[{"attachment":"favicon.ico","version":"1","date":"1227691956","name":"favicon.ico","path":"favicon.ico","attr":"","size":"1150","comment":"","user":"ProjectContributor"},{"attachment":"foswiki-badge.png","version":"2","date":"1227691956","name":"foswiki-badge.gif","path":"foswiki-badge.png","attr":"","size":"4807","comment":"","user":"ProjectContributor"},{"attachment":"foswiki-logo.gif","version":"2","date":"1227691994","name":"foswiki-logo.gif","path":"foswiki-logo.gif","attr":"","size":"7537","comment":"","user":"ProjectContributor"},{"attachment":"foswiki-logo.xcf","version":"1","date":"1227691956","name":"foswiki-logo.xcf","path":"foswiki-logo.xcf","attr":"","size":"45514","user":"ProjectContributor"}]'
    );
}

sub test_attachmentsProjectLogos_favicon_ico {
    my $this = shift;

    #requesting a list of attachments in the 'container' System.ProjectLogos
    #/System/ProjectLogos/attachment.json
    $this->runTest(
        'GET',
        'text/json',
        '', 'System',
        'ProjectLogos',
        'favicon.ico',
        'attachments',
        'json',
        {
            HTTP_RESPONSE_STATUS      => '200',
            HTTP_RESPONSE_STATUS_TEXT => 'OK',
            'X-Foswiki-Rest-Query' =>
              '\'System.ProjectLogos\'/attachments[name=\'favicon.ico\']',
        },
'{"attachment":"favicon.ico","version":"1","date":"1227691956","name":"favicon.ico","path":"favicon.ico","attr":"","size":"1150","comment":"","user":"ProjectContributor"}'
    );

    #lets fail to modify.
    $this->runTest(
        'PATCH',
        'text/json',
'{"attachment":"favicon.ico","version":"1","date":"1227691956","name":"favicon.ico","path":"favicon.ico","attr":"","size":"1150","comment":"Testing comment update.","user":"ProjectContributor"}',
        'System',
        'ProjectLogos',
        'favicon.ico',
        'attachments',
        'json',
        {
            HTTP_RESPONSE_STATUS      => '401',
            HTTP_RESPONSE_STATUS_TEXT => 'Authorization Required',

#            'X-Foswiki-Rest-Query'    => '\'System.ProjectLogos\'/attachments[name=\'favicon.ico\']',
        },
        undef    #its an error, not a payload
    );
}

sub test_attachmentsWebHome {
    my $this = shift;

    #no attachments on topic
    $this->runTest(
        'GET',
        'text/json',
        '', 'System',
        'WebHome',
        '',
        'attachments',
        'json',
        {
            HTTP_RESPONSE_STATUS      => '200',
            HTTP_RESPONSE_STATUS_TEXT => 'OK',
            'X-Foswiki-Rest-Query'    => '\'System.WebHome\'/attachments',
        },
        ''
    );
}

sub test_attachment_modify {
    my $this = shift;

    $this->runTest(
        'POST',
        'text/json',
'{"_topic":"SomeAttachments", "_text":"lets create a topic.\n\n%META:FILEATTACHMENT{name=\"favicon.ico\" attachment=\"favicon.ico\" attr=\"\" comment=\"\" date=\"1227691956\" path=\"favicon.ico\" size=\"1150\" user=\"ProjectContributor\" version=\"1\"}%\n"}',
        'Sandbox',
        '', '', 'topic', 'json',
        {
            HTTP_RESPONSE_STATUS      => '201',
            HTTP_RESPONSE_STATUS_TEXT => 'OK',

#            'X-Foswiki-Rest-Query'    => '\'Sandbox.SomeAttachments\'/attachments',
            'Location' =>
              Foswiki::Func::getScriptUrl( 'Sandbox', 'SomeAttachments',
                'query' )
              . '/topic'
        },
'{"_raw_text":"%META:TOPICINFO{_authorWikiName=\"WikiGuest\" author=\"BaseUserMapping_666\" comment=\"reprev\" date=\"1291604133\" format=\"1.1\" reprev=\"1\" version=\"1\"}%\nlets create a topic.\n\n%META:FILEATTACHMENT{name=\"favicon.ico\" attachment=\"favicon.ico\" attr=\"\" comment=\"\" date=\"1227691956\" path=\"favicon.ico\" size=\"1150\" user=\"ProjectContributor\" version=\"1\"}%\n","_text":"lets create a topic.\n\n%META:FILEATTACHMENT{name=\"favicon.ico\" attachment=\"favicon.ico\" attr=\"\" comment=\"\" date=\"1227691956\" path=\"favicon.ico\" size=\"1150\" user=\"ProjectContributor\" version=\"1\"}%\n","_web":"Sandbox","FILEATTACHMENT":[],"_loadedRev":"1","TOPICINFO":[{"date":1291604133,"version":"1","reprev":"1","author":"BaseUserMapping_666","_authorWikiName":"WikiGuest","comment":"reprev","format":1.1,"rev":"1"}],"_indices":{"TOPICINFO":{}},"_topic":"SomeAttachments"}',
    );

    #    my $webData = Foswiki::Func::getDataDir().'/sandbox;
    my $webPub     = Foswiki::Func::getPubDir() . '/Sandbox/SomeAttachments/';
    my $attachment = $webPub . 'favicon.ico';
    print STDERR "touch $attachment returned: "
      . `mkdir -p $webPub ; chmod 777 $webPub; touch $attachment ; chmod 777 $attachment`;

    $this->runTest(
        'GET',
        'text/json',
        '',
        'Sandbox',
        'SomeAttachments',
        '',
        'attachments',
        'json',
        {
            HTTP_RESPONSE_STATUS      => '200',
            HTTP_RESPONSE_STATUS_TEXT => 'OK',
            'X-Foswiki-Rest-Query' => '\'Sandbox.SomeAttachments\'/attachments',
        },
'{"attachment":"favicon.ico","version":"1","date":"1227691956","name":"favicon.ico","path":"favicon.ico","attr":"","size":"1150","comment":"","user":"ProjectContributor"}',
    );
    $this->runTest(
        'PATCH',
        'text/json',
'{"attachment":"favicon.ico","version":"1","date":"1227691956","name":"favicon.ico","path":"favicon.ico","attr":"","size":"1150","comment":"Set a comment","user":"ProjectContributor"}',
        'Sandbox',
        'SomeAttachments',
        'favicon.ico',
        'attachments',
        'json',
        {
            HTTP_RESPONSE_STATUS      => '200',
            HTTP_RESPONSE_STATUS_TEXT => 'OK',
            'X-Foswiki-Rest-Query' =>
              '\'Sandbox.SomeAttachments\'/attachments[name=\'favicon.ico\']',
        },
'{"attachment":"favicon.ico","version":"1","date":"1227691956","name":"favicon.ico","path":"favicon.ico","attr":"","size":"1150","comment":"Set a comment","user":"ProjectContributor"}',
    );
    $this->runTest(
        'GET',
        'text/json',
        '',
        'Sandbox',
        'SomeAttachments',
        '',
        'attachments',
        'json',
        {
            HTTP_RESPONSE_STATUS      => '200',
            HTTP_RESPONSE_STATUS_TEXT => 'OK',
            'X-Foswiki-Rest-Query' => '\'Sandbox.SomeAttachments\'/attachments',
        },
'{"attachment":"favicon.ico","version":"1","date":"1227691956","name":"favicon.ico","path":"favicon.ico","attr":"","size":"1150","comment":"Set a comment","user":"ProjectContributor"}',
    );
}

sub test_multiple_attachment_modify {
    my $this = shift;

    if ( Foswiki::Func::topicExists( 'Sandbox', 'SomeAttachments' ) ) {

        #delete..
        $this->runTest(
            'DELETE',
            'text/json',
            '',
            'Sandbox',
            'SomeAttachments',
            '', 'topic', 'json',
            {
                HTTP_RESPONSE_STATUS      => '200',
                HTTP_RESPONSE_STATUS_TEXT => 'OK',

#            'X-Foswiki-Rest-Query'    => '\'Sandbox.SomeAttachments\'/attachments',
#                'Location' => Foswiki::Func::getScriptUrl( undef, undef, 'query' ).'/Sandbox/SomeAttachments/topic'
            },
        );
    }

    $this->runTest(
        'POST',
        'text/json',
'{"_topic":"SomeAttachments", "_text":"lets create a topic.\n\n%META:FILEATTACHMENT{name=\"favicon.ico\" attachment=\"favicon.ico\" attr=\"\" comment=\"\" date=\"1227691956\" path=\"favicon.ico\" size=\"1150\" user=\"ProjectContributor\" version=\"1\"}%\n%META:FILEATTACHMENT{name=\"image.png\" attachment=\"image.png\" attr=\"\" comment=\"original comment\" date=\"1227691956\" path=\"image.png\" size=\"1150\" user=\"ProjectContributor\" version=\"1\"}%\n"}',
        'Sandbox',
        '', '', 'topic', 'json',
        {
            HTTP_RESPONSE_STATUS      => '201',
            HTTP_RESPONSE_STATUS_TEXT => 'OK',

#            'X-Foswiki-Rest-Query'    => '\'Sandbox.SomeAttachments\'/attachments',
            'Location' =>
              Foswiki::Func::getScriptUrl( 'Sandbox', 'SomeAttachments',
                'query' )
              . '/topic'
        },
'{"_raw_text":"%META:TOPICINFO{_authorWikiName=\"WikiGuest\" author=\"BaseUserMapping_666\" comment=\"\" date=\"EXTRACTED_FOR_TESTING\" format=\"1.1\" version=\"1\"}%\nlets create a topic.\n\n%META:FILEATTACHMENT{name=\"favicon.ico\" attachment=\"favicon.ico\" attr=\"\" comment=\"\" date=\"EXTRACTED_FOR_TESTING\" path=\"favicon.ico\" size=\"1150\" user=\"ProjectContributor\" version=\"1\"}%\n%META:FILEATTACHMENT{name=\"image.png\" attachment=\"image.png\" attr=\"\" comment=\"original comment\" date=\"EXTRACTED_FOR_TESTING\" path=\"image.png\" size=\"1150\" user=\"ProjectContributor\" version=\"1\"}%\n","_text":"lets create a topic.\n\n%META:FILEATTACHMENT{name=\"favicon.ico\" attachment=\"favicon.ico\" attr=\"\" comment=\"\" date=\"EXTRACTED_FOR_TESTING\" path=\"favicon.ico\" size=\"1150\" user=\"ProjectContributor\" version=\"1\"}%\n%META:FILEATTACHMENT{name=\"image.png\" attachment=\"image.png\" attr=\"\" comment=\"original comment\" date=\"EXTRACTED_FOR_TESTING\" path=\"image.png\" size=\"1150\" user=\"ProjectContributor\" version=\"1\"}%\n","_web":"Sandbox","FILEATTACHMENT":[],"_loadedRev":"1","TOPICINFO":[{"date":"EXTRACTED_FOR_TESTING","version":"1","author":"BaseUserMapping_666","_authorWikiName":"WikiGuest","comment":"","format":1.1,"rev":"1"}],"_indices":{"TOPICINFO":{}},"_topic":"SomeAttachments"}'
    );

    #    my $webData = Foswiki::Func::getDataDir().'/sandbox;
    my $webPub      = Foswiki::Func::getPubDir() . '/Sandbox/SomeAttachments/';
    my $attachment  = $webPub . 'favicon.ico';
    my $attachment2 = $webPub . 'image.png';
    print STDERR "touch $attachment returned: "
      . `mkdir -p $webPub ; chmod 777 $webPub; touch $attachment ; chmod 777 $attachment; touch $attachment2 ; chmod 777 $attachment2`;

    $this->runTest(
        'GET',
        'text/json',
        '',
        'Sandbox',
        'SomeAttachments',
        '',
        'attachments',
        'json',
        {
            HTTP_RESPONSE_STATUS      => '200',
            HTTP_RESPONSE_STATUS_TEXT => 'OK',
            'X-Foswiki-Rest-Query' => '\'Sandbox.SomeAttachments\'/attachments',
        },
'[{"attachment":"favicon.ico","version":"1","date":"EXTRACTED_FOR_TESTING","name":"favicon.ico","path":"favicon.ico","attr":"","size":"1150","comment":"","user":"ProjectContributor"},{"attachment":"image.png","version":"1","date":"EXTRACTED_FOR_TESTING","name":"image.png","path":"image.png","attr":"","size":"1150","comment":"original comment","user":"ProjectContributor"}]',
    );
    $this->runTest(
        'PATCH',
        'text/json',
'{"attachment":"favicon.ico","version":"1","date":"1227691956","name":"favicon.ico","path":"favicon.ico","attr":"","size":"1150","comment":"Set a comment","user":"ProjectContributor"}',
        'Sandbox',
        'SomeAttachments',
        'favicon.ico',
        'attachments',
        'json',
        {
            HTTP_RESPONSE_STATUS      => '200',
            HTTP_RESPONSE_STATUS_TEXT => 'OK',
            'X-Foswiki-Rest-Query' =>
              '\'Sandbox.SomeAttachments\'/attachments[name=\'favicon.ico\']',
        },
'{"attachment":"favicon.ico","version":"1","date":"1227691956","name":"favicon.ico","path":"favicon.ico","attr":"","size":"1150","comment":"Set a comment","user":"ProjectContributor"}',
    );
    $this->runTest(
        'GET',
        'text/json',
        '',
        'Sandbox',
        'SomeAttachments',
        '',
        'attachments',
        'json',
        {
            HTTP_RESPONSE_STATUS      => '200',
            HTTP_RESPONSE_STATUS_TEXT => 'OK',
            'X-Foswiki-Rest-Query' => '\'Sandbox.SomeAttachments\'/attachments',
        },
'[{"attachment":"favicon.ico","version":"1","date":"EXTRACTED_FOR_TESTING","name":"favicon.ico","path":"favicon.ico","attr":"","size":"1150","comment":"Set a comment","user":"ProjectContributor"},{"attachment":"image.png","version":"1","date":"EXTRACTED_FOR_TESTING","name":"image.png","path":"image.png","attr":"","size":"1150","comment":"original comment","user":"ProjectContributor"}]',
    );
    $this->runTest(
        'DELETE',
        'text/json',
        '',
        'Sandbox',
        'SomeAttachments',
        'favicon.ico',
        'attachments',
        'json',
        {
            HTTP_RESPONSE_STATUS      => '200',
            HTTP_RESPONSE_STATUS_TEXT => 'OK',

#            'X-Foswiki-Rest-Query'    => '\'Sandbox.SomeAttachments\'/attachments',
#                'Location' => Foswiki::Func::getScriptUrl( undef, undef, 'query' ).'/Sandbox/SomeAttachments/topic'
        },
    );
    $this->runTest(
        'GET',
        'text/json',
        '',
        'Sandbox',
        'SomeAttachments',
        '',
        'attachments',
        'json',
        {
            HTTP_RESPONSE_STATUS      => '200',
            HTTP_RESPONSE_STATUS_TEXT => 'OK',
            'X-Foswiki-Rest-Query' => '\'Sandbox.SomeAttachments\'/attachments',
        },
'{"attachment":"image.png","version":"1","date":"EXTRACTED_FOR_TESTING","name":"image.png","path":"image.png","attr":"","size":"1150","comment":"original comment","user":"ProjectContributor"}',
    );
}

1;
