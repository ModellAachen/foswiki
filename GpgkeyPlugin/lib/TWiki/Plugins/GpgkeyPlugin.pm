#
# TWiki ($wikiversion has version info)
#
# Copyright (C) 2002 Slava Kozlov,
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
#
# =========================

# =========================
package TWiki::Plugins::GpgkeyPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug $CurrUrl
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

my $pluginName = "GpgkeyPlugin";
my $KeyserverCheckURL =
  "http://blackhole.pca.dfn.de:11371/pks/lookup?op=index&search=";

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    #    &TWiki::Func::writeDebug( "installWeb: $installWeb - $pluginName" );

 # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("GPGKEYPLUGIN_DEBUG");

    # mod_perl will have trouble because these three vals are globals
    # $CurrUrl =~ s/\&/\&amp;/go;

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::GpgPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================

sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    $_[0] =~ s/%GPGLISTVIEW%/&handleGpgKeyView($_[1], $_[2], "")/geo;

    # select which topic lists the users
    $_[0] =~ s/%GPGLISTVIEW{(.*?)}%/&handleGpgKeyView($_[1], $_[2], $1)/geo;

}

sub handleGpgKeyView {
    my ( $topic, $web, $attributes ) = @_;

    my @names;

    my $attrTopic = TWiki::Func::extractNameValuePair( $attributes, "topic" )
      || "GpgkeySigningPartyList";

    my $keylistTopic = TWiki::Func::readTopicText( $web, "$attrTopic" );
    my $mainWeb = TWiki::Func::getPreferencesValue("MAINWEB") || "Main";

    while ( $keylistTopic =~ /\t+\* $mainWeb\.([^\r\n]+)/go ) {
        push @names, $1 if $1;
    }

    unless (@names) {
        &TWiki::Func::writeDebug(
            "- $pluginName: No names registered for the party.");
        return;
    }

    my ( %userTopics, %userKeys, %userFingerprints, $groupTopic, %users,
        %groups );
    foreach my $name (@names) {
        &TWiki::Func::writeDebug("- $pluginName: Processing name $name")
          if $debug;
        if ( length($name) == 0 ) { next; }
        if ( $name =~ /Group$/go ) {
            $groups{$name} = 1;
            $groupTopic = TWiki::Func::readTopicText( $mainWeb, $name );
            unless ( defined($groupTopic) ) {
                warning(
                    "- $pluginName: Group topic \"$mainWeb.$name\" not found!");
                next;
            }
            $groupTopic =~ /\t+\* Set GROUP = ([^\r\n]+)/;
            my @groupMembers = split / *[, ]*/, $1;
            if (@groupMembers) {
                &TWiki::Func::writeDebug(
                    "- $pluginName: Group $name consits of: @groupMembers");
            }
            else {
                &TWiki::Func::writeDebug(
                    "- $pluginName: Group $name is undefined or has no members"
                );
            }
            foreach my $groupMember (@groupMembers) {
                $users{$groupMember} = 1;
            }
        }
        else {
            $users{$name} = 1;
        }
    }

    foreach my $user ( keys %users ) {
        $userTopics{$user} = TWiki::Func::readTopicText( $mainWeb, $user );
        unless ( defined( $userTopics{$user} ) ) {
            warning("- $pluginName: User topic \"$mainWeb.$user\" not found!");
            next;
        }

        $userTopics{$user} =~ /\t+\* GPG Key\: ([^\r\n]+)/;
        my @keyList = split / *[, ] */, $1;
        if (@keyList) {
            &TWiki::Func::writeDebug("- $pluginName: User $user: @keyList")
              if $debug;
        }
        else {
            &TWiki::Func::writeDebug("- $pluginName: User $user has no keys!")
              if $debug;
        }
        foreach my $key (@keyList) {
            $userKeys{$user}{$key} = 1;
        }

        $userTopics{$user} =~ /\t+\* GPG Fingerprint\: ([^\r\n]+)/;
        my @fingerprintList = split / *[,] */, $1;
        if (@fingerprintList) {
            &TWiki::Func::writeDebug(
                "- $pluginName: User $user: @fingerprintList")
              if $debug;
        }
        else {
            &TWiki::Func::writeDebug(
                "- $pluginName: User $user has no fingerprints!")
              if $debug;
        }
        foreach my $fingerprint (@fingerprintList) {
            $userFingerprints{$user}{"$fingerprint"} = 1;
        }
    }

    # startrenderer
    my $lineformat = '| Main.$user | $key | $fingerprint | $check |';
    my $heading    = "| *Name* | *Key* | *Fingerprint* | *Ask the Keyserver* |";
    my $str        = "$heading\n";
    my $entries    = keys %userKeys;

    my $s = "";

    while ( my ( $key, $value ) = each %userKeys ) {
        my ( $z, $g ) = each %$value;
        my $gaga = $userFingerprints{$key};
        my $sasa = each %$gaga;

        my $t = "$lineformat";
        $t =~ s/\$user/$key/;
        $t =~ s/\$key/$z/;
        my $bsc = '<a href="' . $KeyserverCheckURL . $z . '">Check!</a>';
        $t =~ s/\$check/$bsc/;
        $t =~ s/\$fingerprint/$sasa/;
        $t .= "\n";
        $s .= $t;
    }

    $str .= "$s";

    return $str;

    #}

}

# allow other classes to see the installation web
sub installWeb {
    return $installWeb;
}

1;
