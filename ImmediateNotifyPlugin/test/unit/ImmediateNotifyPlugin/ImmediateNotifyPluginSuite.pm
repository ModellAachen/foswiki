# See bottom of file for license and copyright information
package ImmediateNotifyPluginSuite;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use warnings;
use locale;

my $testWeb2;

my @specs;

my $object;
my %notifications;

sub new {
    my $class = shift;
    return $class->SUPER::new( 'ImmediateNotifyPluginTests', @_ );
}

sub loadExtraConfig {
    my ( $this, $context, @args ) = @_;

    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{Enabled} = 0;
    $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{Module} =
      'Foswiki::Plugins::ImmediateNotifyPlugin';
    $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{TEST}{Enabled}       = 1;
    $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{SMTP}{Enabled}       = 0;
    $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{SMTP}{EmailFilterIn} = '';
    $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{XMPP}{Enabled}       = 0;

    $this->SUPER::loadExtraConfig( $context, @args );

#can't change to AdminOnlyAccessControl here, as we need to be able to create topics.
#$Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess'

    return;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    %notifications = ();    # initialize notifications hash

    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{Enabled} = 0;

    $testWeb2 = "$this->{test_web}/SubWeb";

    # Will get torn down when the parent web dies
    my $webObject = Foswiki::Meta->new( $this->{session}, $testWeb2 );
    $webObject->populateNewWeb();

    $this->registerUser( "tu1", "Test", "User1", "test1\@example.com" );
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{users_web}, 'TestUser1' );
    $text .= "   * Set IMMEDIATENOTIFYMETHOD = TEST\n";
    $text .= "   * Set IMMEDIATENOTIFY = TestUser1\n";
    Foswiki::Func::saveTopic( $this->{users_web}, 'TestUser1', $meta, $text,
        { ignorepermissions => 1 } );
    $meta->finish();

    $this->registerUser( "tu2", "Test", "User2", "test2\@example.com" );
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );
    ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{users_web}, 'TestUser2' );
    $text .= '   * Set IMMEDIATENOTIFYMETHOD = TEST(hitme@now)' . "\n";
    $text .= "   * Set IMMEDIATENOTIFY = TestUser2\n";
    Foswiki::Func::saveTopic( $this->{users_web}, 'TestUser2', $meta, $text,
        { ignorepermissions => 1 } );
    $meta->finish();

    $this->registerUser( "tu3", "Test", "User3", "test3\@example.com" );
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );
    ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{users_web}, 'TestUser3' );
    $text .= '   * Set IMMEDIATENOTIFYMETHOD = TEST(user3@example.com)' . "\n";
    $text .= "   * Set IMMEDIATENOTIFY = TestUser3\n";
    Foswiki::Func::saveTopic( $this->{users_web}, 'TestUser3', $meta, $text,
        { ignorepermissions => 1 } );
    $meta->finish();

    $this->registerUser( "tu4", "Test", "User4", "test4\@example.com" );
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );
    ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{users_web}, 'TestUser4' );
    $text .= '   * Set IMMEDIATENOTIFYMETHOD = TEST' . "\n";
    $text .= "   * Set IMMEDIATENOTIFY = TestUser4\n";
    Foswiki::Func::saveTopic( $this->{users_web}, 'TestUser4', $meta, $text,
        { ignorepermissions => 1 } );
    $meta->finish();

    # test group
    Foswiki::Func::saveTopic( $this->{users_web}, "TestGroup", undef,
        "   * Set GROUP = TestUser3\n" );

    # Must create a new wiki object to force re-registration of users
    $Foswiki::cfg{EnableEmail} = 1;
    $this->createNewFoswikiSession();
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    @FoswikiFnTestCase::mails = ();
    $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{Enabled} = 1;

    @specs = (

        # traditional subscriptions
        {
            entry     => "$this->{users_web}.WikiGuest - example\@example.com",
            email     => "example\@example.com",
            topicsout => ""
        },
        {
            entry => "$this->{users_web}.NonPerson - nonperson\@example.com",
            email => "nonperson\@example.com",
            topicsout => "*"
        },

    );

    if (  !$Foswiki::cfg{Site}{CharSet}
        || $Foswiki::cfg{Site}{CharSet} =~ /^iso-?8859/ )
    {

        # High-bit chars - assumes {Site}{CharSet} is set for a high-bit
        # encoding. No tests for multibyte encodings :-(
        push(
            @specs,    # Francais
            {
                email     => "test1\@example.com",
                entry     => "TestUser1 : Requêtes*",
                topicsout => "RequêtesNon RequêtesOui",
            },
        );
    }
    else {
        print STDERR
          "WARNING: High-bit tests disabled for $Foswiki::cfg{Site}{CharSet}\n";
    }

}

