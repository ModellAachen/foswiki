# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2003 Micahel Sparks
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

package Foswiki::Plugins::RandomTopicPlugin;

use strict;

use vars qw(
  $VERSION $RELEASE @topicList $defaultIncludes $defaultExcludes $doneInit
);

# This should always be $Rev$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '2.0';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    Foswiki::Func::registerTagHandler( 'RANDOMTOPIC', \&handleRandomTopic );
    $doneInit = 0;
    return 1;
}

sub init {
    my $session = shift;

    return if $doneInit;

    $doneInit  = 1;
    @topicList = Foswiki::Func::getTopicList( $session->{webName} );
    $defaultIncludes =
      Foswiki::Func::getPreferencesValue("RANDOMTOPICPLUGIN_INCLUDE");
    $defaultExcludes =
      Foswiki::Func::getPreferencesValue("RANDOMTOPICPLUGIN_EXCLUDE");

}

sub handleRandomTopic {
    my ( $session, $params, $topic, $web ) = @_;

    init($session);

    my $header = $params->{header} || '';

    my $format = $params->{format};
    $format = '$topic' unless defined $format;

    my $separator = $params->{separator} || '';
    my $footer    = $params->{footer}    || '';
    my $topics    = $params->{topics}    || 1;

    my $includes = $params->{include};
    $includes = ( $defaultIncludes || "^.+\$" ) unless defined $includes;

    my $excludes = $params->{exclude};
    $excludes = ( $defaultExcludes || "^\$" ) unless defined $excludes;

    my @pickFrom = grep { /$includes/ && !/$excludes/ } @topicList;

    my @result   = ();
    my %chosen   = ();
    my $nrTopics = scalar(@pickFrom);
    my $pickable = $nrTopics;
    while ( $topics && $pickable ) {
        my $i = int( rand($nrTopics) );
        unless ( $chosen{$i} ) {
            my $line = $format;
            $line =~ s/\$topic/$pickFrom[$i]/g;
            push( @result, $line );
            $topics--;
            $pickable--;
            $chosen{$i} = 1;
        }
    }

    return '' unless @result;
    my $result = $header . join( $separator, @result ) . $footer;

    return Foswiki::Func::decodeFormatTokens($result);
}

1;
