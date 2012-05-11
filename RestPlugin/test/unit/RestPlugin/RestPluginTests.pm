package RestPluginTests;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );
use strict;

#TODO: add tests for REST:Utils HTTP method tunneling and mimetypes..

use Foswiki ();
use Foswiki::Func();
use Foswiki::Meta      ();
use Foswiki::Serialise ();
use JSON               ();

# Set to 1 for debug
use constant MONITOR_ALL => 0;

my $UI_FN;
my $fatwilly;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my $this = shift;

    #turn off validation so we don't need to hack around with nonce
    #TODO: add nonces testing later.
    $Foswiki::cfg{Validation}{Method} = 'none';

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
    $UI_FN ||= $this->getUIFn('query');
}

sub call_UI_query {
    my ( $this, $url, $action, $params, $cuid ) = @_;
    my $query = new Unit::Request($params);
    $query->path_info($url);
    $query->method($action);
    my $sess = $Foswiki::Plugins::SESSION;
    $cuid = $this->{test_user_login} unless defined($cuid);

    my $loginname = Foswiki::Func::wikiToUserName($cuid);
    print STDERR "=-=- the user running the UI: " . $loginname . "\n"
      if MONITOR_ALL;
    $fatwilly = new Foswiki( $loginname, $query );

    my ( $text, $result, $stdout, $stderr ) = $this->capture(
        sub {
            no strict 'refs';
            &$UI_FN($fatwilly);
            use strict 'refs';
            $Foswiki::engine->finalize( $fatwilly->{response},
                $fatwilly->{request} );
        }
    );
    print STDERR "SSSSSSSS\n$stderr\nTTTTTTTTTT\n" if MONITOR_ALL;
    print STDERR "$stdout\nUUUUUUUUUUU\n"          if MONITOR_ALL;

    $fatwilly->finish();
    $Foswiki::Plugins::SESSION = $sess;

    $text =~ s/\r//g;
    $text =~ s/(^.*?\n\n+)//s;    # remove CGI header
    return ( $text, $1 );
}

sub testGET_topic {
    my $this = shift;

    {

        #/Main/WebHome/topic.json
        my ( $replytext, $hdr ) =
          $this->call_UI_query( '/Main/WebHome/topic.json', 'GET', {} );

        #        print STDERR "\n--- $replytext\n";
        my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        my ( $meta, $text ) = Foswiki::Func::readTopic( 'Main', 'WebHome' );

        $this->assert_deep_equals( $fromJSON,
            Foswiki::Serialise::convertMeta($meta) );

        #TODO: test the other values we're returning
    }
    {
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( $this->{test_web}, "Improvement2" );

        my ( $replytext, $hdr ) = $this->call_UI_query(
            '/' . $this->{test_web} . '/Improvement2/topic.json',
            'GET', {} );
        my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $this->assert_deep_equals( $fromJSON,
            Foswiki::Serialise::convertMeta($meta) );
    }
}

sub testGET_webs {
    my $this = shift;
    ##WEB
    {
        my $meta =
          Foswiki::Meta->load( $this->{session}, $Foswiki::cfg{SystemWebName} );

        my ( $replytext, $hdr ) = $this->call_UI_query(
            '/' . $Foswiki::cfg{SystemWebName} . '/webs.json',
            'GET', {} );
        my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $this->assert_deep_equals( $fromJSON,
            [ Foswiki::Serialise::convertMeta($meta) ] );
    }
    {
        my $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web} );

        my ( $replytext, $hdr ) =
          $this->call_UI_query( '/' . $this->{test_web} . '/webs.json',
            'GET', {} );
        my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $this->assert_deep_equals( $fromJSON,
            [ Foswiki::Serialise::convertMeta($meta) ] );
    }
}

#TODO: catching an exception inside a capture - gotta find out how to doit.
sub TODOtestGET_webs_doesnotexist {
    my $this = shift;

    #TODO: does not exist
    {
        my $meta =
          Foswiki::Meta->load( $this->{session}, 'SystemDoesNotExist' );

        try {
            my ( $replytext, $hdr ) =
              $this->call_UI_query( '/' . 'SystemDoesNotExist' . '/webs.json',
                'GET', {} );
            my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
            $this->assert_deep_equals( $fromJSON,
                [ Foswiki::Serialise::convertMeta($meta) ] );
        }
        catch Foswiki::EngineException with {
            my $e      = shift;
            my $result = $e->{-text};

            #$res->status( '500 ' . $result );
            print STDERR "******************($result)\n" if MONITOR_ALL;
        }
    }
}