sub test_Simple {
    my $this = shift;
    $object = $this;

    $this->createNewFoswikiSession('TestUser1');

    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{users_web}, 'TestUser1' );
    $text .= "Modified\n";
    Foswiki::Func::saveTopic( $this->{users_web}, 'TestUser1', $meta, $text,
        { ignorepermissions => 1 } );

    ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{users_web}, 'TestUser2' );
    $text .= "Modified\n";
    Foswiki::Func::saveTopic( $this->{users_web}, 'TestUser2', $meta, $text,
        { ignorepermissions => 1 } );

    ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{users_web}, 'TestUser2' );
    $text =~ s/hitme\@now/adiffUser\@there/;
    Foswiki::Func::saveTopic( $this->{users_web}, 'TestUser2', $meta, $text,
        { ignorepermissions => 1 } );

    my $result;
    $result = shift @FoswikiFnTestCase::mails;
    $this->assert_matches(
qr/TEST Sending To: TestUser1, PARAMS none, BODY: TestUser1 has changed the topic .*\/$this->{users_web}\/TestUser1 Rev:r1\.3/,
        $result
    );
    $result = shift @FoswikiFnTestCase::mails;
    $this->assert_matches(
qr/TEST Sending To: TestUser2, PARAMS hitme\@now, BODY: TestUser1 has changed the topic .*\/$this->{users_web}\/TestUser2 Rev:r1\.3/,
        $result
    );
    $result = shift @FoswikiFnTestCase::mails;
    $this->assert_matches(
qr/TEST Sending To: TestUser2, PARAMS adiffUser\@there, BODY: TestUser1 has changed the topic .*\/$this->{users_web}\/TestUser2 Rev:r1\.3/,
        $result
    );

}

sub test_WebImmediateNotify {
    my $this = shift;
    $object = $this;

    my $notifyTopic =
      Foswiki::Meta->new( $this->{session}, $this->{users_web},
        'WebImmediateNotify' );
    $notifyTopic->put( "TOPICPARENT",
        { name => "$this->{users_web}.WebHome" } );
    Foswiki::Func::saveTopic( $this->{users_web}, 'WebImmediateNotify',
        $notifyTopic, "\n   * $this->{users_web}.TestUser3\n   * TestUser4\n" );
    $notifyTopic->finish();

    $this->createNewFoswikiSession('TestUser1');

    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{users_web}, 'TestUser1' );
    $text .= "Modified\n";
    Foswiki::Func::saveTopic( $this->{users_web}, 'TestUser1', $meta, $text,
        { ignorepermissions => 1 } );

    ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{users_web}, 'TestUser2' );
    $text .= "Modified\n";
    Foswiki::Func::saveTopic( $this->{users_web}, 'TestUser2', $meta, $text,
        { ignorepermissions => 1 } );

    ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{users_web}, 'TestUser2' );
    $text =~ s/hitme\@now/adiffUser\@there/;
    Foswiki::Func::saveTopic( $this->{users_web}, 'TestUser2', $meta, $text,
        { ignorepermissions => 1 } );

    #foreach my $message (@FoswikiFnTestCase::mails) {
    #    next unless $message;
    #    print STDERR "$message\n";
    #}

    my $result;

    # First save notifies User 4, 1 & 3
    $result = shift @FoswikiFnTestCase::mails;
    $this->assert_matches(
qr/TEST Sending To: TestUser4, PARAMS none, BODY: TestUser1 has changed the topic .*\/$this->{users_web}\/TestUser1 Rev:r1\.3/,
        $result
    );
    $result = shift @FoswikiFnTestCase::mails;
    $this->assert_matches(
qr/TEST Sending To: TestUser1, PARAMS none, BODY: TestUser1 has changed the topic .*\/$this->{users_web}\/TestUser1 Rev:r1\.3/,
        $result
    );
    $result = shift @FoswikiFnTestCase::mails;
    $this->assert_matches(
qr/TEST Sending To: TestUser3, PARAMS user3\@example.com, BODY: TestUser1 has changed the topic .*\/$this->{users_web}\/TestUser1 Rev:r1\.3/,
        $result
    );

    # 2nd save notifes User4, 2 & 3
    $result = shift @FoswikiFnTestCase::mails;
    $this->assert_matches(
qr/TEST Sending To: TestUser4, PARAMS none, BODY: TestUser1 has changed the topic .*\/$this->{users_web}\/TestUser2 Rev:r1\.3/,
        $result
    );
    $result = shift @FoswikiFnTestCase::mails;
    $this->assert_matches(
qr/TEST Sending To: TestUser2, PARAMS hitme\@now, BODY: TestUser1 has changed the topic .*\/$this->{users_web}\/TestUser2 Rev:r1\.3/,
        $result
    );
    $result = shift @FoswikiFnTestCase::mails;
    $this->assert_matches(
qr/TEST Sending To: TestUser3, PARAMS user3\@example.com, BODY: TestUser1 has changed the topic .*\/$this->{users_web}\/TestUser2 Rev:r1\.3/,
        $result
    );

    # 3rd save notifies User4, 2 & 3
    $result = shift @FoswikiFnTestCase::mails;
    $this->assert_matches(
qr/TEST Sending To: TestUser4, PARAMS none, BODY: TestUser1 has changed the topic .*\/$this->{users_web}\/TestUser2 Rev:r1\.3/,
        $result
    );
    $result = shift @FoswikiFnTestCase::mails;
    $this->assert_matches(
qr/TEST Sending To: TestUser2, PARAMS adiffUser\@there, BODY: TestUser1 has changed the topic .*\/$this->{users_web}\/TestUser2 Rev:r1\.3/,
        $result
    );
    $result = shift @FoswikiFnTestCase::mails;
    $this->assert_matches(
qr/TEST Sending To: TestUser3, PARAMS user3\@example.com, BODY: TestUser1 has changed the topic .*\/$this->{users_web}\/TestUser2 Rev:r1\.3/,
        $result
    );

}

