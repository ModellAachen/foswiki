package Foswiki::Plugins::AutoSavePlugin;

use strict;
use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );
use Unicode::MapUTF8();

$VERSION           = '$Rev$';
$RELEASE           = '0.9';
$SHORTDESCRIPTION  = 'Saves topics automatically';
$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'AutoSavePlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    Foswiki::Func::registerRESTHandler( 'autoSaveTopic', \&_autoSaveTopic );

    if ( $Foswiki::cfg{Plugins}{JQueryPlugin}{Enabled} ) {
        require Foswiki::Plugins::JQueryPlugin;
        Foswiki::Plugins::JQueryPlugin::registerPlugin( "AutoSave",
            'Foswiki::Plugins::AutoSavePlugin::AUTOSAVE' );

        # Foswiki::Plugins::JQueryPlugin::createPlugin("AutoSave");
    }

    return 1;
}

sub DISABLE_beforeEditHandler {
    my $web   = $_[2];
    my $topic = $_[1];

    my $language =
      Foswiki::Func::getPreferencesValue( 'LANGUAGE',
        $Foswiki::cfg{UsersWebName} )
      || 'en';
    my $wikiName = Foswiki::Func::getWikiName();

    my $binPath = Foswiki::Func::getScriptUrl();
    Foswiki::Func::addToHEAD( 'AUTOSAVE',
'<style text="text/css">#autoSaveBox { margin-top:10px; } #autoSaveBox select { margin-right:10px; border:1px solid #a7a7a7; }</style><script type="text/javascript">var userLanguage = "'
          . $language
          . '"; var autoSaveBinPath = "'
          . $binPath
          . '"; var autoSaveWeb = "'
          . $web
          . '"; var autoSaveTopic = "'
          . $topic
          . '";</script><script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/AutoSavePlugin/autosave.js" /></script>'
    );
}

sub _autoSaveTopic {
    my ( $session, $params, $topic, $web ) = @_;

    my $query = Foswiki::Func::getCgiQuery();
    my $topicContent;
    my $currentWeb;
    my $currentTopic;
    my @getTopic;

    # TODO: use Foswiki::UTF82SiteCharSet() here
    $topicContent = Unicode::MapUTF8::from_utf8(
        { -string => $query->param("text"), -charset => 'ISO-8859-1' } );
    $currentWeb = Unicode::MapUTF8::from_utf8(
        { -string => $query->param("web"), -charset => 'ISO-8859-1' } );
    $currentTopic = Unicode::MapUTF8::from_utf8(
        { -string => $query->param("topic"), -charset => 'ISO-8859-1' } );

    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $currentWeb, $currentTopic );

    @getTopic = split( /\./, $currentTopic );
    $currentTopic = $getTopic[1];

    # SMELL: checkAccessPermissions!!!!!
    Foswiki::Func::saveTopic( $currentWeb, $currentTopic, $meta,
        $topicContent );
}

1;
