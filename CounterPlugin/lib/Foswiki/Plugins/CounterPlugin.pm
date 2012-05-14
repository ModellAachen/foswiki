# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2003 RahulMundke

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
package Foswiki::Plugins::CounterPlugin;

# =========================
#This is plugin specific variable
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
our $VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
our $RELEASE = 'Dakar';

our $SHORTDESCRIPTION = 'Vistor counts';

our $NO_PREFS_IN_TOPIC = 1;

our $debug = 1;

################################################################################

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1 ) {
        &Foswiki::Func::writeWarning(
            "Version mismatch between CounterPlugin and Plugins.pm");
        return 0;
    }

    Foswiki::Func::registerTagHandler( COUNTER_PLUGIN => \&_COUNTER );
    Foswiki::Func::registerTagHandler( PAGE_COUNTER   => \&_COUNTER );

    $Count = _readCounter( $web, $topic );
    $Count = $Count + 1;
    _writeCounter( $web, $topic, $Count );

    return 1;
}

################################################################################

sub _writeCounter {
    my ( $web, $topic, $count ) = @_;

    my $fileName = _getCounterFilename( $web, $topic );
    if ( open( FILE, '>', $fileName ) ) {
        print FILE $Count;
        close(FILE);
    }
    else {
        warn "Can't open \"$fileName\" file: $!";
    }
}

################################################################################

sub _getCounterFilename {
    my ( $web, $topic ) = @_;

    return Foswiki::Func::getDataDir() . "/${web}/${topic}.count";
}

################################################################################

sub _readCounter {
    my ( $web, $topic ) = @_;

    my $count = 0;
    my $fileName = _getCounterFilename( $web, $topic );
    if ( open( FILE, '<', $fileName ) ) {
        $count = <FILE>;
        close(FILE);
    }

    return $count . ( $debug && " ($web,$topic)" || '' );
}

################################################################################

sub _COUNTER {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( '',
        $params->{_DEFAULT} || "${theWeb}.${theTopic}" );
    $web   = $params->{web}   if defined $params->{web};
    $topic = $params->{topic} if defined $params->{topic};

    unless ( ( $web eq $theWeb ) and ( $topic eq $theTopic ) ) {
        $Count = _readCounter( $web, $topic );
    }

    return $Count;
}

1;
