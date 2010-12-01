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

my $UI_FN;
my $fatwilly;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
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
    $UI_FN ||= $this->getUIFn('query');
}

sub call_UI_query {
    my ( $this, $url, $action, $params ) = @_;
    my $query = new Unit::Request($params);
    $query->path_info($url);
    $query->method($action);
    my $sess = $Foswiki::Plugins::SESSION;

print STDERR "=-=- the user running the UI: ".$this->{test_user_login}."\n";
    $fatwilly = new Foswiki( $this->{test_user_login}, $query );

    my ($text, $result, $stdout, $stderr) = $this->capture(
        sub {
            no strict 'refs';
            &$UI_FN($fatwilly);
            use strict 'refs';
            $Foswiki::engine->finalize( $fatwilly->{response},
                $fatwilly->{request} );
        }
    );
    print STDERR "SSSSSSSS\n$stderr\nTTTTTTTTTT\n";
    print "$stdout\nUUUUUUUUUUU\n";

    $fatwilly->finish();
    $Foswiki::Plugins::SESSION = $sess;

    $text =~ s/\r//g;
    $text =~ s/(^.*?\n\n+)//s;    # remove CGI header
    return ( $text, $1 );
}

sub testGET {
    my $this = shift;

    {

        #/Main/WebHome/topic.json
        my ( $replytext, $hdr ) =
          $this->call_UI_query( '/Main/WebHome/topic.json', 'GET', {} );

        #print STDERR $replytext;
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

sub LATERtestGET_NoSuchTopic {
    my $this = shift;

    {
        my ( $replytext, $hdr );
        try {
            ( $replytext, $hdr ) =
              $this->call_UI_query( '/Main/WebHomeDoesNotExist/topic.json', 'GET', {} );
        } finally {
            print STDERR "hllo";
        }
        print STDERR "HEADER: $hdr\n";
        print STDERR "REPLY: $replytext\n";

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
#print STDERR "----- ".$fromJSON->{FIELD}[0]->{name}.": ".$fromJSON->{FIELD}[0]->{value}."\n";
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
        $this->assert_deep_equals( $NEWfromJSON,
            Foswiki::Serialise::convertMeta($meta) );
        $this->assert_equals( $NEWfromJSON->{FIELD}[0]->{value},
            'Actually, its brilliant!' );
        $this->assert_equals( $NEWfromJSON->{_text},
            $fromJSON->{_text} );
        $this->assert_str_not_equals(
            $NEWfromJSON->{_raw_text},
            $fromJSON->{_raw_text}
        );
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

#print STDERR "----- ".$fromJSON->{FIELD}[0]->{name}.": ".$fromJSON->{FIELD}[0]->{value}."\n";
        my $partialItem = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $partialItem->{FIELD}[0]->{value} =
          'Something new, something blue';
        foreach my $key ( keys( %{ $partialItem } ) ) {
            next if ( $key eq 'FIELD' );
            delete $partialItem->{$key};
        }
        my $sendJSON = JSON::to_json($partialItem);

        #print STDERR "------------\n".$sendJSON."\n------------\n";

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

        #print STDERR "-------reply-----\n".$replytext."\n------------\n";

        my $NEWfromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $this->assert_deep_equals( $NEWfromJSON,
            Foswiki::Serialise::convertMeta($meta) );
        $this->assert_equals( $NEWfromJSON->{FIELD}[0]->{value},
            'Something new, something blue' );

        $this->assert_str_not_equals(
            $NEWfromJSON->{_raw_text},
            $fromJSON->{_raw_text}
        );
        $this->assert_equals( $NEWfromJSON->{_text},
            $fromJSON->{_text} );
        #make sure the other FIELD is still as it was before.
        $this->assert_equals( $NEWfromJSON->{FIELD}[1]->{value},
            $fromJSON->{FIELD}[1]->{value} );
        $this->assert_equals('work it out yourself!',  $NEWfromJSON->{FIELD}[1]->{value} );
        $this->assert_equals('Details',  $NEWfromJSON->{FIELD}[1]->{name} );
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

#print STDERR "----- ".$fromJSON->{FIELD}[0]->{name}.": ".$fromJSON->{FIELD}[0]->{value}."\n";
        my $partialItem = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $partialItem->{_text} =
          'Something new, something blue';
        foreach my $key ( keys( %{ $partialItem } ) ) {
            next if ( $key eq '_text' );
            delete $partialItem->{$key};
        }
        my $sendJSON = JSON::to_json($partialItem);

        print STDERR "----send--------\n".$sendJSON."\n------------\n";

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

        #print STDERR "-------reply-----\n".$replytext."\n------------\n";

        my $NEWfromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $this->assert_deep_equals( $NEWfromJSON,
            Foswiki::Serialise::convertMeta($meta) );
        $this->assert_equals( $NEWfromJSON->{_text},
            'Something new, something blue' );

        $this->assert_str_not_equals(
            $NEWfromJSON->{_raw_text},
            $fromJSON->{_raw_text}
        );
        $this->assert_equals( $fromJSON->{FIELD}[0]->{value}, $NEWfromJSON->{FIELD}[0]->{value} );
        #make sure the other FIELD is still as it was before.
        $this->assert_equals( $NEWfromJSON->{FIELD}[1]->{value},
            $fromJSON->{FIELD}[1]->{value} );
        $this->assert_equals('work it out yourself!',  $NEWfromJSON->{FIELD}[1]->{value} );
        $this->assert_equals('Details',  $NEWfromJSON->{FIELD}[1]->{name} );
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
print STDERR "------($replytext)\n";
    my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
    $this->assert_deep_equals( $fromJSON,
        Foswiki::Serialise::convertMeta($meta) );

#make sure we get a different timestamp..
sleep(2);


#modify it a little and POST to a new topic name..
#print STDERR "----- ".$fromJSON->{FIELD}[0]->{name}.": ".$fromJSON->{FIELD}[0]->{value}."\n";
    $fromJSON->{FIELD}[0]->{value} = 'Actually, its brilliant!';
    $fromJSON->{_topic} = 'Improvement3';
    my $sendJSON = JSON::to_json($fromJSON);
    ( $replytext, $hdr ) = $this->call_UI_query(
        '/' . $this->{test_web} . '/webs.json',
        'POST', { 'POSTDATA' => $sendJSON } );

    #my $replyHash =  JSON::from_json( $replytext, { allow_nonref => 1 } );
    print STDERR "################### $hdr ######################\n";
    $hdr =~ /Location: (.*)/;
    my $LocationInHdr = $1;
    $this->assert_str_equals(Foswiki::Func::getScriptUrl(undef, undef, 'query').'/' . $this->{test_web} . '/Improvement3/topic', $LocationInHdr);

    #then make sure it saved using GET..
    {
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( $this->{test_web}, "Improvement3" );
        my ( $replytext, $hdr ) = $this->call_UI_query(
            '/' . $this->{test_web} . '/Improvement3/topic.json',
            'GET', {} );
print STDERR "------($replytext)\n";
        my $NEWfromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $this->assert_deep_equals( $NEWfromJSON,
            Foswiki::Serialise::convertMeta($meta) );
        $this->assert_equals( $NEWfromJSON->{FIELD}[0]->{value},
            'Actually, its brilliant!' );
        $this->assert_equals( $NEWfromJSON->{_text},
            $fromJSON->{_text} );
        $this->assert_str_not_equals(
            $NEWfromJSON->{_raw_text},
            $fromJSON->{_raw_text}
        );
        $this->assert_str_not_equals(
            $NEWfromJSON->{TOPICINFO}[0]->{date},
            $fromJSON->{TOPICINFO}[0]->{date}
        );
    }
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
print STDERR "------($replytext)\n";
    my $fromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
    $this->assert_deep_equals( $fromJSON,
        Foswiki::Serialise::convertMeta($meta) );

#make sure we get a different timestamp..
sleep(2);


#modify it a little and POST to a new topic name..
#print STDERR "----- ".$fromJSON->{FIELD}[0]->{name}.": ".$fromJSON->{FIELD}[0]->{value}."\n";
    $fromJSON->{FIELD}[0]->{value} = 'Actually, its brilliant!';
    $fromJSON->{_topic} = 'TestTopicAUTOINC001';

    my $sendJSON = JSON::to_json($fromJSON);
    ( $replytext, $hdr ) = $this->call_UI_query(
        '/' . $this->{test_web} . '/webs.json',
        'POST', { 'POSTDATA' => $sendJSON } );

    #my $replyHash =  JSON::from_json( $replytext, { allow_nonref => 1 } );

    #then make sure it saved using GET..
    {
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( $this->{test_web}, "TestTopic001" );
        my ( $replytext, $hdr ) = $this->call_UI_query(
            '/' . $this->{test_web} . '/TestTopic001/topic.json',
            'GET', {} );
print STDERR "------($replytext)\n";
        my $NEWfromJSON = JSON::from_json( $replytext, { allow_nonref => 1 } );
        $this->assert_deep_equals( $NEWfromJSON,
            Foswiki::Serialise::convertMeta($meta) );
        $this->assert_equals( $NEWfromJSON->{FIELD}[0]->{value},
            'Actually, its brilliant!' );
        $this->assert_equals( $NEWfromJSON->{_text},
            $fromJSON->{_text} );
        $this->assert_str_not_equals(
            $NEWfromJSON->{_raw_text},
            $fromJSON->{_raw_text}
        );
        $this->assert_str_not_equals(
            $NEWfromJSON->{TOPICINFO}[0]->{date},
            $fromJSON->{TOPICINFO}[0]->{date}
        );
    }
}


1;