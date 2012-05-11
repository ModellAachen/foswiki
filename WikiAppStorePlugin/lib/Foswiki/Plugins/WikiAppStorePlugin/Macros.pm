package Foswiki::Plugins::WikiAppStorePlugin::Macros;

use strict;
use warnings;

sub TRYME {
    my ( $session, $params, $topic, $web, $topicObject ) = @_;
    my $return_text = undef;

    # Check if the Wiki App requires any extensions. If it does check
    # that they are enabled/installed or notify the user that they will
    #not be able to test run the Wiki App.
    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    my $reqd_extensions =
      Foswiki::Func::getPreferencesValue('REQUIRED_EXTENSIONS');
    if ($reqd_extensions) {

     # Check if the required extensions are available on this install of Foswiki
        my @extensions = split( /, */, $reqd_extensions );
        if ( scalar @extensions gt 0 ) {
            foreach my $extension (@extensions) {

                # Remove any web prefix if it exists
                $extension =~ s/Extensions.|System.|%SYSTEMEWEB%.|\[|\]//gi;

                # If a Plugin is referenced check that it is enabled
                if ( $extension =~ /Plugin/mi ) {
                    unless ( $Foswiki::cfg{Plugins}{$extension}{Enabled} ) {
                        $return_text .=
"\n<div class='foswikiAlert'>Required extension \'$extension\' is not installed/enabled</div>\n\n";
                    }

# If a Contrib/AddOn is referenced check that there is a topic in the %SYSTEMWEB% with the same name
                }
                elsif ( $extension =~ /Contrib|AddOn/mi ) {
                    unless (
                        Foswiki::Func::topicExists(
                            $Foswiki::cfg{SystemWebName}, $extension
                        )
                      )
                    {
                        $return_text .=
"\n<div class='foswikiAlert'>Required extension \'$extension\' is not installed</div>";
                    }
                }
            }
        }
    }

# If $return_text is defined, disable the test button as it will not work on this install of Foswiki
    if ($return_text) {
        Foswiki::Func::writeWarning($return_text);
        $return_text .=
"\n<div class='foswikiAlert'>Not all of the required extensions needed to test this Wiki App are installed/enabled on this install of Foswiki. If you have the extensions installed on your local install, try downloading the Wiki App and test it there.</div>\n";
        return $return_text;
    }
    else {
        if ( Foswiki::Func::getCgiQuery()->param("appstore_try") ) {
            doTRYME($session);
        }
        else {
            $return_text .=
"\nYou can test this application on this Foswiki install in a personal playpen web called *Sandbox/%WIKINAME%* which will be created if it does not already exist. You simply need to click on the following button:\n";
            $return_text .=
"\n<a class='foswikiSubmit' href='%SCRIPTURL{view}%/$web/$topic?appstore_try=1;app_topic=%WEB%.%TOPIC%'>Try this Wiki Application in your personal Sandbox web</a>";
            return $return_text;
        }
    }
}

