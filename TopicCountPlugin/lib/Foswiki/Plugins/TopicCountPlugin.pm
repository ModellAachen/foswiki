# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2010 Arthur Clemens, arthur@visiblearea.com
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

package Foswiki::Plugins::TopicCountPlugin;

use strict;
use Foswiki::Func;
use Foswiki::Meta;
use Foswiki::Plugins::TopicDataHelperPlugin;

our $VERSION           = '$Rev: 4282 $';
our $RELEASE           = '1.0';
our $SHORTDESCRIPTION  = 'Shows the number of topics in a web or site';
our $NO_PREFS_IN_TOPIC = 1;

my $topic;
my $web;
my $user;
my $installWeb;
my $pluginName = 'TopicCountPlugin';

=pod

=cut

sub initPlugin {
    my ( $inTopic, $inWeb, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    Foswiki::Func::registerTagHandler( 'TOPICCOUNT', \&_handleTopicCount );

    # Plugin correctly initialized
    _debug(
        "- Foswiki::Plugins::${pluginName}::initPlugin( $inWeb.$inTopic ) is OK"
    );

    return 1;
}

=pod

=cut

sub _handleTopicCount {
    my ( $session, $inParams, $inTopic, $inWeb ) = @_;

    _debugData( "_handleTopicCount -- topic=$inWeb.$inTopic; params=",
        $inParams );

    my $topics        = $inParams->{'topic'}        || '*';
    my $webs          = $inParams->{'web'}          || $inWeb || '';
    my $excludeTopics = $inParams->{'excludetopic'} || '';
    my $excludeWebs   = $inParams->{'excludeweb'}   || '';

    # find all topic files except for excluded topics
    my $topicData =
      Foswiki::Plugins::TopicDataHelperPlugin::createTopicData( $webs,
        $excludeWebs, $topics, $excludeTopics );

    _filterTopicData( $topicData, $inParams )
      if Foswiki::Func::isTrue( $inParams->{'permissiononly'} );

    my $files =
      Foswiki::Plugins::TopicDataHelperPlugin::getListOfObjectData($topicData);

    return scalar @{$files};
}

=pod

Filters topic data references in the $inTopicData hash.
Called function remove topic data references in the hash.

=cut

sub _filterTopicData {
    my ( $inTopicData, $inParams ) = @_;
    my %topicData = %$inTopicData;

    # ----------------------------------------------------
    # filter topics by view permission
    my $user = Foswiki::Func::getWikiName();
    my $wikiUserName = Foswiki::Func::userToWikiName( $user, 1 );
    Foswiki::Plugins::TopicDataHelperPlugin::filterTopicDataByViewPermission(
        \%topicData, $wikiUserName );
}

=pod

Shorthand debugging call.

=cut

sub _debug {
    my ($text) = @_;

    return if !$Foswiki::cfg{Plugins}{$pluginName}{Debug};

    $text = "$pluginName: $text";

    #print STDERR $text . "\n";
    Foswiki::Func::writeDebug("$text");
}

=pod

=cut

sub _debugData {
    my ( $text, $data ) = @_;

    return if !$Foswiki::cfg{Plugins}{$pluginName}{Debug};
    Foswiki::Func::writeDebug("$pluginName; $text:");
    if ($data) {
        eval
'use Data::Dumper; local $Data::Dumper::Terse = 1; local $Data::Dumper::Indent = 1; Foswiki::Func::writeDebug(Dumper($data));';
    }
}

1;
