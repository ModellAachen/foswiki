# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
#
# initPlugin is required, all other are optional.
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# =========================
package TWiki::Plugins::NotifyOnChildModificationPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $userListSuffix $emailTextSuffix
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$userListSuffix = 'NotifyUsers';
$mailTextSuffix = 'NotifyText';

$pluginName = 'NotifyOnChildModificationPlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");
    $debug = 1;

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub beforeSaveHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug("${pluginName}::beforeSaveHandler( $_[2].$_[1] )")
      if $debug;

    # This handler is called by TWiki::Store::saveTopic just before
    # the save action.
    my $text = "";
    my $meta = "";
    ( $meta, $text ) = &TWiki::Func::readTopic( $_[2], $_[1] );
    my %parent = $meta->findOne("TOPICPARENT");

    # Find topics with the list of users to notify and the
    # text to send by email
    if ( $parent{"name"} =~ /([^.]*)[.]([^.]*)/ ) { $pname = $2; $pweb = $1; }
    else { $pname = $parent{"name"}; $pweb = $_[2]; }
    my $userTopic   = "$pname$userListSuffix";
    my $mailTopic   = "$pname$mailTextSuffix";
    my $existsUsers = &TWiki::Func::topicExists( $pweb, $userTopic );
    my $existsText  = &TWiki::Func::topicExists( $pweb, $mailTopic );
    if ( $existsUsers && !$existsText ) {
        $mailTopic = $mailTextSuffix;
        $existsText = &TWiki::Func::topicExists( $pweb, $mailTopic );
    }

    # Send email notification to users
    if ( $existsUsers && $existsText ) {
        my @notifylist = TWiki::getEmailNotifyList( $pweb, $userTopic );
        my $notifylist = join ', ', @notifylist;
        if ( $#notifylist >= 0 ) {
            ( $meta, $text ) = &TWiki::Func::readTopic( $pweb, $mailTopic );
            my %mf =
              $meta->findOne( "FIELD", "NotifyOnChildModificationFormFrom" );
            my %ms =
              $meta->findOne( "FIELD", "NotifyOnChildModificationFormSubject" );
            my %mh =
              $meta->findOne( "FIELD", "NotifyOnChildModificationFormHeaders" );
            my $from = $mf{"value"}, $subj = $ms{"value"}, $head = $mh{"value"};
            if ( $from eq "" ) { $from = "%WIKIWEBMASTER%"; }
            if ( $subj eq "" ) {
                $subj = "Modification on $_[1] ($pname child)";
            }
            my $mail = "From: $from\nTo: $notifylist\nSubject: $subj";
            if ( !$head eq "" ) { $mail .= "\n$head"; }
            $text = "$mail\n\n$text";
            $text =~ s/%TOPICPARENT%/$pname/g;
            $theText = &TWiki::Func::expandCommonVariables( $text, $_[1] );
            &TWiki::Func::writeDebug(
"${pluginName}::beforeSaveHandler - Sending mail notification to:"
                  . " $notifylist" )
              if $debug;
            my $error = &TWiki::Net::sendEmail($text);

            if ($error) {
                &TWiki::Func::writeDebug(
                        "${pluginName}::beforeSaveHandler - Cannot send email"
                      . "(see email text below)\n$text" )
                  if $debug;
            }
            else {
                &TWiki::Func::writeDebug(
                    "${pluginName}::beforeSaveHandler - Mail notification sent")
                  if $debug;
            }
        }
        else {
            &TWiki::Func::writeDebug(
                "${pluginName}::beforeSaveHandler - user list to notify is void"
            ) if $debug;
        }
    }
    else {
        &TWiki::Func::writeDebug(
            "${pluginName}::beforeSaveHandler - Cannot find topic $userTopic"
              . " or $mailTopic" )
          if $debug;
    }
}

1;