sub doTRYME {
    my ( $session, $response ) = @_;

    # - Read a MANIFEST from the current topic
    # - Create a "playpen" under Sandbox for the individual user
    # - Copy topics into the playpen
    # - Jump to the nominated "application topic"
    Foswiki::Func::getCgiQuery()->param('app_topic') =~ /^(.*?)\.(.*)$/;
    my ( $web, $topic ) = ( $1, $2 );
    my $original_web   = $web;
    my $original_topic = $topic;
    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    my $manifest = Foswiki::Func::getPreferencesValue('MANIFEST');
    unless ($manifest) {
        die "No * Set MANIFEST statement in $web.$topic";
    }
    my @topics    = split( /, */, $manifest );
    my $wikiname  = Foswiki::Func::getWikiName();
    my $targetWeb = 'Sandbox/' . $wikiname;
    unless ( Foswiki::Func::webExists($targetWeb) ) {

        # Foswiki::Func::createWeb($targetWeb, '_empty');
        # Can't use Foswiki::Func because it's doesn't rewrite the perms
        # Therefore we create a new empty web based on the '_empty' template web
        Foswiki::Meta->new( $session, $targetWeb )
          ->populateNewWeb( '_empty', {} );

  # Add a default WebHome topic which will list all applications in this new web
        ( $meta, $text ) = ( '', '' );
        $text .=
          '---+!! Welcome to your personal playpen web for testing Web Apps';
        $text .=
          "\nYou can use this web for testing the below Foswiki Wiki Apps";
        $text .=
"\n\n<div class='foswikiAlert'>Note that these personalized webs are routinely removed after a defined period of inactivity. Do not use this web for storing long-term information.</div>\n";
        $text .= "\n---++!! Wiki Apps Available in this web\n";
        $text .=
'%SEARCH{"preferences[name=\'APP_MASTER_TOPIC\'].value=\'true\'" excludetopic="WebPreferences,WebHome" type="query" nonoise="on" format="   * [[$topic]]"}%';
        Foswiki::Func::saveTopic( $targetWeb, 'WebHome', $meta, $text,
            { dontlog => 1, minor => 1 } );
    }

    # Check if there are any commentplugin templates defined
    my $user_comments_template = 'UserCommentsTemplate';
    my $comment_pref =
      Foswiki::Func::getPreferencesValue('COMMENT_TEMPLATE_TOPIC');
    if ($comment_pref) {
        my @comment_topics = split( /, */, $comment_pref );
        if ( Foswiki::Func::topicExists( $targetWeb, $user_comments_template ) )
        {
            my ( $meta, $text ) =
              Foswiki::Func::readTopic( $targetWeb, $user_comments_template );
            $text .= "\n%TMPL:INCLUDE{\"$comment_topics[0]\"}%\n";
            Foswiki::Func::saveTopic( $targetWeb, $user_comments_template,
                $meta, $text, { dontlog => 1, minor => 1 } );
        }
        else {

# Copy the default UserCommentsTemplate topic to the playpen
#my ($meta, $text) = Foswiki::Func::readTopic('System', $user_comments_template);
            $comment_topics[0] =~ s/Template//g;
            $text =
"\n<verbatim>\n%TMPL:INCLUDE{\"$comment_topics[0]\"}%\n</verbatim>\n";

     # Must drop the 'Template'  when adding include to the UserCommentsTemplate
            Foswiki::Func::saveTopic( $targetWeb, $user_comments_template,
                $meta, $text, { dontlog => 1, minor => 1 } );
        }
    }

# Find out what is the landing page for the wiki app (Assuming its the first one)
    my $app_landing_topic = $topics[0];
    foreach $topic (@topics) {
        unless ( Foswiki::Func::topicExists( $web, $topic ) ) {
            die "$web.$topic does not exist (listed in * Set MANIFEST)";
        }
    }
    foreach my $topic (@topics) {
        my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
        if ( $app_landing_topic eq $topic ) {
            $meta->putAll(
                'PREFERENCE',
                {
                    name => 'BROADCASTMESSAGE',
                    value =>
"You are using a test version of this wiki application in your personal sandbox web. See [[$original_web.$original_topic]] for further information, including details on how to download this Wiki App for use in your local Foswiki installation."
                },
                { name => 'APP_MASTER_TOPIC', value => 'true' },
            );

            # Set the topic parent to WebHome
            $meta->put( 'TOPICPARENT', { name => 'WebHome' } );
        }
        else {

            # Set the the other app topics parent to the app landing page
            $meta->put( 'TOPICPARENT', { name => $app_landing_topic } );
        }
        Foswiki::Func::saveTopic( $targetWeb, $topic, $meta, $text,
            { dontlog => 1, minor => 1 } );

        # Copy any attachments to the sandbox web
        use Error qw( :try );
        my @attachment_list = undef;
        @attachment_list = Foswiki::Func::getAttachmentList( $web, $topic );
        if ( scalar @attachment_list gt 0 ) {
            foreach my $attachment (@attachment_list) {
                try {
                    Foswiki::Func::copyAttachment( $web, $topic, $attachment,
                        $targetWeb, $topic );
                }
                catch Foswiki::AccessControlException with {
                    my $e = shift;
                }
                catch Error::Simple with {
                    my $e = shift;
                };
            }
        }
    }

    # Now redirect to the App Landing page in the personal Sandbox Web
    Foswiki::Func::redirectCgiQuery( undef,
        Foswiki::Func::getScriptUrl( $targetWeb, $app_landing_topic, 'view' ),
        0 );
}

sub PACKAGEME {
    my ( $session, $params, $topic, $web, $topicObject ) = @_;

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    my @manifest_details =
      split( /, */, Foswiki::Func::getPreferencesValue('MANIFEST') );
    my $return_string;

    foreach my $app_topic (@manifest_details) {
        $return_string .=
"\n   * <a href='%SCRIPTURL{view}%/$web/$app_topic?raw=all' target='_blank'>$app_topic</a>";
    }
    return $return_string;
}

1;
