# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ListMeUpPlugin

=cut

package Foswiki::Plugins::ListMeUpPlugin;

use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version
use Error qw( :try );

our $VERSION           = '$Rev: 11239 $';
our $RELEASE           = '1.0.0';
our $SHORTDESCRIPTION  = 'Add/remove items from a given list (in META data).';
our $NO_PREFS_IN_TOPIC = 1;
our $DEBUG             = 0;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    Foswiki::Func::registerRESTHandler(
        'add',
        \&resthandleAdd,
        authenticate => 1,
        http_allow   => 'POST'
    );
    Foswiki::Func::registerRESTHandler(
        'remove',
        \&resthandleRemove,
        authenticate => 1,
        http_allow   => 'POST'
    );

    # Plugin correctly initialized
    Foswiki::Func::writeDebug("ListMeUpPlugin::initPlugin done.") if $DEBUG;
    return 1;
}

sub _checkParameter {
    my ( $webtopic, $type, $name, $item ) = @_;
    my ( $status, $message ) = ( 200, "" );

    if ( not defined($webtopic) || $webtopic eq "" ) {
        $status  = "400";
        $message = "400 Missing parameter 'webtopic'.";
        return ( $status, $message );
    }
    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef, $webtopic );

    if ( not Foswiki::Func::topicExists( $web, $topic ) ) {
        $status  = "404";
        $message = "404 Topic not found.";
    }
    elsif ( not defined($name) || $name eq "" ) {
        $status  = "400";
        $message = "400 Missing parameter 'name'.";
    }
    elsif ( not defined($item) || $item eq "" ) {
        $status  = "400";
        $message = "400 Missing parameter 'item'.";
    }
    elsif (
        !Foswiki::Func::checkAccessPermission(
            'CHANGE', Foswiki::Func::getWikiName(),
            undef, $topic, $web, undef
        )
      )
    {
        $status  = "403";
        $message = "403 Forbidden.";
    }

    if ( $status eq "200" ) {
        my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
        if ( not defined( $meta->get( $type, $name ) ) ) {
            $status  = "404";
            $message = "404 Metadata not found.";
        }
    }

    return ( $status, $message );
}

sub resthandleAdd {
    my ( $session, $subject, $verb, $response ) = @_;

    my $query     = $session->{request};
    my $webtopic  = $query->{param}->{webtopic}[0];
    my $type      = uc( $query->{param}->{type}[0] ) || "FIELD";
    my $sep       = $query->{param}->{separator}[0] || ", ";
    my $split     = $query->{param}->{split}[0] || '[,\s]+';
    my $name      = $query->{param}->{name}[0] || "";
    my $item      = $query->{param}->{item}[0] || "";
    my $duplicate = $query->{param}->{duplicate}[0] || 0;
    my $sort      = $query->{param}->{sort}[0] || 0;
    if ( $duplicate =~ m/off/i ) { $duplicate = 0; }
    if ( $sort      =~ m/off/i ) { $sort      = 0; }

    # check preconditions
    #
    my ( $status, $message ) =
      _checkParameter( $webtopic, $type, $name, $item );
    unless ( $status == 200 ) {
        $response->header( -status => $status, -type => 'text/plain' );
        $response->print($message);
        return undef;
    }
    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef, $webtopic );

    # compile list
    #
    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    my $field = $meta->get( $type, $name );
    my $list       = $field->{value} || "";
    my $itemExists = 0;
    my @items      = split( /$split/, $list );
    unless ($duplicate) {
        foreach my $cur_item (@items) {
            if ( $cur_item eq $item ) {
                $itemExists = 1;
                last;
            }
        }
    }
    push( @items, $item ) unless ($itemExists);
    if ($sort) {
        @items = sort(@items);
    }
    $list = join( $sep, @items );

    # save list
    #
    $field->{value} = $list;
    $meta->putKeyed( $type, $field );
    try {
        Foswiki::Func::saveTopic( $web, $topic, $meta, $text )
          unless ($itemExists);
    }
    catch Error::Simple with {
        my $e = $DEBUG ? shift : "";
        $response->header( -status => 500, -type => 'text/plain' );
        $response->print("500 Error saving topic. $e");
        return undef;
    };

    return "200 Ok";
}

sub resthandleRemove {
    my ( $session, $subject, $verb, $response ) = @_;

    my $query            = $session->{request};
    my $webtopic         = $query->{param}->{webtopic}[0];
    my $type             = uc( $query->{param}->{type}[0] ) || "FIELD";
    my $sep              = $query->{param}->{separator}[0] || ", ";
    my $split            = $query->{param}->{split}[0] || '[,\s]+';
    my $name             = $query->{param}->{name}[0] || "";
    my $delete_candidate = $query->{param}->{item}[0] || "";
    my $sort             = $query->{param}->{sort}[0] || 0;
    if ( $sort =~ m/off/i ) { $sort = 0; }

    # check preconditions
    #
    my ( $status, $message ) =
      _checkParameter( $webtopic, $type, $name, $delete_candidate );
    unless ( $status == 200 ) {
        $response->header( -status => $status, -type => 'text/plain' );
        $response->print($message);
        return undef;
    }
    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef, $webtopic );

    # compile list
    #
    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    my $field = $meta->get( $type, $name );
    my $list = $field->{value} || "";
    unless ( $list eq "" ) {
        my @oldItems = split( /$split/, $list );
        my @newItems = ();
        foreach my $item (@oldItems) {
            next if ( $item =~ m/^\s*$delete_candidate\s*$/ );
            next if ( $item =~ m/^$/ );
            push( @newItems, $item );
        }
        if ($sort) {
            @newItems = sort(@newItems);
        }
        $list = join( $sep, @newItems );
    }

    # save list
    #
    $field->{value} = $list;
    $meta->putKeyed( $type, $field );
    try {
        Foswiki::Func::saveTopic( $web, $topic, $meta, $text );
    }
    catch Error::Simple with {
        my $e = $DEBUG ? shift : "";
        $response->header( -status => 500, -type => 'text/plain' );
        $response->print("500 Error saving topic. $e");
        return undef;
    };

    return "200 Ok";
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: OliverKrueger

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
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