sub test_NewTopic {
    my $this = shift;
    $object = $this;

    my $notifyTopic =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'WebImmediateNotify' );
    $notifyTopic->put( "TOPICPARENT", { name => "$this->{test_web}.WebHome" } );
    Foswiki::Func::saveTopic( $this->{test_web}, 'WebImmediateNotify',
        $notifyTopic, "\n   * $this->{users_web}.TestUser3\n" );
    $notifyTopic->finish();

    $this->createNewFoswikiSession('TestUser1');

    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'NotifyThis' );
    my $text = "   * Set IMMEDIATENOTIFY = TestUser1\n";
    Foswiki::Func::saveTopic( $this->{test_web}, 'NotifyThis', $meta, $text );

    #foreach my $message (@FoswikiFnTestCase::mails) {
    #    next unless $message;
    #    print STDERR "$message\n";
    #}

    my $result;
    $result = shift @FoswikiFnTestCase::mails;
    $this->assert_matches(
qr/TEST Sending To: TestUser1, PARAMS none, BODY: TestUser1 has created the topic .*\/$this->{test_web}\/NotifyThis Rev:r1\.1/,
        $result
    );
    $result = shift @FoswikiFnTestCase::mails;
    $this->assert_matches(
qr/TEST Sending To: TestUser3, PARAMS user3\@example.com, BODY: TestUser1 has created the topic .*\/$this->{test_web}\/NotifyThis Rev:r1\.1/,
        $result
    );

}

sub disable_testSubweb {
    my $this = shift;

    my @webs = ( $testWeb2, $this->{users_web} );
    Foswiki::Contrib::ImmediateNotifyPlugin::mailNotify( \@webs, 0, undef, 0,
        0 );

    #print "REPORT\n",join("\n\n", @FoswikiFnTestCase::mails);

    my %matched;
    foreach my $message (@FoswikiFnTestCase::mails) {
        next unless $message;
        $message =~ /^To: (.*)$/m;
        my $mailto = $1;
        $this->assert( $mailto, $message );
        foreach my $spec (@specs) {
            if ( $mailto eq $spec->{email} ) {
                $this->assert( !$matched{$mailto} );
                $matched{$mailto} = 1;
                my $xpect = $spec->{topicsout};
                last;
            }
        }
    }
    foreach my $spec (@specs) {
        if ( $spec->{topicsout} ne "" ) {
            $this->assert(
                $matched{ $spec->{email} },
                "Expected mails for "
                  . $spec->{email}
                  . " but only saw mails for "
                  . join( " ", keys %matched )
            );
        }
        else {
            $this->assert(
                !$matched{ $spec->{email} },
                "Didn't expect mails for "
                  . $spec->{email}
                  . "; got "
                  . join( " ", keys %matched )
            );
        }
    }
}

# Check filter-in on email addresses
sub disable_testExcluded {
    my $this = shift;

    $Foswiki::cfg{ImmediateNotifyPlugin}{EmailFilterIn} = '\w+\@example.com';

    my $s = <<'HERE';
   * bad@disallowed.com: *
   * good@example.com: *
HERE

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $Foswiki::cfg{NotifyTopicName} );
    $meta->put( "TOPICPARENT", { name => "$this->{test_web}.WebHome" } );
    Foswiki::Func::saveTopic( $this->{test_web}, $Foswiki::cfg{NotifyTopicName},
        $meta, "Before\n${s}After", $meta );
    Foswiki::Contrib::ImmediateNotifyPlugin::mailNotify( [ $this->{test_web} ],
        0, undef, 0, 0 );

    my %matched;
    foreach my $message (@FoswikiFnTestCase::mails) {
        next unless $message;
        $message =~ /^To: (.*?)$/m;
        my $mailto = $1;
        $this->assert( $mailto, $message );
        $this->assert_str_equals( 'good@example.com', $mailto, $mailto );
    }

    #print "REPORT\n",join("\n\n", @FoswikiFnTestCase::mails);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