sub testGET_allwebs {
    my $this = shift;
    {

        #get all webs..
        #commented out by PH. WTF?
        #my ( $meta, $text ) = Foswiki::Func::readTopic('SystemDoesNotExist');

        my ( $replytext, $hdr ) =
          $this->call_UI_query( '/webs.json', 'GET', {} );

        my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );

        my @webs = Foswiki::Func::getListOfWebs( '', '' );
        my @results = map {
            my $meta = Foswiki::Meta->load( $this->{session}, $_ );
            print STDERR "::::: load($_) == " . $meta->web . "\n"
              if MONITOR_ALL;
            Foswiki::Serialise::convertMeta($meta)
        } @webs;

        $this->assert_deep_equals( $fromJSON, \@results );
    }
}

sub LATERtestGET_NoSuchTopic {
    my $this = shift;

    {
        my ( $replytext, $hdr );
        try {
            ( $replytext, $hdr ) =
              $this->call_UI_query( '/Main/WebHomeDoesNotExist/topic.json',
                'GET', {} );
        }
        finally {
            print STDERR "hllo" if MONITOR_ALL;
        }
        print STDERR "HEADER: $hdr\n"      if MONITOR_ALL;
        print STDERR "REPLY: $replytext\n" if MONITOR_ALL;

    }
}

#modify partial item updates
sub testPATCH_CompleteTopic {
    my $this = shift;

    #GET the topic
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, "Improvement2" );
    my ( $replytext, $hdr ) = $this->call_UI_query(
        '/' . $this->{test_web} . '/Improvement2/topic.json',
        'GET', {} );
    my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
    $this->assert_deep_equals( $fromJSON,
        Foswiki::Serialise::convertMeta($meta) );

#modify it a little and PUT
#print STDERR "----- ".$fromJSON->{FIELD}[0]->{name}.": ".$fromJSON->{FIELD}[0]->{value}."\n" if MONITOR_ALL;
    $fromJSON->{FIELD}[0]->{value} = 'Actually, its brilliant!';
    my $sendJSON = JSON::to_json($fromJSON);
    ( $replytext, $hdr ) = $this->call_UI_query(
        '/' . $this->{test_web} . '/Improvement2/topic.json',
        'PATCH', { 'POSTDATA' => $sendJSON } );

    #my $replyHash =  JSON::from_json( $replytext, { allow_nonref => 1 } );

    #then make sure it saved using GET..
    {
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( $this->{test_web}, "Improvement2" );

        my ( $replytext, $hdr ) = $this->call_UI_query(
            '/' . $this->{test_web} . '/Improvement2/topic.json',
            'GET', {} );

        my $NEWfromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );

        $this->assert_equals( $NEWfromJSON->{_text}, $text );
        $this->assert_str_equals( $NEWfromJSON->{_raw_text},
            $meta->getEmbeddedStoreForm() );

        $this->assert_deep_equals( $NEWfromJSON,
            Foswiki::Serialise::convertMeta($meta) );
        $this->assert_equals( $NEWfromJSON->{FIELD}[0]->{value},
            'Actually, its brilliant!' );
        $this->assert_equals( $NEWfromJSON->{_text}, $fromJSON->{_text} );
        $this->assert_str_not_equals( $NEWfromJSON->{_raw_text},
            $fromJSON->{_raw_text} );
    }
}

