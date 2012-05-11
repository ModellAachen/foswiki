# See bottom of file for default license and copyright information

package Foswiki::Plugins::FreeMarkerPlugin;

use strict;
use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version
use Foswiki::Plugins::FreeMarkerPlugin::AttributeParser qw(new parse);
use Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser qw(new parse);

our $VERSION           = '$Rev: 4533 $';
our $RELEASE           = '1.1.1';
our $SHORTDESCRIPTION  = '<nop>FreeMarker template parser';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName        = 'FreeMarkerPlugin';
our $debug             = 0;
our $web;
our $topic;

sub initPlugin {
    my ( $inTopic, $inWeb, $inUser, $inInstallWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    $topic = $inTopic;
    $web   = $inWeb;

    $debug = Foswiki::Func::getPluginPreferencesFlag("DEBUG");

    Foswiki::Func::registerTagHandler( 'STARTFREEMARKER', \&_startFreeMarker );
    Foswiki::Func::registerTagHandler( 'ENDFREEMARKER',   \&_endFreeMarker );

    _debug("initPlugin; plugin initialized");

    return 1;
}

=pod

=cut

sub commonTagsHandler {

    #my ($text, $topic, $web, $meta ) = @_;

    $_[0] =~
s/%STARTFREEMARKER{?(.*?)}?%(.*?)%ENDFREEMARKER%/&_handleTemplate($1, $2, $_[2], $_[1])/ges;
}

=pod

_handleTemplate($attributes, $content, $web, $topic)

=cut

sub _handleTemplate {
    my ( $inAttrStr, $inContent, $inWeb, $inTopic ) = @_;

    _debug("_handleTemplate");
    _debug("\t inAttrStr=$inAttrStr");
    _debug("\t inContent=$inContent");

    my $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->setDebugLevel( $debug ? 0x1F : 0 );

    my %attributes = Foswiki::Func::extractParameters($inAttrStr);
    my $data       = {};
    $data = _attributesToData( \%attributes ) if (%attributes);

    my $parsed = $parser->parse( $inContent, $data );

    _debug("\t parsed=$parsed");

    return $parsed;
}

=pod

Uses AttributeParser to convert string input to Perl data objects.

=cut

sub _attributesToData {
    my ($inAttr) = @_;

    my $parser = new Foswiki::Plugins::FreeMarkerPlugin::AttributeParser();
    $parser->setDebugLevel( $debug ? 0x1F : 0 );

    my $data = {};

    while ( my ( $key, $value ) = each %{$inAttr} ) {

        # render $value so that we interpret $percnt and such
        $value = Foswiki::Func::decodeFormatTokens($value);
        $value = Foswiki::Func::expandCommonVariables( $value, $topic, $web );

        $data->{$key} = $parser->parse($value);
    }
    if ( $data->{_DEFAULT} ) {
        foreach my $key ( keys %{ $data->{_DEFAULT} } ) {
            $data->{$key} = $data->{_DEFAULT}->{$key};
        }
        delete $data->{_DEFAULT};
    }

    if ($debug) {
        use Data::Dumper;
        _debug( "_attributesToData:\n" . Dumper($data) );
    }

    return $data;
}

# ignored
sub _startFreeMarker {

    #my($session, $params, $inTopic, $inWeb) = @_;
}

# ignored
sub _endFreeMarker {

    #my($session, $params, $inTopic, $inWeb) = @_;
}

=pod

Shorthand function call.

=cut

sub _debug {
    my ($text) = @_;
    Foswiki::Func::writeDebug("$pluginName:$text") if $text && $debug;
}

1;

__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2010 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