#modify partial item updates
sub testPATCH_JustOneField_Topic {
    my $this = shift;

    #GET the topic
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, "Improvement2" );
    my ( $replytext, $hdr ) = $this->call_UI_query(
        '/' . $this->{test_web} . '/Improvement2/topic.json',
        'GET', {} );
    my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
    $this->assert_deep_equals( $fromJSON,
        Foswiki::Serialise::convertMeta($meta) );

    #modify it a little and PUT
    {

        print STDERR "----- "
          . $fromJSON->{FIELD}[0]->{name} . ": "
          . $fromJSON->{FIELD}[0]->{value} . "\n"
          if MONITOR_ALL;
        my $partialItem = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $partialItem->{FIELD}[0]->{value} = 'Something new, something blue';
        foreach my $key ( keys( %{$partialItem} ) ) {
            next if ( $key eq 'FIELD' );
            delete $partialItem->{$key};
        }
        my $sendJSON = JSON::to_json($partialItem);

     #print STDERR "------------\n".$sendJSON."\n------------\n" if MONITOR_ALL;

        ( $replytext, $hdr ) = $this->call_UI_query(
            '/' . $this->{test_web} . '/Improvement2/topic.json',
            'PATCH', { 'POSTDATA' => $sendJSON } );

        #my $replyHash =  JSON::from_json( $replytext, { allow_nonref => 1 } );
    }

    #then make sure it saved using GET..
    {
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( $this->{test_web}, "Improvement2" );
        my ( $replytext, $hdr ) = $this->call_UI_query(
            '/' . $this->{test_web} . '/Improvement2/topic.json',
            'GET', {} );

        print STDERR "-------reply-----\n" . $replytext . "\n------------\n"
          if MONITOR_ALL;

        my $NEWfromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $this->assert_deep_equals( $NEWfromJSON,
            Foswiki::Serialise::convertMeta($meta) );
        $this->assert_equals(
            $NEWfromJSON->{FIELD}[0]->{value},
            'Something new, something blue'
        );
        $this->assert_equals( $NEWfromJSON->{FIELD}[0]->{name},  'Summary' );
        $this->assert_equals( $NEWfromJSON->{FIELD}[0]->{title}, 'Summary' );

        $this->assert_str_not_equals( $NEWfromJSON->{_raw_text},
            $fromJSON->{_raw_text} );
        $this->assert_equals( $NEWfromJSON->{_text}, $fromJSON->{_text} );

        #make sure the other FIELD is still as it was before.
        $this->assert_equals( $NEWfromJSON->{FIELD}[1]->{value},
            $fromJSON->{FIELD}[1]->{value} );
        $this->assert_equals( 'work it out yourself!',
            $NEWfromJSON->{FIELD}[1]->{value} );
        $this->assert_equals( 'Details', $NEWfromJSON->{FIELD}[1]->{name} );
    }
}

#modify partial item updates
sub testPATCH_OneArrayElementByName_Topic {
    my $this = shift;

    #GET the topic
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, "Improvement2" );
    my ( $replytext, $hdr ) = $this->call_UI_query(
        '/' . $this->{test_web} . '/Improvement2/topic.json',
        'GET', {} );
    my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
    $this->assert_deep_equals( $fromJSON,
        Foswiki::Serialise::convertMeta($meta) );

    #send PATCH with only the one
    {

        print STDERR "----- "
          . $fromJSON->{FIELD}[0]->{name} . ": "
          . $fromJSON->{FIELD}[0]->{value} . "\n"
          if MONITOR_ALL;
        my $partialItem = {
            "FIELD" => [
                {
                    "name"  => "Summary",
                    "value" => 'Something new, something blue'
                }
            ]
        };
        my $sendJSON = JSON::to_json($partialItem);

        print STDERR "------------\n" . $sendJSON . "\n------------\n"
          if MONITOR_ALL;

        ( $replytext, $hdr ) = $this->call_UI_query(
            '/' . $this->{test_web} . '/Improvement2/topic.json',
            'PATCH', { 'POSTDATA' => $sendJSON } );

        #my $replyHash =  JSON::from_json( $replytext, { allow_nonref => 1 } );
    }

    #then make sure it saved using GET..
    {
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( $this->{test_web}, "Improvement2" );
        my ( $replytext, $hdr ) = $this->call_UI_query(
            '/' . $this->{test_web} . '/Improvement2/topic.json',
            'GET', {} );

        print STDERR "-------reply-----\n" . $replytext . "\n------------\n"
          if MONITOR_ALL;

        my $NEWfromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $this->assert_deep_equals( $NEWfromJSON,
            Foswiki::Serialise::convertMeta($meta) );
        $this->assert_equals(
            $NEWfromJSON->{FIELD}[0]->{value},
            'Something new, something blue'
        );

        $this->assert_str_not_equals( $NEWfromJSON->{_raw_text},
            $fromJSON->{_raw_text} );
        $this->assert_equals( $NEWfromJSON->{_text}, $fromJSON->{_text} );

        #make sure the other FIELD is still as it was before.
        $this->assert_equals( $NEWfromJSON->{FIELD}[1]->{value},
            $fromJSON->{FIELD}[1]->{value} );
        $this->assert_equals( 'work it out yourself!',
            $NEWfromJSON->{FIELD}[1]->{value} );
        $this->assert_equals( 'Details', $NEWfromJSON->{FIELD}[1]->{name} );
    }
}

#modify partial item updates
sub testPATCH_Topic_PARENT {
    my $this = shift;

    #GET the topic
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, "Improvement2" );
    my ( $replytext, $hdr ) = $this->call_UI_query(
        '/' . $this->{test_web} . '/Improvement2/topic.json',
        'GET', {} );
    my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
    $this->assert_deep_equals( $fromJSON,
        Foswiki::Serialise::convertMeta($meta) );

    #modify it a little and PUT
    {

#print STDERR "----- ".$fromJSON->{FIELD}[0]->{name}.": ".$fromJSON->{FIELD}[0]->{value}."\n" if MONITOR_ALL;
        my $partialItem = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $partialItem->{TOPICPARENT} = [ { 'name' => 'WebHome' } ];
        foreach my $key ( keys( %{$partialItem} ) ) {
            next if ( $key eq 'TOPICPARENT' );
            delete $partialItem->{$key};
        }
        my $sendJSON = JSON::to_json($partialItem);

     #print STDERR "------------\n".$sendJSON."\n------------\n" if MONITOR_ALL;

        ( $replytext, $hdr ) = $this->call_UI_query(
            '/' . $this->{test_web} . '/Improvement2/topic.json',
            'PATCH', { 'POSTDATA' => $sendJSON } );

        #my $replyHash =  JSON::from_json( $replytext, { allow_nonref => 1 } );
    }

    #then make sure it saved using GET..
    {
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( $this->{test_web}, "Improvement2" );
        my ( $replytext, $hdr ) = $this->call_UI_query(
            '/' . $this->{test_web} . '/Improvement2/topic.json',
            'GET', {} );

#print STDERR "-------reply-----\n".$replytext."\n------------\n" if MONITOR_ALL;

        my $NEWfromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $this->assert_deep_equals( $NEWfromJSON,
            Foswiki::Serialise::convertMeta($meta) );
        $this->assert_equals(

            #            keys(%{$NEWfromJSON->{TOPICPARENT}}),
            $meta->getParent(),
            'WebHome'
        );

        $this->assert_str_not_equals( $NEWfromJSON->{_raw_text},
            $fromJSON->{_raw_text} );
        $this->assert_equals( $NEWfromJSON->{_text}, $fromJSON->{_text} );

        #make sure the other FIELD is still as it was before.
        $this->assert_equals( $NEWfromJSON->{FIELD}[1]->{value},
            $fromJSON->{FIELD}[1]->{value} );
        $this->assert_equals( 'work it out yourself!',
            $NEWfromJSON->{FIELD}[1]->{value} );
        $this->assert_equals( 'Details', $NEWfromJSON->{FIELD}[1]->{name} );
    }
}

#modify partial item updates
sub testPATCH_JustText_Topic {
    my $this = shift;

    #GET the topic
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, "Improvement2" );
    my ( $replytext, $hdr ) = $this->call_UI_query(
        '/' . $this->{test_web} . '/Improvement2/topic.json',
        'GET', {} );
    my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
    $this->assert_deep_equals( $fromJSON,
        Foswiki::Serialise::convertMeta($meta) );

    #modify it a little and PUT
    {

#print STDERR "----- ".$fromJSON->{FIELD}[0]->{name}.": ".$fromJSON->{FIELD}[0]->{value}."\n" if MONITOR_ALL;
        my $partialItem = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $partialItem->{_text} = 'Something new, something blue';
        foreach my $key ( keys( %{$partialItem} ) ) {
            next if ( $key eq '_text' );
            delete $partialItem->{$key};
        }
        my $sendJSON = JSON::to_json($partialItem);

        print STDERR "----send--------\n" . $sendJSON . "\n------------\n"
          if MONITOR_ALL;

        ( $replytext, $hdr ) = $this->call_UI_query(
            '/' . $this->{test_web} . '/Improvement2/topic.json',
            'PATCH', { 'POSTDATA' => $sendJSON } );

        #my $replyHash =  JSON::from_json( $replytext, { allow_nonref => 1 } );
    }

    #then make sure it saved using GET..
    {
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( $this->{test_web}, "Improvement2" );
        my ( $replytext, $hdr ) = $this->call_UI_query(
            '/' . $this->{test_web} . '/Improvement2/topic.json',
            'GET', {} );

#print STDERR "-------reply-----\n".$replytext."\n------------\n" if MONITOR_ALL;

        my $NEWfromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $this->assert_deep_equals( $NEWfromJSON,
            Foswiki::Serialise::convertMeta($meta) );
        $this->assert_equals( $NEWfromJSON->{_text},
            'Something new, something blue' );

        $this->assert_str_not_equals( $NEWfromJSON->{_raw_text},
            $fromJSON->{_raw_text} );
        $this->assert_equals( $fromJSON->{FIELD}[0]->{value},
            $NEWfromJSON->{FIELD}[0]->{value} );

        #make sure the other FIELD is still as it was before.
        $this->assert_equals( $NEWfromJSON->{FIELD}[1]->{value},
            $fromJSON->{FIELD}[1]->{value} );
        $this->assert_equals( 'work it out yourself!',
            $NEWfromJSON->{FIELD}[1]->{value} );
        $this->assert_equals( 'Details', $NEWfromJSON->{FIELD}[1]->{name} );
    }
}

#create new items
sub testPOST {
    my $this = shift;

    #GET the topic
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, "Improvement2" );
    my ( $replytext, $hdr ) = $this->call_UI_query(
        '/' . $this->{test_web} . '/Improvement2/topic.json',
        'GET', {} );
    print STDERR "------($replytext)\n" if MONITOR_ALL;
    my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
    $this->assert_deep_equals( $fromJSON,
        Foswiki::Serialise::convertMeta($meta) );

    #make sure we get a different timestamp..
    sleep(2);

#modify it a little and POST to a new topic name..
#print STDERR "----- ".$fromJSON->{FIELD}[0]->{name}.": ".$fromJSON->{FIELD}[0]->{value}."\n" if MONITOR_ALL;
    $fromJSON->{FIELD}[0]->{value} = 'Actually, its brilliant!';
    $fromJSON->{_topic} = 'Improvement3';
    my $sendJSON = JSON::to_json($fromJSON);
    ( $replytext, $hdr ) =
      $this->call_UI_query( '/' . $this->{test_web} . '/topic.json',
        'POST', { 'POSTDATA' => $sendJSON } );

    #my $replyHash =  JSON::from_json( $replytext, { allow_nonref => 1 } );
    print STDERR "################### $hdr ######################\n"
      if MONITOR_ALL;
    $hdr =~ /Location: (.*)/;
    my $LocationInHdr = $1;
    $this->assert_str_equals(
        Foswiki::Func::getScriptUrl( undef, undef, 'query' ) . '/'
          . $this->{test_web}
          . '/Improvement3/topic',
        $LocationInHdr
    );

    #then make sure it saved using GET..
    {
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( $this->{test_web}, "Improvement3" );
        my ( $replytext, $hdr ) = $this->call_UI_query(
            '/' . $this->{test_web} . '/Improvement3/topic.json',
            'GET', {} );
        print STDERR "------($replytext)\n" if MONITOR_ALL;
        my $NEWfromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $this->assert_deep_equals( $NEWfromJSON,
            Foswiki::Serialise::convertMeta($meta) );
        $this->assert_equals( $NEWfromJSON->{FIELD}[0]->{value},
            'Actually, its brilliant!' );
        $this->assert_equals( $NEWfromJSON->{_text}, $fromJSON->{_text} );
        $this->assert_str_not_equals( $NEWfromJSON->{_raw_text},
            $fromJSON->{_raw_text} );
        $this->assert_str_not_equals(
            $NEWfromJSON->{TOPICINFO}[0]->{date},
            $fromJSON->{TOPICINFO}[0]->{date}
        );
    }

    #DELETE it
    $this->assert(
        Foswiki::Func::topicExists( $this->{test_web}, 'Improvement3' ) );

    ( $replytext, $hdr ) = $this->call_UI_query(
        '/' . $this->{test_web} . '/Improvement3/topic.json',
        'DELETE', {}, 'BaseUserMapping_333' );

    $this->assert(
        not Foswiki::Func::topicExists( $this->{test_web}, 'Improvement3' ) );

}

#create new items
sub testPOST_AUTOINC001 {
    my $this = shift;

    #GET the topic
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, "Improvement2" );
    my ( $replytext, $hdr ) = $this->call_UI_query(
        '/' . $this->{test_web} . '/Improvement2/topic.json',
        'GET', {} );
    print STDERR "------($replytext)\n" if MONITOR_ALL;
    my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
    $this->assert_deep_equals( $fromJSON,
        Foswiki::Serialise::convertMeta($meta) );

    #make sure we get a different timestamp..
    sleep(2);

#modify it a little and POST to a new topic name..
#print STDERR "----- ".$fromJSON->{FIELD}[0]->{name}.": ".$fromJSON->{FIELD}[0]->{value}."\n" if MONITOR_ALL;
    $fromJSON->{FIELD}[0]->{value} = 'Actually, its brilliant!';
    $fromJSON->{_topic} = 'TestTopicAUTOINC001';

    my $sendJSON = JSON::to_json($fromJSON);
    ( $replytext, $hdr ) =
      $this->call_UI_query( '/' . $this->{test_web} . '/topic.json',
        'POST', { 'POSTDATA' => $sendJSON } );

    #my $replyHash =  JSON::from_json( $replytext, { allow_nonref => 1 } );

    #then make sure it saved using GET..
    {
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( $this->{test_web}, "TestTopic001" );
        my ( $replytext, $hdr ) = $this->call_UI_query(
            '/' . $this->{test_web} . '/TestTopic001/topic.json',
            'GET', {} );
        print STDERR "------($replytext)\n" if MONITOR_ALL;
        my $NEWfromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $this->assert_deep_equals( $NEWfromJSON,
            Foswiki::Serialise::convertMeta($meta) );
        $this->assert_equals( $NEWfromJSON->{FIELD}[0]->{value},
            'Actually, its brilliant!' );
        $this->assert_equals( $NEWfromJSON->{_text}, $fromJSON->{_text} );
        $this->assert_str_not_equals( $NEWfromJSON->{_raw_text},
            $fromJSON->{_raw_text} );
        $this->assert_str_not_equals(
            $NEWfromJSON->{TOPICINFO}[0]->{date},
            $fromJSON->{TOPICINFO}[0]->{date}
        );
    }
}

sub test_copy_topic {
    my $this = shift;

#TODO: this is a dumb blind copy, where we even copy attachment meta that is not valid for this new topic.

    {
        my ( $replytext, $hdr ) = $this->call_UI_query(
            '/' . $this->{test_web} . '/Improvement2/topic.json',
            'GET', {} );
        my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $fromJSON->{_topic} = 'CopyOfimprovement2';

        $this->assert(
            not Foswiki::Func::topicExists(
                $this->{test_web}, 'CopyOfimprovement2'
            )
        );
        my $sendJSON = JSON::to_json($fromJSON);

        sleep(1);

        #POST to the web..
        ( $replytext, $hdr ) =
          $this->call_UI_query( '/' . $this->{test_web} . '/topic.json',
            'POST', { 'POSTDATA' => $sendJSON } );

        $this->assert(
            Foswiki::Func::topicExists(
                $this->{test_web}, 'CopyOfimprovement2'
            )
        );
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( $this->{test_web}, 'CopyOfimprovement2' );

        #amend $fromJSON's time&author
        $sendJSON =~ s/BaseUserMapping_666/scum/g;
        $sendJSON =~
          s/$fromJSON->{TOPICINFO}[0]->{date}/$meta->{TOPICINFO}[0]->{date}/g;
        $this->assert_deep_equals( Foswiki::Serialise::convertMeta($meta),
            JSON::from_json( $sendJSON, { allow_nonref => 1 } ) );
    }
}

sub test_create_web {
    my $this = shift;

    #TODO: move to 'clean' processor
    $this->deleteWebs(
        1,
        (
            $this->{test_web} . 'REST',
            'Sandbox/' . $this->{test_web} . 'REST',
            'Sandbox/' . $this->{test_web} . 'Again'
        )
    );

    my @websToDelete;

    #TODO: make sure the Location and other Headers are correct..
    {
        my $newWeb = $this->{test_web} . 'REST';
        push( @websToDelete, $newWeb );
        $this->assert( not Foswiki::Func::webExists($newWeb) );

        #create  web using _default
        my $sendJSON = JSON::to_json(
            {
                baseweb    => '_default',
                newweb     => $newWeb,
                webbgcolor => '#ff2222',
                websummary => 'web created by query REST API'
            }
        );
        my ( $replytext, $hdr ) =
          $this->call_UI_query( '/webs.json?copy', 'POST',
            { 'POSTDATA' => $sendJSON },
            'BaseUserMapping_333' );
        my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );

        $this->assert( Foswiki::Func::webExists($newWeb) );
        $this->assert_equals( '#ff2222',
            Foswiki::Func::getPreferencesValue( 'WEBBGCOLOR', $newWeb ) );
        $this->assert_equals( 'web created by query REST API',
            Foswiki::Func::getPreferencesValue( 'WEBSUMMARY', $newWeb ) );
    }

    {
        my $newWeb = 'Sandbox/' . $this->{test_web} . 'REST';
        push( @websToDelete, $newWeb );
        $this->assert( not Foswiki::Func::webExists($newWeb) );

        #create  web using _default
        my $sendJSON = JSON::to_json(
            {
                baseweb    => '_default',
                newweb     => $newWeb,
                webbgcolor => '#22ff22',
                websummary => 'subweb created by query REST API'
            }
        );
        my ( $replytext, $hdr ) =
          $this->call_UI_query( '/webs.json?copy', 'POST',
            { 'POSTDATA' => $sendJSON },
            'BaseUserMapping_333' );
        my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );

        $this->assert( Foswiki::Func::webExists($newWeb) );
        $this->assert_equals( '#22ff22',
            Foswiki::Func::getPreferencesValue( 'WEBBGCOLOR', $newWeb ) );
        $this->assert_equals( 'subweb created by query REST API',
            Foswiki::Func::getPreferencesValue( 'WEBSUMMARY', $newWeb ) );
    }
    {    #this one the newWeb should become a subweb of the uri web..
        my $nestedWeb = $this->{test_web} . 'Again';
        my $newWeb    = 'Sandbox/' . $nestedWeb;
        push( @websToDelete, $newWeb );
        $this->assert( not Foswiki::Func::webExists($newWeb) );

        #create  web using _default
        my $sendJSON = JSON::to_json(
            {
                baseweb    => '_default',
                newweb     => $nestedWeb,
                webbgcolor => '#22ff22',
                websummary => 'another subweb created by query REST API'
            }
        );
        my ( $replytext, $hdr ) =
          $this->call_UI_query( '/Sandbox/webs.json?copy', 'POST',
            { 'POSTDATA' => $sendJSON },
            'BaseUserMapping_333' );
        my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );

        $this->assert( Foswiki::Func::webExists($newWeb) );
        $this->assert_equals( '#22ff22',
            Foswiki::Func::getPreferencesValue( 'WEBBGCOLOR', $newWeb ) );
        $this->assert_equals( 'another subweb created by query REST API',
            Foswiki::Func::getPreferencesValue( 'WEBSUMMARY', $newWeb ) );
    }
    $this->deleteWebs( undef, @websToDelete );
}

sub deleteWebs {
    my $this         = shift;
    my $cleaning     = shift;
    my @websToDelete = @_;

#delete all webs we just made.. (again, needs to use the REST API so that the permissions are ok.)
    foreach my $deleteWeb (@websToDelete) {

#if we're cleaning, we don't care if the web exists or not, we just want to make sure its gone before we start the test
        next if ( $cleaning and not( Foswiki::Func::webExists($deleteWeb) ) );
        $this->assert( Foswiki::Func::webExists($deleteWeb) );

        print STDERR "\nDELETE($deleteWeb)\n" if MONITOR_ALL;

        my ( $replytext, $hdr ) =
          $this->call_UI_query( '/' . $deleteWeb . '/webs.json?copy',
            'DELETE', {}, 'BaseUserMapping_333' );
        print STDERR "\n  DELETE($deleteWeb) == "
          . ( Foswiki::Func::webExists($deleteWeb) ? 'exists' : 'gone' ) . "\n"
          if MONITOR_ALL;

        $this->assert( not( Foswiki::Func::webExists($deleteWeb) ) );
    }
}

1;
